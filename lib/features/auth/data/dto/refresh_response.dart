/// Resposta canônica do `POST /api/v1/auth/refresh`.
///
/// O backend faz rotação: a cada refresh, devolve um par novo
/// `(accessToken, refreshToken)` e invalida o `refreshToken` antigo.
class RefreshResponse {
  const RefreshResponse({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;

  factory RefreshResponse.fromJson(Map<String, dynamic> json) {
    return RefreshResponse(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
    );
  }
}
