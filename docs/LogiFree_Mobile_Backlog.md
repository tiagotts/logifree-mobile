# LogiFree Mobile — Backlog

Cards detalhados para sair do **POC** (apenas OCR + ScanScreen com `setState`) até o **MVP de porteiro** descrito em `LogiFree_Mobile_Telas.md`.

> **Como usar este documento**
>
> - Cada card tem **contexto**, **dependências**, **arquivos afetados/criados**, **passos**, **critérios de aceite** e **esforço estimado**.
> - O agente `mobile-backlog-manager` lê este arquivo antes de priorizar.
> - Quem implementa: `mobile-flutter` (código), `mobile-tester` (testes), `mobile-code-reviewer` (revisão).
> - **Ordem sugerida**: Fundação (INFRA) → Auth → Scan production-ready → Packages → Delivery → Polish.
>
> Esforço: `rápido` (<2h), `médio` (meio dia), `grande` (1+ dia), `épico` (vários dias).

---

## Resumo executivo

| Bloco | Cards | Esforço total | Bloqueia |
|-------|-------|---------------|----------|
| INFRA — fundação técnica | 6 (001-006) | 2-3 dias | Tudo |
| AUTH — autenticação | 4 (007-010) | 2-3 dias | Tudo autenticado |
| SCAN — POC → produção | 3 (011-013) | 1-2 dias | Recebimento |
| PACKAGES — recebimento e listagem | 4 (014-017) | 3-4 dias | Delivery |
| DELIVERY — entrega e devolução | 3 (018-020) | 1-2 dias | MVP |
| OFFLINE — fila local | 2 (021-022) | 2-3 dias | Robustez |
| OBSERVABILITY — Sentry + Shorebird | 2 (023-024) | 1 dia | Produção |
| POLISH — UX, settings, MFA | 3 (025-027) | 1-2 dias | Lançamento |

**Total estimado:** ~13-20 dias de trabalho focado.

---

## Estado atual (auditoria do código)

✅ **Existe:**
- `lib/main.dart` — `MyApp` com `MaterialApp` direto
- `lib/features/scan/data/ocr_service.dart` — wrapper Google ML Kit
- `lib/features/scan/data/ocr_result.dart` — value object
- `lib/features/scan/presentation/scan_screen.dart` — `StatefulWidget` com `setState` (POC)
- `test/test_helpers/` — infra de teste com mocktail
- `test/features/scan/data/ocr_result_test.dart` — testes de OcrResult

❌ **Não existe:**
- Nenhum diretório `lib/core/`, `lib/shared/`, `app.dart`
- Features `auth`, `packages`, `delivery`
- Riverpod, go_router, Dio, Sentry, Shorebird, sqflite, connectivity_plus, flutter_secure_storage, freezed, build_runner
- Code generation pipeline
- Lints estritos no `analysis_options.yaml`
- `--dart-define` reading em `core/config/env.dart`

---

# BLOCO 1 — INFRA (fundação)

Sem esse bloco, nada autenticado funciona. Tem que vir primeiro.

---

## CARD-MOBILE-001 — Adicionar lints estritos e formatação 🟢

**Contexto.** `analysis_options.yaml` hoje só importa `flutter_lints`. Sem `strict-casts`, `strict-inference`, `prefer_single_quotes`, `require_trailing_commas` e `avoid_print` o time não consegue manter as convenções descritas em `CLAUDE.md`.

**Esforço:** rápido (1h).

**Dependências:** nenhuma. **Começar por aqui — destrava qualidade desde o dia 1.**

**Arquivos afetados:**
- `analysis_options.yaml`

**Passos:**

1. Substituir conteúdo por:

   ```yaml
   include: package:flutter_lints/flutter.yaml

   analyzer:
     language:
       strict-casts: true
       strict-inference: true
       strict-raw-types: true
     errors:
       missing_required_param: error
       missing_return: error
       todo: ignore

   linter:
     rules:
       prefer_single_quotes: true
       require_trailing_commas: true
       avoid_print: true
       prefer_const_constructors: true
       prefer_const_literals_to_create_immutables: true
       sort_child_properties_last: true
       use_key_in_widget_constructors: true
   ```

2. Rodar `dart format lib/ test/`.
3. Rodar `flutter analyze` e corrigir os warnings/errors expostos.

**Critérios de aceite:**
- `flutter analyze` retorna 0 issues.
- Código existente formatado conforme regras (aspas simples, trailing commas).

---

## CARD-MOBILE-002 — Instalar stack de dependências base 🔴

**Contexto.** O `pubspec.yaml` hoje só tem o necessário pro POC. Pra implementar qualquer feature do MVP precisamos do stack-alvo de `docs/LogiFree_Mobile_Stack.md`.

**Esforço:** rápido (30min). É só adicionar dependências; configuração vem nos cards seguintes.

**Dependências:** CARD-MOBILE-001.

**Arquivos afetados:**
- `pubspec.yaml`

**Passos:**

