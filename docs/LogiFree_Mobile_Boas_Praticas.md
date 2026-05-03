# LogiFree Mobile — Boas Práticas (Flutter/Dart)

Complementa as boas práticas gerais do back-front (`LogiFree_Boas_Praticas.md`). Foco aqui é Flutter idioms.

---

## State Management (Riverpod)

- **Sempre Riverpod**, nunca `setState` para estado compartilhado.
- Use `riverpod_generator` (`@riverpod`) para providers — gera tipo seguro e auto dispose.
- `Notifier` para estado mutável; `FutureProvider`/`StreamProvider` para async.
- `ref.watch` em build (reativo); `ref.read` em handlers (one-shot).
- `ref.listen` para side effects (ex.: navegação, snackbar).

```dart
@riverpod
class PackagesController extends _$PackagesController {
  @override
  Future<List<Package>> build() async {
    return ref.read(packagesRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(packagesRepositoryProvider).list());
  }
}
```

---

## Imutabilidade

- **Freezed** para data classes. Sem mutação direta.
- `copyWith()` para criar variações.

```dart
@freezed
class Package with _$Package {
  const factory Package({
    required String id,
    required PackageStatus status,
    String? trackingCode,
  }) = _Package;

  factory Package.fromJson(Map<String, dynamic> json) => _$PackageFromJson(json);
}
```

---

## Navegação (go_router)

- Configuração centralizada em `app.dart`.
- Use `context.go('/path')` para navegação imperativa.
- `redirect` no router para guards de auth.
- Deep links via `logifree://` configurado no AndroidManifest e Info.plist.

---

## HTTP (Dio)

- Cliente único centralizado (`core/api/api_client.dart`).
- Interceptors: auth (JWT), error mapping (`AppError`), logging em dev.
- DTOs com Freezed + JSON serializable.
- Repositórios em `features/<x>/data/` consomem o cliente.

---

## Erros

- Cliente HTTP mapeia resposta `{ error, message, code, details, requestId }` para `AppError`:

```dart
class AppError implements Exception {
  AppError({required this.code, required this.userMessage, this.details, this.requestId});
  final String code;
  final String userMessage;     // pt-BR pronto para UI
  final Map<String, dynamic>? details;
  final String? requestId;
}
```

- Catch no controller; mostra `userMessage` em SnackBar/Dialog.
- Sentry capture nos `catch` que vão exibir.

---

## Async

- **Sempre `async/await`.** Sem `.then()`.
- `Future<void>` ignorado vira lint error (`unawaited_futures`).
- Use `unawaited(future)` quando intencional.

---

## UI

- Material 3.
- Theme via CSS-like seed color (alinha com painel web).
- Sem widgets gigantes (>200 linhas) — extraia em sub-widgets.
- `const` em widgets sempre que possível (perf).
- `SafeArea` no root de telas.

---

## Acessibilidade

- `Semantics` nos elementos interativos.
- Tamanho mínimo de tap target: 48dp.
- Contraste WCAG AA.

---

## Testes

- `flutter test` — runner padrão.
- Widget tests para telas principais.
- Unit tests para providers/use-cases (mocktail para mocks).
- Tests co-locados em `test/` espelhando estrutura de `lib/`.
- Sem snapshot tests no MVP.

---

## Lints (analysis_options.yaml)

- `flutter_lints` base.
- `strict-casts`, `strict-inference`, `strict-raw-types`.
- `prefer_single_quotes`, `require_trailing_commas`.
- `avoid_print` — use `dart:developer` `log()` ou Sentry.

---

## Anti-padrões

- ❌ `setState` para estado compartilhado entre widgets.
- ❌ `dynamic` (use `Object?` + narrowing).
- ❌ `.then()` quando `await` cabe.
- ❌ `print()` (use logger ou Sentry).
- ❌ Singleton mutável global (use Riverpod).
- ❌ `BuildContext` async sem `mounted` check.
- ❌ Mutar lista/map retornado de função (use imutável).
- ❌ Widget gigante sem decomposição.
- ❌ Lógica de negócio em widget (vai para controller/use-case).
- ❌ `Provider` 6.x clássico (use Riverpod).

---

## Pre-commit (a configurar)

- `dart format .`
- `dart analyze`
- `flutter test` (smoke)
