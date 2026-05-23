/// Erro canônico do app, pronto pra UI.
///
/// Mapeado a partir do formato padronizado de erro do back
/// (`{ error, message, code, details, requestId }`) pelo
/// [ErrorInterceptor]. O campo [userMessage] já vem em pt-BR,
/// pronto pra ser exibido ao usuário (snackbar, dialog etc.).
///
/// Exemplo:
/// ```dart
/// try {
///   await dio.post('/auth/sign-in', data: ...);
/// } on DioException catch (e) {
///   if (e.error is AppError) {
///     final err = e.error! as AppError;
///     showSnackbar(err.userMessage);
///   }
/// }
/// ```
class AppError implements Exception {
  /// Cria um [AppError].
  const AppError({
    required this.code,
    required this.userMessage,
    this.details,
    this.requestId,
  });

  /// Código semântico do erro (ex.: `INVALID_CREDENTIALS`, `NOT_FOUND`).
  ///
  /// Vem do campo `code` do body do back. Quando não há body,
  /// recebe códigos sintéticos como `NETWORK_TIMEOUT` ou `SERVER_ERROR`.
  final String code;

  /// Mensagem em pt-BR pronta pra exibir ao usuário.
  final String userMessage;

  /// Detalhes adicionais do erro (campos inválidos, contexto extra).
  ///
  /// Estrutura varia por endpoint — consumidor decide como interpretar.
  final Map<String, dynamic>? details;

  /// ID da request para correlacionar com logs do back/Sentry.
  final String? requestId;

  @override
  String toString() =>
      'AppError(code: $code, userMessage: $userMessage, requestId: $requestId)';
}