1. Adicionar em `dependencies`:

   ```yaml
   # State + routing
   flutter_riverpod: ^2.5.1
   riverpod_annotation: ^2.3.5
   go_router: ^14.2.0

   # HTTP + auth + storage
   dio: ^5.7.0
   flutter_secure_storage: ^9.2.2

   # Offline
   sqflite: ^2.3.3
   connectivity_plus: ^6.0.5
   path: ^1.9.0

   # Câmera
   camera: ^0.11.0
   permission_handler: ^11.3.1

   # Data classes
   freezed_annotation: ^2.4.4
   json_annotation: ^4.9.0

   # Observabilidade
   sentry_flutter: ^8.9.0
   shorebird_code_push: ^1.1.4

   # Utilitários
   intl: ^0.19.0
   uuid: ^4.4.2
   ```

2. Adicionar em `dev_dependencies`:

   ```yaml
   build_runner: ^2.4.11
   freezed: ^2.5.7
   json_serializable: ^6.8.0
   riverpod_generator: ^2.4.3
   custom_lint: ^0.6.4
   riverpod_lint: ^2.3.13
   ```

3. Rodar `flutter pub get`.
4. Rodar `dart run build_runner build --delete-conflicting-outputs` (vai gerar nada ainda — só validar pipeline).

**Critérios de aceite:**
- `flutter pub get` sem conflitos de versão.
- `flutter analyze` ainda passa.
- `dart run build_runner build` roda sem erro.

---

## CARD-MOBILE-003 — Criar `lib/core/config/env.dart` (variáveis via `--dart-define`) 🟢

**Contexto.** Hoje não há leitura de variáveis de ambiente. O `CLAUDE.md` documenta `API_BASE_URL`, `SENTRY_DSN`, `ENVIRONMENT` via `--dart-define`, mas nada está conectado.

**Esforço:** rápido (1h).

**Dependências:** CARD-MOBILE-002.

**Arquivos criados:**
- `lib/core/config/env.dart`
- `test/core/config/env_test.dart`

**Passos:**

1. Criar `lib/core/config/env.dart`:

   ```dart
   class Env {
     static const apiBaseUrl = String.fromEnvironment(
       'API_BASE_URL',
       defaultValue: 'http://localhost:3000/api/v1',
     );

     static const sentryDsn = String.fromEnvironment('SENTRY_DSN');

     static const environment = String.fromEnvironment(
       'ENVIRONMENT',
       defaultValue: 'development',
     );

     static bool get isDevelopment => environment == 'development';
     static bool get isProduction => environment == 'production';
     static bool get hasSentry => sentryDsn.isNotEmpty;
   }
   ```

2. Adicionar teste verificando defaults.

**Critérios de aceite:**
- `Env.apiBaseUrl` retorna default quando `--dart-define` não passado.
- `Env.hasSentry` retorna `false` quando DSN vazio.
- Documentar no README ou comentário como rodar com cada `--dart-define`.

---

## CARD-MOBILE-004 — Criar `app.dart` + `ProviderScope` + tema 🟠

**Contexto.** Hoje `main.dart` instancia `MaterialApp` direto. Pra introduzir Riverpod e go_router precisamos separar em `app.dart` envolvido por `ProviderScope`.

**Esforço:** médio (3h).

**Dependências:** CARD-MOBILE-002.

**Arquivos criados/afetados:**
- `lib/main.dart` (refatorar)
- `lib/app.dart` (novo)
- `lib/core/theme/app_theme.dart` (novo)
- `lib/core/router/app_router.dart` (novo — placeholder com rota `/`)

**Passos:**

1. Criar `lib/core/theme/app_theme.dart` com `ThemeData` Material 3 — paleta, tipografia, cantos arredondados, tap targets ≥ 48dp.
2. Criar `lib/core/router/app_router.dart` com `GoRouter` mínimo (rota `/` → tela placeholder).
3. Criar `lib/app.dart`:

   ```dart
   class LogiFreeApp extends ConsumerWidget {
     const LogiFreeApp({super.key});

     @override
     Widget build(BuildContext context, WidgetRef ref) {
       final router = ref.watch(routerProvider);
       return MaterialApp.router(
         title: 'LogiFree',
         theme: AppTheme.light(),
         darkTheme: AppTheme.dark(),
         routerConfig: router,
         localizationsDelegates: ...,
         supportedLocales: const [Locale('pt', 'BR')],
       );
     }
   }
   ```

4. Refatorar `main.dart`:

   ```dart
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     runApp(const ProviderScope(child: LogiFreeApp()));
   }
   ```

5. Mover `ScanScreen` do POC pra rota `/scan-poc` provisoriamente até a tela definitiva ficar pronta.

**Critérios de aceite:**
- App roda com `flutter run` e mostra a placeholder.
- POC de scan continua acessível em `/scan-poc`.
- Sem `setState` novo em `app.dart`.

---

## CARD-MOBILE-005 — Configurar Dio + interceptors (auth placeholder, retry, logging) 🟠

**Contexto.** Toda chamada HTTP vai por Dio. Precisamos do cliente configurado, interceptor de logging em dev, retry com backoff e placeholder do interceptor de auth (token vem no CARD-007).

