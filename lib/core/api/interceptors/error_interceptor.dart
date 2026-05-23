import 'package:dio/dio.dart';

import '../api_error.dart';

/// Mapeia respostas de erro do back pro formato canônico [AppError].
///
/// Formato esperado no body:
/// ```json
/// {
///   "error": "ValidationError",
///   "message": "Dados inválidos",
///   "code": "VALIDATION_ERROR",
///   "details": { ... },
///   "requestId": "uuid"
/// }
/// ```
///
/// O [AppError] resultante é anexado em `DioException.error`, de modo
/// que o chamador faz:
/// ```dart
/// on DioException catch (e) {
///   final err = e.error;
///   if (err is AppError) { ... }
/// }
/// ```
///
/// O interceptor **não engole** o erro — segue propagando via
/// `handler.next(...)` para que retry/log e o chamador continuem
/// vendo o `DioException`.
class ErrorInterceptor extends Interceptor {
  /// Cria um [ErrorInterceptor].
  const ErrorInterceptor();

  /// Mapeamento `code` → mensagem pt-BR. Mantido propositalmente
  /// pequeno: códigos não mapeados caem no [_fallbackMessage].
  static const Map<String, String> _codeToUserMessage = <String, String>{
    'INVALID_CREDENTIALS': 'E-mail ou senha inválidos.',
    'MFA_REQUIRED': 'Verificação em duas etapas necessária.',
    'FORBIDDEN': 'Você não tem permissão para esta ação.',
    'NOT_FOUND': 'Recurso não encontrado.',
    'VALIDATION_ERROR': 'Dados inválidos. Confira os campos.',
    'RATE_LIMITED': 'Muitas tentativas. Aguarde um instante.',
  };

  static const String _fallbackMessage =
      'Não foi possível completar a ação. Tente novamente.';

  static const String _timeoutMessage = 'Conexão lenta. Tente novamente.';

  static const String _serverErrorMessage =
      'Serviço temporariamente indisponível.';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final AppError appError = _mapToAppError(err);
    final DioException enriched = err.copyWith(error: appError);
    handler.next(enriched);
  }

  AppError _mapToAppError(DioException err) {
    // Timeouts e falhas de conexão sem resposta.
    if (_isTimeout(err.type)) {
      return const AppError(
        code: 'NETWORK_TIMEOUT',
        userMessage: _timeoutMessage,
      );
    }
    if (err.type == DioExceptionType.connectionError) {
      return const AppError(
        code: 'NETWORK_ERROR',
        userMessage: _timeoutMessage,
      );
    }

    final Response<dynamic>? response = err.response;
    final int? status = response?.statusCode;
    final Object? data = response?.data;

    // Tenta extrair o formato canônico do back.
    if (data is Map<String, dynamic>) {
      final String? code = data['code'] as String?;
      final Map<String, dynamic>? details =
          data['details'] is Map<String, dynamic>
          ? data['details'] as Map<String, dynamic>
          : null;
      final String? requestId = data['requestId'] as String?;

      if (code != null && code.isNotEmpty) {
        return AppError(
          code: code,
          userMessage: _codeToUserMessage[code] ?? _fallbackMessage,
          details: details,
          requestId: requestId,
        );
      }
    }

    // Sem `code` no body: decide pelo status.
    if (status != null && status >= 500) {
      return const AppError(
        code: 'SERVER_ERROR',
        userMessage: _serverErrorMessage,
      );
    }

    return const AppError(code: 'UNKNOWN_ERROR', userMessage: _fallbackMessage);
  }

  bool _isTimeout(DioExceptionType type) =>
      type == DioExceptionType.connectionTimeout ||
      type == DioExceptionType.receiveTimeout ||
      type == DioExceptionType.sendTimeout;
}
