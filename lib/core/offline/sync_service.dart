import 'dart:async';
import 'dart:developer' as developer;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/dio_client.dart';
import '../storage/offline_queue.dart';
import 'pending_operation.dart';

/// Snapshot do estado da fila + sincronização (consumível pela UI).
class SyncQueueState {
  /// Cria um [SyncQueueState].
  const SyncQueueState({
    required this.operations,
    required this.isSyncing,
    required this.isOnline,
  });

  /// Estado inicial: nada na fila, sem syncing, offline assumido até
  /// o primeiro evento de conectividade.
  factory SyncQueueState.initial() => const SyncQueueState(
    operations: <PendingOperation>[],
    isSyncing: false,
    isOnline: false,
  );

  /// Todas as operações conhecidas (pendentes + sending + failed).
  final List<PendingOperation> operations;

  /// `true` enquanto o [SyncService] está drenando a fila.
  final bool isSyncing;

  /// Reflete o último resultado de [Connectivity.checkConnectivity].
  final bool isOnline;

  /// Cópia com campos sobrescritos.
  SyncQueueState copyWith({
    List<PendingOperation>? operations,
    bool? isSyncing,
    bool? isOnline,
  }) {
    return SyncQueueState(
      operations: operations ?? this.operations,
      isSyncing: isSyncing ?? this.isSyncing,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}

/// Abstração fina sobre o `connectivity_plus` — facilita testes sem
/// precisar mexer no `PlatformInterface` interno do plugin.
///
/// Implementação default ([DefaultConnectivityWatcher]) delega para
/// uma instância de [Connectivity]; testes podem fornecer uma
/// implementação custom com `Stream` controlado.
abstract class ConnectivityWatcher {
  /// Estado atual da conectividade.
  Future<List<ConnectivityResult>> check();

  /// Stream de mudanças.
  Stream<List<ConnectivityResult>> get onChanged;
}

/// Implementação padrão que delega para [Connectivity].
class DefaultConnectivityWatcher implements ConnectivityWatcher {
  /// Cria uma [DefaultConnectivityWatcher].
  DefaultConnectivityWatcher([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<List<ConnectivityResult>> check() => _connectivity.checkConnectivity();

  @override
  Stream<List<ConnectivityResult>> get onChanged =>
      _connectivity.onConnectivityChanged;
}

/// Drena a fila offline quando o app volta a ter conectividade.
///
/// **Responsabilidades:**
/// - Escutar [ConnectivityWatcher.onChanged].
/// - Disparar drenagem em toda transição offline → online.
/// - Aplicar backoff exponencial entre tentativas.
/// - Marcar como `failed` após [maxAttempts].
/// - Expor estado consolidado via [stateStream].
///
/// **Não usa `Dio` direto para reenvio:** recebe um `Dio` pronto (com
/// os outros interceptors), monta uma `RequestOptions` a partir da
/// [PendingOperation], e dispara `dio.fetch`. Para evitar loop com o
/// próprio [OfflineFallbackInterceptor], a request é marcada com
/// `extra['_syncReplay'] = true` — esse interceptor checa e ignora.
class SyncService {
  /// Cria um [SyncService] e **não** começa a escutar até que [start]
  /// seja chamado.
  SyncService({
    required OfflineQueue queue,
    required Dio dio,
    required ConnectivityWatcher connectivity,
    this.maxAttempts = 5,
    Duration Function(int attempts)? backoffStrategy,
  }) : _queue = queue,
       _dio = dio,
       _connectivity = connectivity,
       _backoffStrategy = backoffStrategy ?? defaultBackoff;

  /// Estratégia padrão: 1s, 2s, 4s, 8s, 16s... (cap em 60s).
  ///
  /// [attempts] é o número de tentativas **já feitas** — para a primeira
  /// retentativa, vale 1.
  static Duration defaultBackoff(int attempts) {
    if (attempts <= 0) {
      return Duration.zero;
    }
    final int seconds = 1 << (attempts - 1); // 1, 2, 4, 8, 16, 32...
    final int capped = seconds > 60 ? 60 : seconds;
    return Duration(seconds: capped);
  }

  final OfflineQueue _queue;
  final Dio _dio;
  final ConnectivityWatcher _connectivity;
  final Duration Function(int attempts) _backoffStrategy;

  /// Limite de tentativas. Após este número, a operação vira `failed`.
  final int maxAttempts;

  static const String _loggerName = 'logifree.sync';

  /// Flag que sinaliza para o [OfflineFallbackInterceptor] que aquela
  /// request é uma retentativa controlada pelo [SyncService] e **não**
  /// deve ser enfileirada novamente.
  static const String syncReplayFlag = '_syncReplay';

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  StreamSubscription<List<PendingOperation>>? _queueSub;

  bool _isOnline = false;
  bool _isSyncing = false;
  bool _disposed = false;
  Completer<void>? _drainCompleter;

  final StreamController<SyncQueueState> _state =
      StreamController<SyncQueueState>.broadcast();
  SyncQueueState _currentState = SyncQueueState.initial();

  /// Stream com o estado consolidado da fila.
  Stream<SyncQueueState> get stateStream => _state.stream;

  /// Último estado emitido (síncrono).
  SyncQueueState get currentState => _currentState;

  /// Inicia a escuta de conectividade e o relay do snapshot da fila.
  ///
  /// É seguro chamar mais de uma vez — chamadas subsequentes são no-op.
  Future<void> start() async {
    if (_connSub != null || _disposed) {
      return;
    }

    // Relay do snapshot da fila para o state stream.
    _queueSub = _queue.changes.listen((List<PendingOperation> ops) {
      _emit(_currentState.copyWith(operations: ops));
    });

    // Snapshot inicial das pendências.
    final List<PendingOperation> initial = await _queue.listAll();
    _emit(_currentState.copyWith(operations: initial));

    // Estado de conectividade inicial.
    final List<ConnectivityResult> first = await _connectivity.check();
    _isOnline = _hasNetwork(first);
    _emit(_currentState.copyWith(isOnline: _isOnline));

    // Escuta mudanças.
    _connSub = _connectivity.onChanged.listen(_handleConnectivityChange);

    // Se já está online no boot e existem pendências, drena.
    if (_isOnline) {
      unawaited(_drain());
    }
  }

  /// Encerra streams e libera recursos.
  Future<void> dispose() async {
    _disposed = true;
    await _connSub?.cancel();
    await _queueSub?.cancel();
    if (!_state.isClosed) {
      await _state.close();
    }
  }

  /// Força uma drenagem (útil para botões "tentar novamente" na UI).
  ///
  /// Se já está drenando, devolve o `Future` da drenagem em andamento.
  Future<void> drainNow() {
    if (_drainCompleter != null && !_drainCompleter!.isCompleted) {
      return _drainCompleter!.future;
    }
    return _drain();
  }

  /// Força uma nova tentativa de uma operação específica.
  ///
  /// Útil para a tela de pendências (CARD-022): o usuário toca em
  /// "Tentar novamente" em um item que já chegou em `failed` ou que
  /// está parado e quer empurrar manualmente.
  ///
  /// O fluxo é:
  /// 1. Reseta `attempts` para 0 (usando [OfflineQueue.resetForRetry]).
  /// 2. Volta o status para `pending`.
  /// 3. Dispara uma drenagem (se possível — exige estar online).
  ///
  /// Se a operação não existe na fila, é no-op silencioso.
  Future<void> retry(String id) async {
    final PendingOperation? op = await _queue.findById(id);
    if (op == null) {
      return;
    }
    await _queue.resetForRetry(id);
    if (_isOnline) {
      unawaited(drainNow());
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final bool wasOnline = _isOnline;
    final bool nowOnline = _hasNetwork(results);
    _isOnline = nowOnline;
    _emit(_currentState.copyWith(isOnline: nowOnline));

    if (!wasOnline && nowOnline) {
      developer.log(
        'connectivity restored — draining queue',
        name: _loggerName,
      );
      unawaited(_drain());
    }
  }

  Future<void> _drain() async {
    if (_isSyncing || _disposed) {
      return;
    }
    _isSyncing = true;
    _drainCompleter = Completer<void>();
    _emit(_currentState.copyWith(isSyncing: true));

    try {
      List<PendingOperation> pending = await _queue.listPending();
      while (pending.isNotEmpty && _isOnline && !_disposed) {
        final PendingOperation op = pending.first;
        await _processOne(op);
        // Recarrega pra refletir mudanças (markDone / increment / failed).
        pending = await _queue.listPending();
      }
    } finally {
      _isSyncing = false;
      _emit(_currentState.copyWith(isSyncing: false));
      if (!_drainCompleter!.isCompleted) {
        _drainCompleter!.complete();
      }
    }
  }

  Future<void> _processOne(PendingOperation op) async {
    // Backoff entre tentativas (a partir da 2ª).
    if (op.attempts > 0) {
      final Duration delay = _backoffStrategy(op.attempts);
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
    }
    if (!_isOnline || _disposed) {
      return;
    }

    await _queue.markSending(op.id);
    try {
      await _dispatch(op);
      await _queue.markDone(op.id);
      developer.log(
        'synced ${op.method} ${op.url} (id=${op.id})',
        name: _loggerName,
      );
    } on DioException catch (e) {
      await _onFailure(op, _describeError(e));
    } on Object catch (e) {
      await _onFailure(op, e.toString());
    }
  }

  Future<void> _dispatch(PendingOperation op) async {
    final Map<String, dynamic> headers = <String, dynamic>{
      ...op.headers,
      'Idempotency-Key': op.idempotencyKey,
    };
    final RequestOptions options = RequestOptions(
      path: op.url,
      method: op.method,
      data: op.body,
      headers: headers,
      extra: <String, dynamic>{syncReplayFlag: true},
    );
    await _dio.fetch<dynamic>(options);
  }

  Future<void> _onFailure(PendingOperation op, String error) async {
    final int newAttempts = op.attempts + 1;
    if (newAttempts >= maxAttempts) {
      await _queue.markFailed(op.id, error);
      developer.log(
        'op ${op.id} reached maxAttempts ($maxAttempts) — marked failed',
        name: _loggerName,
      );
    } else {
      await _queue.incrementAttempts(op.id, lastError: error);
      developer.log(
        'op ${op.id} failed (attempt $newAttempts): $error',
        name: _loggerName,
      );
    }
  }

  String _describeError(DioException e) {
    final int? status = e.response?.statusCode;
    if (status != null) {
      return 'HTTP $status (${e.type.name})';
    }
    return e.type.name;
  }

  void _emit(SyncQueueState state) {
    _currentState = state;
    if (!_state.isClosed) {
      _state.add(state);
    }
  }

  /// `true` se a lista de conectividade indica alguma rede ativa.
  ///
  /// Considera **qualquer** valor diferente de `none` como online.
  /// `connectivity_plus` 6+/7+ devolve `List` porque um device pode
  /// ter wifi + mobile + bluetooth simultaneamente.
  static bool _hasNetwork(List<ConnectivityResult> results) {
    if (results.isEmpty) {
      return false;
    }
    return results.any((ConnectivityResult r) => r != ConnectivityResult.none);
  }
}

/// Provider Riverpod do [Connectivity] (singleton).
final Provider<Connectivity> connectivityProvider = Provider<Connectivity>(
  (Ref ref) => Connectivity(),
);

/// Provider Riverpod do [ConnectivityWatcher] (singleton).
///
/// Em testes, sobrescreva este provider com uma implementação fake
/// para controlar o stream de conectividade.
final Provider<ConnectivityWatcher> connectivityWatcherProvider =
    Provider<ConnectivityWatcher>(
      (Ref ref) => DefaultConnectivityWatcher(ref.watch(connectivityProvider)),
    );

/// Provider Riverpod do [SyncService].
///
/// Construído com `FutureProvider` porque o [OfflineQueue] é assíncrono.
/// O provider **não** chama `start()` automaticamente — quem inicializa
/// o serviço é o `main.dart` (warm-up explícito), garantindo um ponto
/// único de boot.
final FutureProvider<SyncService> syncServiceProvider =
    FutureProvider<SyncService>((Ref ref) async {
      final OfflineQueue queue = await ref.watch(offlineQueueProvider.future);
      final Dio dio = ref.watch(dioClientProvider);
      final ConnectivityWatcher connectivity = ref.watch(
        connectivityWatcherProvider,
      );
      final SyncService service = SyncService(
        queue: queue,
        dio: dio,
        connectivity: connectivity,
      );
      ref.onDispose(service.dispose);
      return service;
    });