**Esforço:** médio (4h).

**Dependências:** CARD-MOBILE-003.

**Arquivos criados:**
- `lib/core/api/dio_client.dart`
- `lib/core/api/interceptors/logging_interceptor.dart`
- `lib/core/api/interceptors/retry_interceptor.dart`
- `lib/core/api/interceptors/error_interceptor.dart`
- `lib/core/api/api_error.dart` (mapeia formato do back)
- `test/core/api/dio_client_test.dart`

**Passos:**

1. Criar `AppError` data class com `code`, `userMessage` (pt-BR), `details`, `requestId` — conforme `LogiFree_Tratamento_Erros.md` do back.
2. `ErrorInterceptor` mapeia response do back (`{ error, message, code, details, requestId }`) para `AppError` com `userMessage` localizado.
3. `RetryInterceptor`: retenta 1x em 5xx e timeout (não em 4xx).
4. `LoggingInterceptor`: só ativo em `Env.isDevelopment`.
5. `DioClient.create()` retorna `Dio` com `baseUrl = Env.apiBaseUrl`, header `X-Condominium-Slug` injetado quando contexto de tenant existir (deixar hook pronto, valor vem depois).
6. Provider Riverpod: `@riverpod Dio dioClient(DioClientRef ref)`.

**Critérios de aceite:**
- Mock de resposta de erro do back vira `AppError` com `userMessage` em pt-BR.
- Retry só acontece em 5xx (testar).
- Em dev mode loga requests; em prod não.

---

## CARD-MOBILE-006 — Configurar `flutter_secure_storage` + `SecureStorage` wrapper 🟢

**Contexto.** Tokens (access, refresh, MFA) ficam no Keychain (iOS) / Keystore (Android). Precisamos de wrapper testável.

**Esforço:** rápido (2h).

**Dependências:** CARD-MOBILE-002.

**Arquivos criados:**
- `lib/core/storage/secure_storage.dart`
- `lib/core/storage/secure_storage_keys.dart`
- `test/core/storage/secure_storage_test.dart`

**Passos:**

1. Definir keys constantes: `accessToken`, `refreshToken`, `selectedCondominiumSlug`, `userId`.
2. Wrapper `SecureStorage` com métodos `read`, `write`, `delete`, `deleteAll` — interface mockável.
3. Provider Riverpod.
4. Configurar Android (`AndroidOptions(encryptedSharedPreferences: true)`) e iOS (`IOSOptions(accessibility: KeychainAccessibility.first_unlock)`).

**Critérios de aceite:**
- Teste com mock de `FlutterSecureStorage` valida read/write/delete.
- Após reinstalar app no iOS, token sobrevive (validar manualmente em device).

---

# BLOCO 2 — AUTH (autenticação)

Sem auth não dá pra testar nada autenticado. Tem que vir logo depois da infra.

---

## CARD-MOBILE-007 — `AuthService` + DTOs (sign-in, refresh, sign-out) 🔴

**Contexto.** Implementa as chamadas dos endpoints `POST /api/v1/auth/mobile/sign-in`, `POST /api/v1/auth/refresh`, `POST /api/v1/auth/sign-out`. JWT com access (15min) + refresh rotativo (30 dias).

**Esforço:** médio (4h).

**Dependências:** CARD-MOBILE-005, CARD-MOBILE-006.

**Arquivos criados:**
- `lib/features/auth/data/auth_repository.dart`
- `lib/features/auth/data/dto/sign_in_request.dart` (Freezed + JSON)
- `lib/features/auth/data/dto/sign_in_response.dart`
- `lib/features/auth/data/dto/refresh_response.dart`
- `lib/features/auth/data/dto/user_dto.dart` (id, email, name, memberships[])
- `lib/features/auth/application/auth_state.dart` (Freezed sealed: Unauthenticated, Authenticating, Authenticated, MfaRequired, Error)
- `lib/features/auth/application/auth_controller.dart` (`@riverpod class AuthController`)
- `test/features/auth/...`

**Passos:**

1. Definir DTOs com Freezed + json_serializable.
2. `AuthRepository.signIn(email, password)` → `SignInResponse | MfaRequired | AuthError`.
3. `AuthRepository.refresh(refreshToken)` → novo par de tokens.
4. `AuthRepository.signOut()` → POST + limpa secure storage.
5. `AuthController.signIn(email, password)`:
   - Atualiza estado pra `Authenticating`.
   - Chama repo, salva tokens no `SecureStorage`.
   - Decodifica JWT pra extrair `userId`, `memberships`.
   - Vai pra `Authenticated` ou `MfaRequired`.
6. **NÃO usar `useEffect` no front** — usar `ref.listen(authStateProvider)` em rotas/UI pra reagir a logout.

**Critérios de aceite:**
- Mock de back retornando 200 vira `Authenticated`.
- Mock retornando `code: MFA_REQUIRED` vira `MfaRequired`.
- Após `signOut()`, secure storage está vazio e estado é `Unauthenticated`.

---

