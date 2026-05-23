import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../offline/pending_operation.dart';
import '../../offline/sync_service.dart';
import '../../storage/offline_queue.dart';

/// Status HTTP "sintético" devolvido ao chamador quando uma operação
/// foi enfileirada em vez de enviada.
///
/// Optamos por **202 Accepted** porque semanticamente significa
/// "recebi sua intenção, ainda não está concluída". A UI deve tratar
/// 2xx como sucesso e exibir um toast informativo ("Salvo offline").
const int kOfflineEnqueuedStatus = 202;

/// Chave em `extra` do `Response` para distinguir um sucesso real de
/// um enqueue. UI pode checar e mudar o toast.
const String kOfflineEnqueuedExtraKey = 'offline_enqueued';

/// Métodos HTTP que devem ser enfileirados em caso de falha de rede.
const Set<String> _mutatingMethods = <String>{'POST', 'PUT', 'PATCH', 'DELETE'};

/// Intercepta falhas de rede em métodos mutadores e enfileira a
/// operação para sincronização futura.
///
/// **Ordem no `Dio.interceptors`:** deve vir **antes** do
/// [RetryInterceptor] e do [ErrorInterceptor], para conseguir
/// "resolver" a request com o response sintético em vez de propagar
/// o erro.
///
/// **Quando ignora:**
/// - GET / HEAD (não mutadores).
/// - Requests marcadas com `extra[SyncService.syncReplayFlag] == true`
///   (são retentativas do próprio [SyncService]).
/// - Erros que não são de rede (status HTTP 4xx/5xx vindos do servidor).
class OfflineFallbackInterceptor extends Interceptor {
  /// Cria um [OfflineFallbackInterceptor].
  ///
  /// O [uuid] é injetado para facilitar testes (UUIDs determinísticos).
  /// Em produção, usa o default `const Uuid()`.
  OfflineFallbackInterceptor({required OfflineQueue queue, Uuid? uuid})
    : _queue = queue,
      _uuid = uuid ?? const Uuid();

  final OfflineQueue _queue;
  final Uuid _uuid;

  static const String _loggerName = 'logifree.offline';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final RequestOptions options = err.requestOptions;

    // Sync replay: deixa propagar para o SyncService tratar.
    if (options.extra[SyncService.syncReplayFlag] == true) {
      handler.next(err);
      return;
    }

    if (!_shouldEnqueue(err, options)) {
      handler.next(err);
      return;
    }

