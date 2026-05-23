import 'package:dio/dio.dart';

/// Retenta uma única vez requests que falham por causas transitórias.
///
/// Critério de retry:
/// - HTTP 5xx
/// - Timeout (`connectionTimeout`, `receiveTimeout`, `sendTimeout`)
///
/// **Não retenta** em 4xx — erro do cliente não vai melhorar com
/// nova tentativa.
///
/// Marca a request com `_retryAttempted` em `RequestOptions.extra`
/// para garantir no máximo uma tentativa adicional, mesmo que o
/// interceptor entre no fluxo várias vezes.
class RetryInterceptor extends Interceptor {
  /// Cria um [RetryInterceptor] que usa o [Dio] passado para
  /// reexecutar a request original.
  RetryInterceptor(this._dio);

  final Dio _dio;

  static const String _retryFlag = '_retryAttempted';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_shouldRetry(err)) {
      handler.next(err);
      return;
    }

    final RequestOptions options = err.requestOptions;
    final bool alreadyRetried = options.extra[_retryFlag] == true;
    if (alreadyRetried) {
      handler.next(err);
      return;
    }

    options.extra[_retryFlag] = true;

    try {
      final Response<dynamic> response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _shouldRetry(DioException err) {
    if (_isTimeout(err.type)) {
      return true;
    }
    final int? status = err.response?.statusCode;
    return status != null && status >= 500 && status < 600;
  }

  bool _isTimeout(DioExceptionType type) =>
      type == DioExceptionType.connectionTimeout ||
      type == DioExceptionType.receiveTimeout ||
      type == DioExceptionType.sendTimeout;
}
