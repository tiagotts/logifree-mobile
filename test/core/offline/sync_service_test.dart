import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logifree_mobile/core/offline/pending_operation.dart';
import 'package:logifree_mobile/core/offline/sync_service.dart';
import 'package:logifree_mobile/core/storage/migrations.dart';
import 'package:logifree_mobile/core/storage/offline_queue.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Fake do [ConnectivityWatcher] controlado pelo teste.
class _FakeConnectivityWatcher implements ConnectivityWatcher {
  _FakeConnectivityWatcher({
    List<ConnectivityResult> initial = const <ConnectivityResult>[
      ConnectivityResult.none,
    ],
  }) : _current = initial;

  final StreamController<List<ConnectivityResult>> _controller =
      StreamController<List<ConnectivityResult>>.broadcast();
  List<ConnectivityResult> _current;

  void push(List<ConnectivityResult> next) {
    _current = next;
    _controller.add(next);
  }

  Future<void> dispose() async {
    await _controller.close();
  }

  @override
  Future<List<ConnectivityResult>> check() async => _current;

  @override
  Stream<List<ConnectivityResult>> get onChanged => _controller.stream;
}

/// Adapter HTTP que devolve a resposta da fila — igual ao do
/// `dio_client_test.dart`, adaptado pra `SyncService`.
class _QueuedAdapter implements HttpClientAdapter {
  _QueuedAdapter(this.responses);