## CARD-MOBILE-008 — Interceptor de auth no Dio (injeta token, refresh em 401) 🔴

**Contexto.** Depois do CARD-007 temos tokens; agora todo request precisa anexar `Authorization: Bearer <accessToken>` e, em 401, tentar refresh transparente antes de propagar erro.

**Esforço:** médio (4h). Cuidado: lógica de fila pra refresh concorrente.

**Dependências:** CARD-MOBILE-007.

**Arquivos criados/afetados:**
- `lib/core/api/interceptors/auth_interceptor.dart` (novo)
- `lib/core/api/dio_client.dart` (registrar interceptor)
- `test/core/api/auth_interceptor_test.dart`

**Passos:**

1. `AuthInterceptor` lê accessToken do `SecureStorage` e injeta no header.
2. Em 401:
   - Tenta refresh **uma vez** com `refreshToken`.
   - Se sucesso, salva novos tokens e retenta request original.
   - Se falha, dispara evento de logout (`authControllerProvider.notifier.forceLogout()`).
3. **Bloquear requests concorrentes durante refresh** — usar `Completer` ou `singleflight` para evitar N refreshes paralelos.
4. Header `X-Condominium-Slug` injetado a partir do tenant selecionado (CARD-MOBILE-010).

**Critérios de aceite:**
- Mock de 401 dispara refresh; novo request usa novo access token.
- Dois requests simultâneos com 401 disparam só 1 refresh.
- 401 em refresh → logout forçado.

---

## CARD-MOBILE-009 — Telas: Splash, Login, Forgot Password, Reset Password (deep link) 🟠

**Contexto.** Implementa telas 1.1, 1.2, 1.3, 1.4 de `LogiFree_Mobile_Telas.md`.

**Esforço:** grande (1 dia).

**Dependências:** CARD-MOBILE-007, CARD-MOBILE-008.

**Arquivos criados:**
- `lib/features/auth/presentation/splash_screen.dart`
- `lib/features/auth/presentation/login_screen.dart`
- `lib/features/auth/presentation/forgot_password_screen.dart`
- `lib/features/auth/presentation/reset_password_screen.dart`
- `lib/core/router/app_router.dart` (atualizar rotas)
- `test/features/auth/presentation/...`

**Passos:**

1. **Splash:** lê tokens, valida com `/me`, decide se vai pra `/login` ou pra `/select-condominium`.
2. **Login:** form com email + senha, toggle "mostrar senha", link "Esqueci senha", botão "Entrar" com loading inline (não spinner global).
3. **Forgot password:** input email, mensagem genérica ("se cadastrado, enviamos link") pra não vazar enumeração de usuários.
4. **Reset password:** abre via deep link `logifree://reset-password?token=...`. Form com nova senha + confirmação. Validação client-side: mínimo 10 chars.
5. Configurar deep link em `AndroidManifest.xml` e `Info.plist`.
6. Guard global no router: rotas autenticadas redirecionam pra `/login` se `authState != Authenticated`.

**Critérios de aceite:**
- Fluxo end-to-end de login funciona contra back mockado.
- Erro `INVALID_CREDENTIALS` mostra "Email ou senha inválidos" sem dar pista de qual.
- Deep link abre tela de reset com token preenchido.
- Não usa `setState` para estado de loading (usar Riverpod).

---

## CARD-MOBILE-010 — Seletor de condomínio + injeção de `X-Condominium-Slug` 🟠

**Contexto.** Tela 2.1. Usuário com múltiplas memberships precisa escolher; com 1 só pula direto.

**Esforço:** médio (4h).

**Dependências:** CARD-MOBILE-009.

**Arquivos criados:**
- `lib/features/auth/presentation/select_condominium_screen.dart`
- `lib/features/auth/application/tenant_controller.dart` (`@riverpod class TenantController`)
- `lib/features/auth/data/dto/membership_dto.dart`

**Passos:**

1. Após login bem-sucedido:
   - Se `memberships.length == 1` → seleciona e vai pra home.
   - Se `> 1` → vai pra `/select-condominium`.
2. Tela lista cards de condomínio (nome + cidade).
3. Tap salva slug em `SecureStorage` e atualiza `tenantControllerProvider`.
4. `AuthInterceptor` lê slug do controller e injeta como header em todo request.
5. Switcher acessível depois pelo perfil (botão "Trocar condomínio").

**Critérios de aceite:**
- Header `X-Condominium-Slug` presente em todos os requests autenticados.
- Trocar condomínio limpa caches relevantes (lista de pacotes etc.).
- Usuário com 1 membership não vê a tela.

---

# BLOCO 3 — SCAN (POC → produção)

POC já existe mas é `setState`. Precisa virar Riverpod, usar câmera ao vivo (não `image_picker`) e integrar com o endpoint de recebimento.

---

## CARD-MOBILE-011 — Migrar OCR pra `camera` + Riverpod (substituir POC) 🟠

**Contexto.** POC atual usa `image_picker` (galeria/foto avulsa). Pra UX de porteiro precisamos de `CameraPreview` fullscreen com captura **automática** ao detectar barcode (conforme tela 2.3).