    try {
      final PendingOperation op = _buildOperation(options);
      await _queue.enqueue(op);

      developer.log(
        'enqueued ${op.method} ${op.url} (id=${op.id})',
        name: _loggerName,
      );

      final Response<dynamic> syntheticResponse = Response<dynamic>(
        requestOptions: options,
        statusCode: kOfflineEnqueuedStatus,
        statusMessage: 'Accepted (offline queue)',
        data: <String, Object?>{
          'enqueued': true,
          'operationId': op.id,
          'idempotencyKey': op.idempotencyKey,
        },
        extra: <String, dynamic>{
          kOfflineEnqueuedExtraKey: true,
          'operationId': op.id,
        },
      );
      handler.resolve(syntheticResponse);
    } on Object catch (e, st) {
      // Se enfileirar falhou (banco corrompido?), propaga o erro
      // original — chamador pelo menos vê um erro coerente.
      developer.log(
        'failed to enqueue offline operation: $e',
        name: _loggerName,
        error: e,
        stackTrace: st,
      );
      handler.next(err);
    }
  }

  /// Decide se a falha caracteriza um cenário offline.
  ///
  /// Cobertura:
  /// - `DioExceptionType.connectionTimeout` / `connectionError`
  /// - `DioExceptionType.unknown` cuja causa subjacente é uma
  ///   `SocketException` (sem internet, DNS falhou etc.).
  bool _shouldEnqueue(DioException err, RequestOptions options) {
    final String method = options.method.toUpperCase();
    if (!_mutatingMethods.contains(method)) {
      return false;
    }
    // Endpoints de auth (sign-in, refresh, sign-out, password reset/change)
    // NUNCA devem ir para a fila offline: sem servidor não há token,
    // e o body contém credenciais sensíveis que não devem ser persistidas
    // em disco. A falha deve propagar para o chamador exibir o erro.
    if (_isAuthEndpoint(options.path)) {
      return false;
    }
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.unknown:
        // `unknown` com erro de socket = sem rede. Identificamos pelo
        // nome do tipo para evitar import de `dart:io`, que quebra web.
        final Object? cause = err.error;
        if (cause == null) {
          return false;
        }
        final String typeName = cause.runtimeType.toString();
        return typeName.contains('SocketException') ||
            typeName.contains('HttpException');
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
        return false;
    }
  }

  PendingOperation _buildOperation(RequestOptions options) {
    final String id = _safeUuidV7();
    // A idempotency-key acompanha a operação **para sempre** — mesmo
    // valor em todas as retentativas. Se o chamador já passou uma,
    // respeitamos; caso contrário, geramos uma nova UUID v7.
    final Object? existingKey = options.headers['Idempotency-Key'];
    final String idempotencyKey =
        existingKey is String && existingKey.isNotEmpty
        ? existingKey
        : _safeUuidV7();

    // Headers serializáveis: drop tudo que não for primitivo/list/map.
    // (Em particular `Authorization` é dropado — o SyncService
    // reanexa no momento do envio através do AuthInterceptor, quando
    // este existir.)
    final Map<String, Object?> headers = <String, Object?>{};
    options.headers.forEach((String k, Object? v) {
      if (k.toLowerCase() == 'authorization') {
        return;
      }
      if (v is String || v is num || v is bool || v == null) {
        headers[k] = v;
      } else if (v is List<Object?>) {
        headers[k] = v;
      } else {
        headers[k] = v.toString();
      }
    });

    return PendingOperation(
      id: id,
      method: options.method.toUpperCase(),
      url: _absoluteUrl(options),
      headers: headers,
      body: _normalizeBody(options.data),
      idempotencyKey: idempotencyKey,
      createdAt: DateTime.now().toUtc(),
      attempts: 0,
      status: PendingOperationStatus.pending,
    );
  }

  String _absoluteUrl(RequestOptions options) {
    final String base = options.baseUrl;
    final String path = options.path;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    if (base.isEmpty) {
      return path;
    }
    final bool baseHasSlash = base.endsWith('/');
    final bool pathHasSlash = path.startsWith('/');
    if (baseHasSlash && pathHasSlash) {
      return '$base${path.substring(1)}';
    }
    if (!baseHasSlash && !pathHasSlash) {
      return '$base/$path';
    }
    return '$base$path';
  }

  Object? _normalizeBody(Object? data) {
    if (data == null) {
      return null;
    }
    if (data is Map<Object?, Object?> ||
        data is List<Object?> ||
        data is String ||
        data is num ||
        data is bool) {
      return data;
    }
    // FormData e similares não são JSON-serializáveis — armazenamos
    // a representação `toString()` como fallback (operações com
    // upload binário ficam fora do escopo do MVP offline).
    return data.toString();
  }

  /// Identifica rotas de autenticação, que nunca devem ser enfileiradas.
  static bool _isAuthEndpoint(String path) {
    return path.startsWith('/auth/') || path.startsWith('auth/');
  }

  /// Tenta `v7`; se a versão do pacote `uuid` no ambiente não tiver,
  /// cai para `v4`. Garante que nunca quebramos no runtime.
  String _safeUuidV7() {
    try {
      return _uuid.v7();
    } on NoSuchMethodError {
      return _uuid.v4();
    }
  }
}

/// Provider Riverpod do [OfflineFallbackInterceptor].
///
/// Espera o [offlineQueueProvider] estar pronto.
final FutureProvider<OfflineFallbackInterceptor>
offlineFallbackInterceptorProvider = FutureProvider<OfflineFallbackInterceptor>(
  (Ref ref) async {
    final OfflineQueue queue = await ref.watch(offlineQueueProvider.future);
    return OfflineFallbackInterceptor(queue: queue);
  },
);