  final List<Object> responses;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (responses.isEmpty) {
      throw StateError('No more queued responses');
    }
    final Object next = responses.removeAt(0);
    if (next is DioException) {
      throw next;
    }
    if (next is ResponseBody) {
      return next;
    }
    throw StateError('Unsupported queued response: $next');
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _ok() {
  final List<int> body = utf8.encode(jsonEncode(<String, Object?>{'ok': true}));
  return ResponseBody.fromBytes(
    body,
    200,
    headers: <String, List<String>>{
      'content-type': <String>['application/json'],
    },
  );
}

DioException _netErr() {
  return DioException(
    requestOptions: RequestOptions(path: '/x'),
    type: DioExceptionType.connectionError,
    error: 'no internet',
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late OfflineQueue queue;
  late _FakeConnectivityWatcher connectivity;
  late Dio dio;
  late _QueuedAdapter adapter;

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: kSchemaVersion,
        onCreate: (Database db, int version) async {
          await runInitialMigrations(db);
        },
      ),
    );
    queue = OfflineQueue(db);
    connectivity = _FakeConnectivityWatcher();
    dio = Dio(BaseOptions(baseUrl: 'https://api.test/v1'));
    adapter = _QueuedAdapter(<Object>[]);
    dio.httpClientAdapter = adapter;
  });

  tearDown(() async {
    await connectivity.dispose();
    await queue.close();
  });

  PendingOperation buildOp(
    String id, {
    int attempts = 0,
    String idempotencyKey = 'idem',
  }) {
    return PendingOperation(
      id: id,
      method: 'POST',
      url: '/api/v1/packages',
      headers: <String, Object?>{'X-Condominium-Slug': 'central'},
      body: <String, Object?>{'tracking': 'AA1234'},
      idempotencyKey: idempotencyKey,
      createdAt: DateTime.utc(2026, 5, 23, 12),
      attempts: attempts,
      status: PendingOperationStatus.pending,
    );
  }

  group('SyncService — backoff', () {
    test('defaultBackoff segue progressão exponencial com cap em 60s', () {
      expect(SyncService.defaultBackoff(0), Duration.zero);
      expect(SyncService.defaultBackoff(1), const Duration(seconds: 1));
      expect(SyncService.defaultBackoff(2), const Duration(seconds: 2));
      expect(SyncService.defaultBackoff(3), const Duration(seconds: 4));
      expect(SyncService.defaultBackoff(4), const Duration(seconds: 8));
      expect(SyncService.defaultBackoff(5), const Duration(seconds: 16));
      expect(SyncService.defaultBackoff(6), const Duration(seconds: 32));
      expect(SyncService.defaultBackoff(7), const Duration(seconds: 60));
      expect(SyncService.defaultBackoff(20), const Duration(seconds: 60));
    });
  });

  group('SyncService — drenagem', () {
    test('transição offline → online dispara drenagem', () async {
      await queue.enqueue(buildOp('a'));
      adapter.responses.add(_ok());

      final SyncService sync = SyncService(
        queue: queue,
        dio: dio,
        connectivity: connectivity,
        backoffStrategy: (_) => Duration.zero,
      );
      addTearDown(sync.dispose);
      await sync.start();

      // Boot: offline ⇒ a fila ainda está cheia.
      expect(await queue.listPending(), hasLength(1));

      // Sobe a rede.
      connectivity.push(<ConnectivityResult>[ConnectivityResult.wifi]);
      // Aguarda o async do listener.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // Garante que terminou (drainNow espera o drain em curso).
      await sync.drainNow();

      expect(await queue.listPending(), isEmpty);
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.first.headers['Idempotency-Key'], 'idem');
      expect(adapter.requests.first.extra[SyncService.syncReplayFlag], isTrue);
    });

    test('drena no boot quando já está online', () async {
      // Já começa online.
      connectivity.push(<ConnectivityResult>[ConnectivityResult.mobile]);
      // O snapshot precisa estar setado antes do start() consultar:
      await Future<void>.delayed(Duration.zero);

      await queue.enqueue(buildOp('a'));
      adapter.responses.add(_ok());

      final SyncService sync = SyncService(
        queue: queue,
        dio: dio,
        connectivity: connectivity,
        backoffStrategy: (_) => Duration.zero,
      );
      addTearDown(sync.dispose);
      await sync.start();
      await sync.drainNow();

      expect(await queue.listPending(), isEmpty);
    });

    test(
      'após maxAttempts a operação vai para failed e não é mais tentada',
      () async {
        await queue.enqueue(buildOp('a'));
        // 3 falhas seguidas (maxAttempts = 3) — todas as tentativas.
        adapter.responses.addAll(<Object>[_netErr(), _netErr(), _netErr()]);

        connectivity.push(<ConnectivityResult>[ConnectivityResult.wifi]);

        final SyncService sync = SyncService(
          queue: queue,
          dio: dio,
          connectivity: connectivity,
          maxAttempts: 3,
          backoffStrategy: (_) => Duration.zero,
        );
        addTearDown(sync.dispose);
        await sync.start();
        await sync.drainNow();

        final List<PendingOperation> all = await queue.listAll();
        expect(all, hasLength(1));
        expect(all.single.status, PendingOperationStatus.failed);
        // 3 tentativas (2 incrementos + 1 markFailed na terceira).
        // attempts no banco: 2 (não incrementa antes do markFailed).
        expect(adapter.requests, hasLength(3));

        // Drena de novo: não deve tentar mais.
        await sync.drainNow();
        expect(adapter.requests, hasLength(3));
      },
    );

    test('sucesso no meio do retry remove a operação', () async {
      await queue.enqueue(buildOp('a'));
      adapter.responses.addAll(<Object>[_netErr(), _ok()]);

      connectivity.push(<ConnectivityResult>[ConnectivityResult.wifi]);

      final SyncService sync = SyncService(
        queue: queue,
        dio: dio,
        connectivity: connectivity,
        backoffStrategy: (_) => Duration.zero,
      );
      addTearDown(sync.dispose);
      await sync.start();
      await sync.drainNow();

      expect(await queue.listPending(), isEmpty);
      expect(adapter.requests, hasLength(2));
    });

    test('stateStream reflete operações + isOnline + isSyncing', () async {
      await queue.enqueue(buildOp('a'));
      adapter.responses.add(_ok());

      final SyncService sync = SyncService(
        queue: queue,
        dio: dio,
        connectivity: connectivity,
        backoffStrategy: (_) => Duration.zero,
      );
      addTearDown(sync.dispose);

      final List<SyncQueueState> states = <SyncQueueState>[];
      final StreamSubscription<SyncQueueState> sub = sync.stateStream.listen(
        states.add,
      );

      await sync.start();
      connectivity.push(<ConnectivityResult>[ConnectivityResult.wifi]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sync.drainNow();
      // Aguarda o stream entregar o último _emit (broadcast async).
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(states, isNotEmpty);
      // currentState é o snapshot síncrono final.
      expect(sync.currentState.isOnline, isTrue);
      expect(sync.currentState.operations, isEmpty);
      expect(sync.currentState.isSyncing, isFalse);
      // E o último evento entregue no stream também converge.
      final SyncQueueState last = states.last;
      expect(last.isOnline, isTrue);
      expect(last.isSyncing, isFalse);

      await sub.cancel();
    });

    test('não drena duas vezes em paralelo se chamada concorrente', () async {
      await queue.enqueue(buildOp('a'));
      adapter.responses.add(_ok());

      connectivity.push(<ConnectivityResult>[ConnectivityResult.wifi]);

      final SyncService sync = SyncService(
        queue: queue,
        dio: dio,
        connectivity: connectivity,
        backoffStrategy: (_) => Duration.zero,
      );
      addTearDown(sync.dispose);
      await sync.start();

      // Dois drainNow simultâneos.
      await Future.wait(<Future<void>>[sync.drainNow(), sync.drainNow()]);

      // Cada operação foi enviada exatamente uma vez.
      expect(adapter.requests, hasLength(1));
    });
  });
}