**Esforço:** grande (1 dia).

**Dependências:** CARD-MOBILE-004, CARD-MOBILE-002 (camera + permission_handler).

**Arquivos criados/afetados:**
- `lib/features/scan/presentation/camera_screen.dart` (novo — substitui `scan_screen.dart`)
- `lib/features/scan/application/camera_controller.dart` (`@riverpod`)
- `lib/features/scan/application/ocr_controller.dart`
- `lib/features/scan/data/ocr_service.dart` (manter, ajustar)
- `lib/core/permissions/camera_permission.dart` (novo)
- `test/features/scan/...`

**Passos:**

1. Pedir permissão de câmera via `permission_handler`; se negada, mostrar empty state com botão "Abrir configurações".
2. `CameraPreview` fullscreen + overlay de mira.
3. Detecção contínua de barcode (stream do `google_mlkit_barcode_scanning`):
   - Ao detectar, vibração (`HapticFeedback.mediumImpact`) + captura frame + roda OCR de texto.
   - Manda pro `OcrController` que entrega `OcrResult` pra próxima tela.
4. Botão "Capturar manualmente" como fallback.
5. Botão "Cancelar" no canto superior.
6. **Sem `setState`** — usar `ref.watch(cameraControllerProvider)` e `Notifier`.

**Critérios de aceite:**
- Câmera abre em fullscreen.
- Barcode detectado dispara navegação pra tela de confirmação (CARD-MOBILE-012) sem clique manual.
- Permissão negada mostra empty state correto.
- POC antigo (`scan_screen.dart` com `image_picker`) **removido**.

---

## CARD-MOBILE-012 — Parser de etiqueta por transportadora 🟠

**Contexto.** OCR devolve texto bruto. Precisamos identificar transportadora (Correios, Mercado Livre, Amazon, etc.) por regex e extrair tracking + destinatário.

**Esforço:** médio (4h). Regex frágil — vai precisar de iteração.

**Dependências:** CARD-MOBILE-011.

**Arquivos criados:**
- `lib/features/scan/domain/carrier_parser.dart`
- `lib/features/scan/domain/carriers/correios_parser.dart`
- `lib/features/scan/domain/carriers/mercado_livre_parser.dart`
- `lib/features/scan/domain/carriers/amazon_parser.dart`
- `lib/features/scan/domain/parsed_label.dart` (Freezed)
- `test/features/scan/domain/...` (com fixtures de texto OCR real)

**Passos:**

1. `CarrierParser` interface: `bool matches(String rawText)` + `ParsedLabel parse(String rawText)`.
2. Implementar parsers por transportadora com regex.
3. `CarrierParser.dispatch(rawText)` tenta cada parser em ordem; retorna `ParsedLabel(carrier: 'unknown')` se ninguém bater.
4. Coletar 10-20 textos OCR reais como fixtures de teste (pedir pro time de operação).

**Critérios de aceite:**
- Testes com fixtures reais retornam carrier correto.
- Fixture de transportadora desconhecida retorna `unknown` sem erro.
- Cobertura de testes ≥ 80% pra `carrier_parser.dart`.

---

## CARD-MOBILE-013 — Tela de confirmar recebimento (tela 2.4) 🟠

**Contexto.** Após scan, mostra dados extraídos pra revisão antes de submeter.

**Esforço:** médio (4h).

**Dependências:** CARD-MOBILE-012.

**Arquivos criados:**
- `lib/features/scan/presentation/confirm_receipt_screen.dart`
- `lib/features/scan/application/receipt_form_controller.dart`

**Passos:**

1. Recebe `ParsedLabel` + foto via go_router state.
2. Form com campos editáveis: transportadora (dropdown com fallback "Outra"), código, destinatário, unidade (autocomplete), morador (filtrado por unidade), notas.
3. Foto da etiqueta como preview pequeno expansível (modal full-screen).
4. Botão "Confirmar" → chama `POST /api/v1/packages` com `Idempotency-Key` (UUID v7 gerado client-side).
5. Botão "Voltar/refazer" → volta pra câmera.

**Critérios de aceite:**
- Submit com sucesso volta pra home com toast "Pacote registrado".
- Submit em offline encaminha pra fila local (CARD-MOBILE-021).
- `Idempotency-Key` único por scan (não regenera ao retentar).

---

# BLOCO 4 — PACKAGES

Lista, detalhes, identificação manual.

---

## CARD-MOBILE-014 — `PackageRepository` + DTOs 🟠

**Esforço:** médio (3h).

**Dependências:** CARD-MOBILE-005, CARD-MOBILE-008.

**Arquivos criados:**
- `lib/features/packages/data/package_repository.dart`
- `lib/features/packages/data/dto/package_dto.dart`
- `lib/features/packages/data/dto/package_status.dart` (enum)
- `lib/features/packages/data/dto/create_package_request.dart`
- `test/features/packages/data/...`

**Passos:**

