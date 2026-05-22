# LogiFree Mobile — Testes

Guia para escrever testes do app Flutter. Espelha a filosofia do `LogiFree_Backend_Testes.md` (back-front).

---

## TL;DR

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:logifree_mobile/features/scan/data/ocr_result.dart';

import '../../../test_helpers/test_helpers.dart';

void main() {
  group('OcrResult', () {
    test('hasError é true quando error não é null', () {
      const result = OcrResult(error: 'falha');
      expect(result.hasError, isTrue);
    });
  });
}
```

```bash
flutter test                                          # tudo
flutter test test/features/scan                        # subpasta
flutter test --coverage                                # com cobertura
```

---

## Stack

- **Runner:** `flutter test` (default, baseado em `package:test`).
- **Mocks:** `mocktail` (sem codegen, sintaxe simples; preferido a `mockito` no projeto).
- **HTTP fake (quando entrar Dio):** `MockAdapter` ou stub manual via `mocktail`.
- **Sem Riverpod ainda** — quando entrar, padrão será `ProviderContainer` com `overrideWith`.

---

## Setup local

Nada além de `flutter pub get`. Sem env extra, sem DB.

Quando o app passar a fazer HTTP real e ter backend rodando para testes de integração, criamos um `.env.test`. Por enquanto tudo é mockado.

---

## Infraestrutura — `test/test_helpers/`

| Arquivo | Função |
|---|---|
| `test_helpers.dart` | Barrel — `export` de todos os outros. Importe daqui. |
| `test_constants.dart` | IDs UUID v7 fixos (`testCondominiumId`, `testUserId`, `testResidentId`). Alinhados com back-front. |
| `test_data.dart` | Fixtures: `SampleTrackingCodes`, `SampleLabelTexts`, emails/phones de exemplo. |
| `test_setup.dart` | `ensureTestBinding()` e `stubMethodChannel()` para mockar plugins nativos. |
| `widget_pumper.dart` | `pumpAppWidget()` envolve widget em `MaterialApp` + ajusta surface size. |

**Padrão de import em qualquer `*_test.dart`:**

```dart
import '../../../test_helpers/test_helpers.dart';
```

---

## Padrões

### 1. Co-localização (estrutura espelhada)

Tests espelham `lib/`:

```
lib/features/scan/data/ocr_result.dart
test/features/scan/data/ocr_result_test.dart
```

Mesmo path relativo, sufixo `_test.dart`. `flutter test` descobre automaticamente.

### 2. Naming

- Arquivo: `<source>_test.dart`.
- `group(NomeDaClasse | 'feature')`
- `test('<comportamento> quando <condição>')`

```dart
group('OcrResult', () {
  test('hasText é true quando text é não-vazio', () { ... });
  test('hasData é false quando vazio', () { ... });
});
```

### 3. Tipos de teste

**Unit puro (sem widgets, sem plugins):**
```dart
test('descrição', () { ... });
```
Modelos, validadores, transformações, parsers.

**Widget test (renderiza UI):**
```dart
testWidgets('descrição', (tester) async {
  await pumpAppWidget(tester, const ScanScreen());
  await tester.tap(find.text('Escanear'));
  await tester.pumpAndSettle();
  expect(find.text('Resultado'), findsOneWidget);
});
```

**Integration test (em `integration_test/` — não em `test/`):**
Para testes E2E em device real. Não usar pra unit/widget.

### 4. Mocks com mocktail

```dart
import 'package:mocktail/mocktail.dart';

class MockOcrService extends Mock implements OcrService {}

