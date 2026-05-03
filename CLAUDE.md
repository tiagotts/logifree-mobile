# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Projeto

Aplicação mobile Flutter para o sistema **LogiFree** - Sistema de gestão de encomendas para condomínios. App focado para uso de porteiros, com capacidades offline e OCR para leitura de etiquetas.

**IMPORTANTE**: Documentação arquitetural completa em `docs/`. Este repo é parte de um monorepo maior (`logifree-back-front`). Decisões cross-platform estão documentadas em `../logifree-back-front/.claude/ia/`.

## Stack Tecnológico

| Componente | Tecnologia | Versão | Motivo |
| ---------- | ---------- | ------ | ------ |
| Framework | Flutter | 3.24+ | Performance câmera + OCR + bundle pequeno |
| Linguagem | Dart | 3.5+ | - |
| State Management | Riverpod | 2.x | Padrão moderno com codegen |
| Routing | go_router | 14.x | Padrão oficial Flutter |
| HTTP Client | Dio | 5.x | Interceptors (auth, retry, log) |
| OCR | Google ML Kit | - | On-device, gratuito, multi-formato |
| Câmera | camera | 0.11.x | Plugin oficial |
| Storage Seguro | flutter_secure_storage | 9.x | Keychain/Keystore para tokens |
| DB Local | sqflite | 2.x | Fila offline |
| Conectividade | connectivity_plus | 6.x | Detectar online/offline |
| Observabilidade | Sentry Flutter | 8.x | Mesma plataforma do back/front |
| Hot Updates | Shorebird | 2.x | Patches sem App Store/Play |
| Codegen | freezed, json_serializable, riverpod_generator | - | Data classes, JSON, providers |

Veja `docs/LogiFree_Mobile_Stack.md` para detalhes completos.

## Estrutura do Projeto

```text
lib/
├── main.dart                 # Entry point + Sentry + Shorebird + sqflite init
├── app.dart                  # Root widget + go_router config
├── core/
│   ├── api/                  # Dio + interceptors (auth, retry, error mapping)
│   ├── auth/                 # AuthService, JWT, refresh rotativo
│   ├── storage/
│   │   ├── secure_storage.dart    # Tokens (Keychain/Keystore)
│   │   └── offline_queue.dart     # sqflite - operações pendentes
│   ├── config/
│   │   └── env.dart          # Vars via --dart-define
│   └── theme/
│       └── app_theme.dart    # ThemeData (Material 3)
├── features/
│   ├── auth/                 # Autenticação
│   │   ├── presentation/     # Widgets/telas
│   │   ├── application/      # Providers Riverpod
│   │   └── data/             # Repository + DTOs
│   ├── scan/                 # OCR e captura de etiquetas
│   ├── packages/             # Gestão de pacotes
│   └── delivery/             # Entregas
└── shared/
    └── widgets/              # Componentes reutilizáveis
```

Veja `docs/LogiFree_Mobile_Estrutura.md` para detalhes completos.

## Comandos Comuns

### Desenvolvimento

```bash
# Instalar dependências
flutter pub get

# Executar com variáveis de ambiente
flutter run \
  --dart-define=API_BASE_URL=https://api.logifree.com.br/api/v1 \
  --dart-define=SENTRY_DSN=https://... \
  --dart-define=ENVIRONMENT=development

# Executar em dispositivo específico
flutter devices
flutter run -d <device-id>

# Hot reload: 'r' | Hot restart: 'R'
```

### Code Generation

```bash
# Gerar código (Freezed, JSON, Riverpod)
dart run build_runner build

# Gerar em modo watch (desenvolvimento)
dart run build_runner watch

# Limpar e regenerar
dart run build_runner build --delete-conflicting-outputs
```

### Testes

```bash
# Todos os testes
flutter test

# Teste específico
flutter test test/features/auth/auth_service_test.dart

# Com coverage
flutter test --coverage
```

### Análise e Formatação

```bash
# Analisar código (SEMPRE antes de commit)
flutter analyze

# Formatar código
dart format lib/ test/

# Lints customizados em analysis_options.yaml:
# - strict-casts, strict-inference, strict-raw-types
# - prefer_single_quotes, require_trailing_commas
# - avoid_print (use dart:developer log ou Sentry)
```

### Build

```bash
# Android APK
flutter build apk

# Android App Bundle (Play Store)
flutter build appbundle

# iOS (requer macOS)
flutter build ios

# Web
flutter build web
```

## Convenções de Código

### Naming