1. Definir `PackageStatus` enum (`pendingIdentification`, `awaitingPickup`, `delivered`, `returned`, `canceled`).
2. `PackageRepository`:
   - `Future<Package> create(CreatePackageRequest req, String idempotencyKey)`
   - `Future<PagedResult<Package>> list({status, page, search, dateFrom, dateTo})`
   - `Future<Package> getById(String id)`
   - `Future<Package> identify(String id, IdentifyRequest req)`
   - `Future<Package> deliver(String id, DeliverRequest req)`
   - `Future<Package> markReturned(String id, ReturnRequest req)`
   - `Future<void> cancel(String id)`

**Critérios de aceite:**
- DTOs serializam/desserializam JSON corretamente.
- Testes com mock de Dio validam endpoints e headers.

---

## CARD-MOBILE-015 — Home / Dashboard do dia (tela 2.2) 🟠

**Esforço:** médio (4h).

**Dependências:** CARD-MOBILE-014, CARD-MOBILE-010.

**Arquivos criados:**
- `lib/features/packages/presentation/home_screen.dart`
- `lib/features/packages/application/daily_summary_controller.dart`

**Passos:**

1. Botão grande "Escanear Pacote" (ação primária — tap target ≥ 48dp).
2. Cards com contadores: recebidos hoje, aguardando retirada, entregues hoje.
3. Lista compacta dos 5 últimos pacotes (mais recentes).
4. Badge se fila offline > 0 (CARD-MOBILE-021).
5. Acesso rápido pra `/packages` e `/profile`.
6. Pull-to-refresh.

**Critérios de aceite:**
- Tela carrega em <1s com cache local + invalidate em background.
- Tap em "Escanear" abre `/scan`.
- Badge offline visível só quando há operações pendentes.

---

## CARD-MOBILE-016 — Lista de pacotes (tela 2.6) 🟠

**Esforço:** grande (1 dia).

**Dependências:** CARD-MOBILE-014.

**Arquivos criados:**
- `lib/features/packages/presentation/packages_list_screen.dart`
- `lib/features/packages/application/packages_list_controller.dart` (com paginação)
- `lib/features/packages/presentation/widgets/package_card.dart`
- `lib/features/packages/presentation/widgets/packages_filter_sheet.dart`

**Passos:**

1. Lista paginada (infinite scroll).
2. Filtros: status (chips), data (date range picker), busca (textfield com debounce 300ms).
3. Item: unidade, nome, status (chip colorido), tempo aguardando (relative time pt-BR), ícone da transportadora.
4. Pull-to-refresh.
5. Empty state: "Nenhum pacote ainda. Toque em 'Escanear' para começar."
6. Skeleton loader em vez de spinner.

**Critérios de aceite:**
- Scroll suave com paginação ao chegar perto do fim.
- Filtros aplicam sem refetch desnecessário (debounce).
- Empty state correto quando lista vazia.

---

## CARD-MOBILE-017 — Detalhes do pacote + identificação manual (telas 2.5 e 2.7) 🟠

**Esforço:** grande (1 dia).

**Dependências:** CARD-MOBILE-016.

**Arquivos criados:**
- `lib/features/packages/presentation/package_details_screen.dart`
- `lib/features/packages/presentation/identify_recipient_screen.dart`
- `lib/features/packages/application/package_details_controller.dart`
- `lib/features/packages/application/identify_controller.dart`

**Passos:**

1. **Detalhes:** todos os campos do pacote + timeline de eventos + foto da etiqueta + botões de ação contextuais por status.
2. **Identificar destinatário:** autocomplete de unidade → autocomplete de morador (filtrado pela unidade) → confirmar. Opção "Não consigo identificar" mantém `pending_identification`.
3. Botões de ação aparecem só quando válidos para o status atual.

**Critérios de aceite:**
- Identificar pacote com `pending_identification` muda status pra `awaiting_pickup`.
- Timeline mostra eventos em ordem cronológica reversa.
- Botão "Cancelar" só aparece se pacote não foi entregue/devolvido.

---

# BLOCO 5 — DELIVERY (entrega + devolução)

---

## CARD-MOBILE-018 — Registrar entrega (tela 2.8) 🟠

**Esforço:** médio (3h).

**Dependências:** CARD-MOBILE-017.

**Arquivos criados:**
- `lib/features/delivery/presentation/deliver_package_screen.dart`
- `lib/features/delivery/application/deliver_controller.dart`

**Passos:**

1. Resumo do pacote no topo (foto, transportadora, destinatário).
2. Input "Quem retirou" (texto livre) OU botão "Validar token de retirada" (CARD-MOBILE-019).
3. Campo de observações (opcional).
4. Botão "Confirmar entrega" → `POST /api/v1/packages/:id/deliver`.

**Critérios de aceite:**
- Após submit, status muda pra `delivered`, volta pra detalhes.
- Funciona offline (encaminha pra fila — CARD-MOBILE-021).

---

## CARD-MOBILE-019 — Validar token de retirada (tela 2.9) 🟢

**Esforço:** rápido (2h).

**Dependências:** CARD-MOBILE-018.