test('controller mostra erro quando OCR falha', () async {
  final mockOcr = MockOcrService();
  when(() => mockOcr.processImage(any())).thenAnswer(
    (_) async => const OcrResult(error: 'simulado'),
  );

  final result = await mockOcr.processImage('/path');
  expect(result.hasError, isTrue);
  verify(() => mockOcr.processImage('/path')).called(1);
});
```

**Registrar fallback values** para tipos não-primitivos (mocktail exige):
```dart
setUpAll(() {
  registerFallbackValue(const OcrResult());
});
```

### 5. Plugins nativos (camera, ml_kit, secure_storage)

Não funcionam em test ambiente sem device. Duas alternativas:

**a) Mock o serviço wrapper** (preferido):
```dart
class MockOcrService extends Mock implements OcrService {}
```

**b) Stub do method channel** (quando o wrapper não pode ser facilmente injetado):
```dart
import '../test_helpers/test_helpers.dart';

setUp(() {
  stubMethodChannel('plugins.flutter.io/path_provider', (call) async {
    if (call.method == 'getApplicationDocumentsDirectory') return '/tmp/test';
    return null;
  });
});
```

### 6. Widget pumper

Use `pumpAppWidget()` em vez de `tester.pumpWidget(MaterialApp(...))` toda hora:

```dart
await pumpAppWidget(tester, const MyScreen());
```

Garante surface size consistente e tema padrão.

### 7. Cobertura

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html  # opcional: gerar HTML
```

Alvo: **70% backend-side da camada `data/` e `application/`**, smoke nos widgets críticos.
Sem perseguir 95% — teste o que importa.

### 8. Cleanup

Cada teste deve ser **independente**.
- `setUp` para preparar estado antes de cada teste.
- `tearDown` para limpar (raro em Flutter sem DB).
- `setUpAll` / `tearDownAll` para setup global (registerFallbackValue, etc.).

---

## Anti-padrões

- ❌ Importar `lib/` direto (`import 'lib/...'`) em vez de `package:logifree_mobile/...`.
- ❌ `pumpWidget` sem `MaterialApp` (faltam i18n, theme, navigator).
- ❌ `await tester.pump()` quando precisa `pumpAndSettle()` (e vice-versa — pumpAndSettle trava em animação infinita).
- ❌ Mockar `OcrService` mas chamar plugin real em outro lugar — o teste vai falhar com "MissingPluginException".
- ❌ Tests dependentes da ordem de execução.
- ❌ Tests com `Future.delayed(Duration(seconds: X))` literal — use `tester.pump(duration)` ou `fakeAsync`.
- ❌ Sem `dispose()` em providers/services que segurar recursos.
- ❌ Snapshot test em UI que muda com frequência (data/hora atual, IDs gerados).
- ❌ Hardcoded English em assertions de UI — UI é pt-BR.

---

## Quando o projeto crescer

Estes itens entram no helper conforme aparecer necessidade:

- **`test_container.dart`** — `ProviderContainer` com `overrideWith` quando Riverpod entrar.
- **`test_api.dart`** — mock Dio (interceptor ou MockAdapter) quando entrar HTTP real.
- **`test_secure_storage.dart`** — mock `flutter_secure_storage` quando auth entrar.
- **`fakes/`** — fakes de longa duração para entidades de domínio (`FakePackagesRepository`, etc.).
- **`golden/`** — golden tests para telas críticas (quando UI estabilizar).

---

## CI (a configurar)

```yaml
- uses: subosito/flutter-action@v2
  with:
    channel: stable
- run: flutter pub get
- run: flutter analyze
- run: flutter test --coverage
- uses: codecov/codecov-action@v4   # opcional
  with:
    file: coverage/lcov.info
```

Pre-commit local sugerido (a configurar):
```bash
dart format --set-exit-if-changed lib/ test/
dart analyze
flutter test
```

---

## Docs relacionadas

- `LogiFree_Mobile_Estrutura.md` — onde cada teste vive espelhando `lib/`.
- `LogiFree_Mobile_Boas_Praticas.md` — convenções gerais (que se aplicam a tests também).
- `../logifree-back-front/.claude/ia/LogiFree_Backend_Testes.md` — filosofia equivalente no back.
