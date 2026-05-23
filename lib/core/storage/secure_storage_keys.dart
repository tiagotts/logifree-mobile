/// Chaves usadas pelo [SecureStorage] do app.
///
/// Centralizar aqui evita typos e facilita auditoria de quais dados
/// sensíveis o app persiste no Keychain (iOS) / Keystore (Android).
class SecureStorageKeys {
  const SecureStorageKeys._();

  /// JWT de acesso (curta duração — 15 min).
  static const String accessToken = 'access_token';

  /// JWT de refresh rotativo (30 dias).
  static const String refreshToken = 'refresh_token';

  /// Slug do condomínio selecionado para o header `X-Condominium-Slug`.
  static const String selectedCondominiumSlug = 'selected_condominium_slug';

  /// ID do usuário autenticado (extraído do JWT no login).
  static const String userId = 'user_id';

  /// Snapshot JSON do `UserDto` (nome, e-mail, memberships).
  ///
  /// Usado pelo splash para reconstruir a sessão sem precisar de chamada
  /// `/me` extra. Atualizado a cada sign-in.
  static const String userSnapshot = 'user_snapshot';
}