**Arquivos criados:**
- `lib/features/delivery/presentation/validate_pickup_token_screen.dart`
- `lib/features/delivery/application/pickup_token_controller.dart`

**Passos:**

1. Input 6 chars (formato `XXX-XXX` opcional).
2. `GET /api/v1/pickup-tokens/:code` valida.
3. Se OK, mostra: nome autorizado, validade, pacote relacionado → navega pra "Registrar entrega" pré-preenchida.
4. Se inválido/expirado: erro localizado.

**Critérios de aceite:**
- Token inválido mostra "Token inválido ou expirado".
- Token válido pré-preenche tela de entrega com nome autorizado.

---

## CARD-MOBILE-020 — Registrar devolução (tela 2.10) 🟢

**Esforço:** rápido (2h).

**Dependências:** CARD-MOBILE-017.

**Arquivos criados:**
- `lib/features/delivery/presentation/return_package_screen.dart`

**Passos:**

1. Resumo do pacote.
2. Motivo (textfield opcional).
3. Botão "Confirmar devolução" → `POST /api/v1/packages/:id/return`.

**Critérios de aceite:**
- Status muda pra `returned`.
- Funciona offline.

---

# BLOCO 6 — OFFLINE (fila local)

Operações sem rede ficam em sqflite e sobem quando reconectar.

---

## CARD-MOBILE-021 — `OfflineQueue` em sqflite + interceptor de fallback 🔴

**Contexto.** Implementa a fila descrita em `LogiFree_Mobile_Offline.md`. Idempotência via UUID v7 client-side.

**Esforço:** grande (1.5 dias). Tem risco de race condition — testar bem.

**Dependências:** CARD-MOBILE-008, CARD-MOBILE-014.

**Arquivos criados:**
- `lib/core/storage/offline_queue.dart` (DAO sqflite)
- `lib/core/storage/migrations.dart`
- `lib/core/offline/sync_service.dart`
- `lib/core/offline/pending_operation.dart` (Freezed)
- `lib/core/api/interceptors/offline_fallback_interceptor.dart`
- `test/core/offline/...`

**Passos:**

1. Schema sqflite: `pending_operations(id PK uuid, method, url, headers JSON, body JSON, idempotency_key, created_at, attempts, status, last_error)`.
2. `OfflineQueue.enqueue(op)`, `dequeue()`, `markFailed(id, err)`, `markDone(id)`.
3. `OfflineFallbackInterceptor`: detecta `DioException` por timeout/conectividade → enfileira em vez de propagar erro.
4. `SyncService`: stream de `Connectivity.onConnectivityChanged`; quando volta online, drena a fila em ordem, com backoff exponencial em falhas.
5. UUID v7 (`uuid` package, função `v7()`) pra `Idempotency-Key`.
6. **Não** tentar mais de N vezes (configurável, default 5) — depois disso vai pra "falhou", usuário descarta na tela 3.1.

**Critérios de aceite:**
- Submit de pacote sem rede vai pra fila e mostra toast "Salvo offline, sincronizando quando reconectar".
- Reconectar dispara sincronização automática.
- `Idempotency-Key` impede duplicação se retentativa colidir com sucesso anterior (back é responsável; mobile só envia consistente).
- Testes com `Connectivity` mockado validam transições.

---

## CARD-MOBILE-022 — Tela de operações pendentes (tela 3.1) + banner de conectividade 🟢

**Esforço:** médio (3h).

**Dependências:** CARD-MOBILE-021.

**Arquivos criados:**
- `lib/features/offline/presentation/pending_operations_screen.dart`
- `lib/shared/widgets/connectivity_banner.dart`

**Passos:**

1. Lista de pendências com tipo, data, status (`enviando`, `falhou`).
2. Botão "Tentar novamente" por item.
3. Botão "Descartar" com confirmação.
4. Banner persistente no topo do app quando offline.
5. Toast temporário "Voltou online — sincronizando..." em reconexão.

**Critérios de aceite:**
- Banner aparece quando `connectivityResult == ConnectivityResult.none`.
- Lista atualiza ao vivo conforme operações são processadas.
- Descartar remove do sqflite (com confirmação).

---

# BLOCO 7 — OBSERVABILITY

---

## CARD-MOBILE-023 — Configurar Sentry Flutter 🟠

**Esforço:** médio (3h).

**Dependências:** CARD-MOBILE-004.

**Arquivos afetados:**
- `lib/main.dart`
- `lib/core/observability/sentry_setup.dart` (novo)

**Passos:**

1. Em `main.dart`, envolver `runApp` com `SentryFlutter.init(...)` quando `Env.hasSentry`.
2. Configurar `tracesSampleRate: 0.2` em prod, `1.0` em dev.
3. Tag `environment`, `release` (build version + commit hash via `--dart-define`).
4. Filtros de PII: scrub `Authorization`, `X-Condominium-Slug`, body de auth.
5. Capturar erros não tratados via `FlutterError.onError` e `PlatformDispatcher.instance.onError`.