- **Arquivos**: `snake_case`
- **Classes/Types**: `PascalCase`
- **Variáveis/Funções**: `camelCase`
- **Constantes**: `camelCase` (não SNAKE_CASE - convenção Dart)
- **Providers Riverpod**: sufixo `Provider` (ex: `authStateProvider`)

### Imports (ordem)

1. `dart:` core
2. `package:flutter/`
3. `package:` third-party
4. Relativos `../` ou `./`

**NUNCA** use barrel files (`index.dart`) - gera ciclos de dependência.

### Camadas (dentro de `features/<x>/`)

- **`presentation/`**: Widgets, telas, navegação
- **`application/`**: Providers, controllers, use-cases (Riverpod)
- **`data/`**: Repositórios, DTOs, fontes HTTP/SQLite

**Comunicação**: presentation → application → data

### Idiomas

- **Código, slugs, enums, eventos**: INGLÊS
- **UI exibida ao usuário**: PORTUGUÊS (pt-BR)
- **Documentação narrativa**: PORTUGUÊS

## State Management (Riverpod)

- **SEMPRE Riverpod**, nunca `setState` para estado compartilhado
- Use `riverpod_generator` (`@riverpod`) para providers type-safe
- `Notifier` para estado mutável
- `FutureProvider`/`StreamProvider` para async
- `ref.watch` em build (reativo)
- `ref.read` em handlers (one-shot)
- `ref.listen` para side effects (navegação, snackbar)

```dart
@riverpod
class PackagesController extends _$PackagesController {
  @override
  Future<List<Package>> build() async {
    return ref.read(packagesRepositoryProvider).list();
  }
}
```

## Autenticação

- JWT com refresh token rotativo (30 dias)
- Access token: 15 minutos
- Storage: `flutter_secure_storage` (Keychain/Keystore)
- Interceptor Dio: auto-refresh em 401 + retry
- Header obrigatório: `X-Condominium-Slug` (multi-tenant)

Veja `docs/LogiFree_Mobile_Auth.md` para fluxo completo.

## Funcionalidades Principais

### OCR e Captura de Etiquetas

- Google ML Kit (text + barcode scanning)
- On-device, sem API externa
- Identificação automática de transportadora por regex
- Fallback manual se OCR falhar

Veja `docs/LogiFree_Mobile_OCR.md`.

### Modo Offline

- Operações em fila local (sqflite) quando offline
- Sincronização automática ao reconectar
- Idempotência via UUID v7 client-side
- UI mostra badge de "operações pendentes"

Veja `docs/LogiFree_Mobile_Offline.md`.

## Tratamento de Erros

Backend retorna formato padronizado:

```json
{
  "error": "ValidationError",
  "message": "Dados inválidos",
  "code": "INVALID_CREDENTIALS",
  "details": {},
  "requestId": "uuid"
}
```

Cliente mapeia `code` para mensagens pt-BR:

```dart
class AppError implements Exception {
  final String code;
  final String userMessage;  // pt-BR pronto para UI
  final Map<String, dynamic>? details;
  final String? requestId;
}
```

## Anti-padrões (NUNCA FAZER)

- ❌ `setState` para estado compartilhado (use Riverpod)
- ❌ `dynamic` (use `Object?` + narrowing)
- ❌ `.then()` quando `await` cabe
- ❌ `print()` (use `dart:developer` log ou Sentry)
- ❌ Singleton mutável global (use Riverpod)
- ❌ `BuildContext` async sem `mounted` check
- ❌ Mutar lista/map retornado
- ❌ Widget gigante sem decomposição (max ~200 linhas)
- ❌ Lógica de negócio em widget (vai para controller)
- ❌ Provider 6.x clássico (use Riverpod)

## Documentação Completa

Consulte sempre antes de implementar:

- **`docs/ai.md`**: Guia para agentes de IA sobre qual doc consultar
- **`docs/LogiFree_Mobile_Stack.md`**: Stack completo e justificativas
- **`docs/LogiFree_Mobile_Estrutura.md`**: Estrutura de pastas e convenções
- **`docs/LogiFree_Mobile_Auth.md`**: Autenticação e tokens
- **`docs/LogiFree_Mobile_OCR.md`**: OCR e captura de etiquetas
- **`docs/LogiFree_Mobile_Offline.md`**: Estratégia offline
- **`docs/LogiFree_Mobile_Boas_Praticas.md`**: Práticas Flutter/Dart

**Repo sibling**: `../logifree-back-front/.claude/ia/` contém docs cross-platform (modelo de dados, permissões, tratamento de erros, etc.)

## Plataformas Foco

Embora configurado para todas as plataformas Flutter, o foco é:

- **Android** (primário - porteiros usam tablets Android)
- **iOS** (secundário)
