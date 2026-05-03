# LogiFree Mobile — Autenticação

> Referência: `../logifree-back-front/.claude/ia/LogiFree_Fluxo_Autenticacao.md`. Este doc cobre só o lado mobile.

---

## Fluxo

1. **Login:** `POST /auth/mobile/sign-in { email, password }` → `{ accessToken, refreshToken }`.
2. **Storage:** ambos em `flutter_secure_storage` (Keychain no iOS, Keystore no Android).
3. **Cada request HTTP:** `Authorization: Bearer <accessToken>` + `X-Condominium-Slug: <slug>` injetados pelo interceptor Dio.
4. **401 com `code: TOKEN_EXPIRED`:** interceptor chama `POST /auth/mobile/refresh { refreshToken }`. Substitui par no storage. Retry da request original.
5. **Refresh expirado/revogado:** força logout, limpa storage, navega para login.
6. **Logout manual:** `POST /auth/mobile/sign-out { refreshToken }` + clear storage.

---

## Tokens

- **Access token:** JWT, 15 minutos.
- **Refresh token:** opaque (não JWT), 30 dias, **rotativo** (cada uso invalida o anterior).
- **Reuso de refresh já consumido:** revoga toda a cadeia. Usuário forçado a relogar.

---

## Implementação

### `core/auth/auth_service.dart`
- `signIn({email, password})` → grava tokens.
- `refresh()` → rotaciona par.
- `signOut()` → limpa storage + chama backend.
- `isAuthenticated` getter (lê secure storage).

### `core/api/api_client.dart`
- Dio com `BaseOptions(baseUrl: Env.apiBaseUrl)`.
- `AuthInterceptor`:
  - `onRequest`: anexa `Authorization` se houver token.
  - `onError`: se 401 + `TOKEN_EXPIRED`, chama `refresh()` e retry.
  - Evitar loop infinito: max 1 retry por request.

### `core/storage/secure_storage.dart`
- Wrapper sobre `FlutterSecureStorage`.
- Chaves: `access_token`, `refresh_token`.

---

## Multi-tenant

Mobile guarda `currentCondominiumSlug` (também em secure_storage).
Quando porteiro trabalha em múltiplos condos, mostra picker de seleção (não tem header switcher como o web).

Header `X-Condominium-Slug` injetado em **toda** request, exceto endpoints de auth.

---

## MFA

Para `porteiro` MFA é opcional no MVP. Se backend retornar `code: MFA_REQUIRED`:
- Tela de input do código TOTP.
- `POST /auth/mobile/sign-in` com `mfaCode` no body.

---

## Erros comuns e mapeamento

Códigos do back-front (`@logifree/shared`) mapeiam para pt-BR:

```dart
const Map<String, String> errorMessages = {
  'INVALID_CREDENTIALS': 'Email ou senha incorretos.',
  'TOKEN_EXPIRED':       'Sessão expirada.',
  'TOKEN_REVOKED':       'Sessão inválida. Faça login novamente.',
  'MFA_REQUIRED':        'Código de autenticação obrigatório.',
  'ACCOUNT_LOCKED':      'Conta bloqueada por excesso de tentativas.',
  'TOO_MANY_ATTEMPTS':   'Muitas tentativas. Tente novamente em alguns minutos.',
};
```

Atualizar quando lista do back-front mudar.