**Critérios de aceite:**
- Erro forçado aparece no Sentry com tag de ambiente correto.
- Tokens não aparecem em breadcrumbs.

---

## CARD-MOBILE-024 — Configurar Shorebird (hot updates) 🟢

**Esforço:** rápido (2h, depois de criar conta).

**Dependências:** CARD-MOBILE-002.

**Passos:**

1. `shorebird init` no repo.
2. Configurar `shorebird.yaml`.
3. Adicionar checagem de patch em `main.dart` (`ShorebirdCodePush().updatePatch()`).
4. Documentar no README como publicar patch (`shorebird patch android --release-version=...`).

**Critérios de aceite:**
- `shorebird release` builda sem erro.
- Documentação do fluxo de patch existe.

---

# BLOCO 8 — POLISH (perfil, settings, MFA)

---

## CARD-MOBILE-025 — Perfil + logout (tela 3.2) 🟢

**Esforço:** rápido (2h).

**Dependências:** CARD-MOBILE-010.

**Arquivos criados:**
- `lib/features/auth/presentation/profile_screen.dart`

**Passos:**

1. Nome, email, role.
2. Lista de memberships com botão "Trocar condomínio" se > 1.
3. Link pra Settings.
4. Botão "Sair" com confirmação → `AuthController.signOut()`.

**Critérios de aceite:**
- Logout limpa secure storage e leva pra `/login`.

---

## CARD-MOBILE-026 — Settings (tela 3.3) 🟢

**Esforço:** rápido (2h).

**Arquivos criados:**
- `lib/features/settings/presentation/settings_screen.dart`
- `lib/features/settings/application/theme_controller.dart`

**Passos:**

1. Toggle de tema (claro/escuro/automático) persistido em `flutter_secure_storage`.
2. Versão do app + commit hash + ambiente (via `PackageInfo` + `--dart-define`).
3. Links pra política de privacidade e termos.
4. "Solicitar exclusão da conta" → abre email.

**Critérios de aceite:**
- Tema persiste entre sessões.
- Versão exibida bate com `pubspec.yaml`.

---

## CARD-MOBILE-027 — MFA (telas 1.5 e 3.4) 🟡

**Contexto.** MFA é opcional pro porteiro no MVP. Só precisa se o condomínio exigir.

**Esforço:** médio (4h).

**Dependências:** CARD-MOBILE-009.

**Arquivos criados:**
- `lib/features/auth/presentation/mfa_prompt_screen.dart`
- `lib/features/auth/presentation/setup_mfa_screen.dart`
- `lib/features/auth/data/mfa_repository.dart`

**Passos:**

1. **MFA prompt:** input 6 dígitos + botão validar + link "Usar código de recuperação".
2. **Setup MFA:** QR code (gerar via `qr_flutter` — adicionar dep) + input pra primeiro código + lista de 10 recovery codes copiáveis.
3. Endpoints: `POST /api/v1/auth/mfa/setup`, `POST /api/v1/auth/mfa/verify`.

**Critérios de aceite:**
- MFA prompt aparece só se back retorna `MFA_REQUIRED`.
- Setup gera QR + valida primeiro código corretamente.
- Recovery codes copiáveis individualmente e em lote.

---

# Apêndice — riscos e decisões pendentes

## Riscos técnicos

- **OCR em device real:** parsers de carrier são frágeis. Testar com 20+ etiquetas reais ANTES de fechar CARD-MOBILE-012.
- **Permissão de câmera em iOS:** precisa de `NSCameraUsageDescription` em `Info.plist`.
- **Refresh concorrente:** se `AuthInterceptor` não bloquear corretamente, pode disparar N refreshes — testar com `Future.wait`.
- **Idempotência offline:** se UUID v7 não for único por scan, duplica pacote. Gerar 1x no momento do scan e persistir junto com a operação.

## Decisões pendentes (perguntar ao negócio)

- Quais transportadoras priorizar para parser de etiqueta? (Correios, ML, Amazon, Shopee, outras?)
- MFA é obrigatório para algum condomínio no MVP ou pode ficar pra depois?
- Política de retenção de fila offline: descartar após quantos dias / tentativas?
- Tamanho máximo da foto da etiqueta (compressão)?

## Decisões já tomadas (não revisitar)

- Stack: Riverpod + go_router + Dio + Sentry + Shorebird + sqflite (`docs/LogiFree_Mobile_Stack.md`).
- Sem `setState` para estado compartilhado.
- Idempotência client-side via UUID v7.
- Multi-tenant via header `X-Condominium-Slug`.
- Plataforma primária: Android.

---

# Como atualizar este backlog

- **Card concluído:** mover para seção "Concluído" no topo (criar quando primeiro card fechar) com link pro commit/PR.
- **Card novo:** seguir o template (contexto, esforço, dependências, arquivos, passos, critérios).
- **Mudança de prioridade:** atualizar a tabela do resumo executivo.
- **Decisão pendente respondida:** mover do apêndice pra "decisões já tomadas".

O agente `mobile-backlog-manager` cruza este arquivo com `lib/` real para priorizar — então **mantenha sincronizado**.
