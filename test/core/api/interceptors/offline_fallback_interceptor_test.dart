import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logifree_mobile/core/api/interceptors/offline_fallback_interceptor.dart';
import 'package:logifree_mobile/core/offline/pending_operation.dart';
import 'package:logifree_mobile/core/offline/sync_service.dart';
import 'package:logifree_mobile/core/storage/migrations.dart';
import 'package:logifree_mobile/core/storage/offline_queue.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _ErrorAdapter implements HttpClientAdapter {
  _ErrorAdapter(this.error);

  final DioException error;
  int callCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    callCount++;
    throw error.copyWith(requestOptions: options);
  }

  @override
  void close({bool force = false}) {}
}

class _OkAdapter implements HttpClientAdapter {
  int callCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    callCount++;
    final List<int> body = utf8.encode(
      jsonEncode(<String, Object?>{'ok': true}),
    );
    return ResponseBody.fromBytes(
      body,
      200,
      headers: <String, List<String>>{
        'content-type': <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late OfflineQueue queue;

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: kSchemaVersion,
        onCreate: (Database d, int v) async {
          await runInitialMigrations(d);
        },
      ),
    );
    queue = OfflineQueue(db);
  });

  tearDown(() async {
    await queue.close();
  });

  Dio buildDio(HttpClientAdapter adapter) {
    final Dio dio = Dio(BaseOptions(baseUrl: 'https://api.test/v1'));
    dio.interceptors.add(OfflineFallbackInterceptor(queue: queue));
    dio.httpClientAdapter = adapter;
    return dio;
  }

  group('OfflineFallbackInterceptor', () {
    test('POST com falha de rede enfileira e devolve 202 sintético', () async {
      final _ErrorAdapter adapter = _ErrorAdapter(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
          error: 'no internet',
        ),
      );
      final Dio dio = buildDio(adapter);

      final Response<dynamic> response = await dio.post<dynamic>(
        '/packages',
        data: <String, Object?>{'tracking': 'AA1234'},
      );

      expect(response.statusCode, 202);
      expect(response.extra['offline_enqueued'], isTrue);
      expect(response.extra['operationId'], isA<String>());

      final List<PendingOperation> all = await queue.listAll();
      expect(all, hasLength(1));
      final PendingOperation op = all.single;
      expect(op.method, 'POST');
      expect(op.url, 'https://api.test/v1/packages');
      expect((op.body! as Map<String, Object?>)['tracking'], 'AA1234');
      expect(op.status, PendingOperationStatus.pending);
      expect(op.idempotencyKey, isNotEmpty);
    });

    test('PUT com connectionTimeout também enfileira', () async {
      final _ErrorAdapter adapter = _ErrorAdapter(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionTimeout,
        ),
      );
      final Dio dio = buildDio(adapter);

      final Response<dynamic> response = await dio.put<dynamic>('/packages/1');
      expect(response.statusCode, 202);
      expect(await queue.listAll(), hasLength(1));
    });

    test('PATCH e DELETE também enfileiram', () async {
      final _ErrorAdapter adapter = _ErrorAdapter(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      );
      final Dio dio = buildDio(adapter);

      await dio.patch<dynamic>('/packages/1');
      await dio.delete<dynamic>('/packages/2');

      expect(await queue.listAll(), hasLength(2));
    });

    test('GET com falha de rede NÃO enfileira — propaga erro', () async {
      final _ErrorAdapter adapter = _ErrorAdapter(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      );
      final Dio dio = buildDio(adapter);

      bool threw = false;
      try {
        await dio.get<dynamic>('/packages');
      } on DioException catch (_) {
        threw = true;
      }
      expect(threw, isTrue);
      expect(await queue.listAll(), isEmpty);
    });

    test('POST com sucesso (sem erro) não toca na fila', () async {
      final _OkAdapter adapter = _OkAdapter();
      final Dio dio = buildDio(adapter);

      final Response<dynamic> response = await dio.post<dynamic>(
        '/packages',
        data: <String, Object?>{'tracking': 'AA1234'},
      );
      expect(response.statusCode, 200);
      expect(await queue.listAll(), isEmpty);
    });

    test('request marcada como syncReplay NÃO é enfileirada', () async {
      final _ErrorAdapter adapter = _ErrorAdapter(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      );
      final Dio dio = buildDio(adapter);

      bool threw = false;
      try {
        await dio.post<dynamic>(
          '/packages',
          options: Options(
            extra: <String, dynamic>{SyncService.syncReplayFlag: true},
          ),
        );
      } on DioException catch (_) {
        threw = true;
      }
      expect(threw, isTrue);
      expect(await queue.listAll(), isEmpty);
    });

    test('respeita Idempotency-Key fornecido pelo chamador', () async {
      final _ErrorAdapter adapter = _ErrorAdapter(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      );
      final Dio dio = buildDio(adapter);

      await dio.post<dynamic>(
        '/packages',
        options: Options(
          headers: <String, dynamic>{'Idempotency-Key': 'meu-id-fixo'},
        ),
        data: <String, Object?>{'x': 1},
      );

      final PendingOperation op = (await queue.listAll()).single;
      expect(op.idempotencyKey, 'meu-id-fixo');
    });

    test('erro 4xx do servidor NÃO enfileira (não é falha de rede)', () async {
      // badResponse com status 400 — não é cenário offline.
      final _ErrorAdapter adapter = _ErrorAdapter(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: 400,
          ),
          type: DioExceptionType.badResponse,
        ),
      );
      final Dio dio = buildDio(adapter);

      bool threw = false;
      try {
        await dio.post<dynamic>('/packages');
      } on DioException catch (_) {
        threw = true;
      }
      expect(threw, isTrue);
      expect(await queue.listAll(), isEmpty);
    });

    test('header Authorization NÃO é persistido na fila', () async {
      final _ErrorAdapter adapter = _ErrorAdapter(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      );
      final Dio dio = buildDio(adapter);

      await dio.post<dynamic>(
        '/packages',
        options: Options(
          headers: <String, dynamic>{
            'Authorization': 'Bearer SECRET',
            'X-Condominium-Slug': 'central',
          },
        ),
      );

      final PendingOperation op = (await queue.listAll()).single;
      expect(op.headers.containsKey('Authorization'), isFalse);
      expect(op.headers['X-Condominium-Slug'], 'central');
    });
  });
}
