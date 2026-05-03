# LogiFree Mobile — Stack Tecnológico

**Status:** Vivo (atualizado conforme ADRs novas). Decisões cross-platform vivem em `../logifree-back-front/.claude/ia/LogiFree_Stack_Tecnologico.md`.

---

## Resumo

| Camada | Escolha | Motivo |
|---|---|---|
| Framework | **Flutter 3.24+** / Dart 3.5+ | ADR-002. Performance câmera + OCR + bundle pequeno. |
| State | **Riverpod 2.x** + codegen | Padrão moderno; alinha com signals do front Angular. |
| Routing | **go_router 14.x** | Padrão da equipe Flutter Google. |
| HTTP | **Dio 5.x** | Interceptors fáceis (auth, retry, log). |
| OCR | **Google ML Kit** (`text_recognition` + `barcode_scanning`) | On-device, gratuito, multi-formato. |
| Câmera | **camera 0.11.x** | Plugin oficial Flutter. |
| Storage seguro | **flutter_secure_storage 9.x** | Keychain (iOS) / Keystore (Android). |
| Storage local | **sqflite 2.x** + `path_provider` | Fila offline. |
| Conectividade | **connectivity_plus 6.x** | Detectar online/offline. |
| Observabilidade | **Sentry Flutter 8.x** | Mesma plataforma do back/front. |
| Hot updates | **Shorebird 2.x** | Patches sem App Store/Play approval. |
| i18n | **intl** | pt-BR-only no MVP. |
| Codegen | **freezed**, **json_serializable**, **riverpod_generator** | Data classes imutáveis, JSON, providers tipados. |
| Testes | `flutter_test`, **mocktail** | Padrão Flutter. |

---

## Princípios

1. **On-device first.** OCR, decisões de UI, fila offline — tudo local. Backend só quando precisa.
2. **Imutabilidade.** Use Freezed para data classes. `copyWith` em vez de mutação.
3. **Single source of truth.** Estado em providers Riverpod. Nada em estado de widget exceto UI puramente local.
4. **Tipos sempre.** Sem `dynamic`. Use `Object?` + narrowing se realmente não souber.
5. **Códigos de erro do back-front** (`packages/shared/error-codes`) mapeiam para mensagens pt-BR locais.

---

## Versões pinadas

Ver `pubspec.yaml`. Dois cuidados:
- **ML Kit**: pacotes do Google atualizam frequentemente; quando `flutter pub get` falhar com "no version match", aceite a sugestão.
- **Camera**: APIs entre 0.10/0.11 mudaram bastante; manter pinado.

## Não usar (decisão consciente)

- **Provider 6.x** clássico — Riverpod cobre.
- **Bloc** — overhead desnecessário para o porte atual.
- **GetIt** — Riverpod já faz DI.
- **MobX** — verbose, codegen mais pesado.
- **Hive** — sqflite é suficiente; Hive não tem queries SQL e atrapalha sync.

---

## Configurações por ambiente

Injetadas via `--dart-define`:

```bash
flutter run \
  --dart-define=API_BASE_URL=https://api.logifree.com.br/api/v1 \
  --dart-define=SENTRY_DSN=https://... \
  --dart-define=ENVIRONMENT=production
```

Acesso pelo código via `lib/core/config/env.dart`.
