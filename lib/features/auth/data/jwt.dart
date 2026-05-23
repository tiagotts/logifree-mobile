import 'dart:convert';

/// Decodifica o payload (parte central) de um JWT.
///
/// Devolve `null` se o token estiver malformado. Não valida assinatura —
/// validação é responsabilidade do back; o cliente só lê o que está
/// dentro para extrair `sub`, `exp`, etc.
Map<String, dynamic>? decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;

  var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
  while (payload.length % 4 != 0) {
    payload += '=';
  }

  try {
    final decoded = utf8.decode(base64.decode(payload));
    final result = jsonDecode(decoded);
    if (result is Map<String, dynamic>) return result;
    return null;
  } on Object {
    return null;
  }
}

/// Retorna o instante de expiração do JWT, ou `null` se não houver `exp`.
DateTime? jwtExpiry(String token) {
  final payload = decodeJwtPayload(token);
  if (payload == null) return null;
  final exp = payload['exp'];
  if (exp is! int) return null;
  return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
}
