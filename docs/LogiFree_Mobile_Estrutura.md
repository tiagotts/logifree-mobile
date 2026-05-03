# LogiFree Mobile — Estrutura do Projeto

```
lib/
├── main.dart                          # entry point + Sentry + Shorebird init + sqflite
├── app.dart                           # root widget + go_router config
├── core/
│   ├── api/                           # Dio + interceptors (auth, retry, error mapping)
│   ├── auth/                          # AuthService, JWT, refresh rotativo
│   ├── storage/
│   │   ├── secure_storage.dart        # tokens (Keychain/Keystore)
│   │   └── offline_queue.dart         # sqflite — operações pendentes
│   ├── config/
│   │   └── env.dart                   # vars via --dart-define
│   └── theme/
│       └── app_theme.dart             # ThemeData (light + dark, seed indigo)
├── features/
│   ├── auth/
│   │   ├── presentation/              # widgets/telas
│   │   ├── application/               # providers Riverpod
│   │   └── data/                      # repository + DTOs
│   ├── scan/
│   │   ├── presentation/              # CameraPreview + overlay
│   │   ├── application/               # OCR provider, parsing
│   │   └── data/
│   ├── packages/
│   │   ├── presentation/
│   │   ├── application/
│   │   └── data/
│   └── delivery/
│       ├── presentation/
│       ├── application/
│       └── data/
└── shared/
    └── widgets/                       # componentes reutilizáveis (LoadingOverlay, etc.)
```

## Convenções

### Naming
- **Arquivos:** `snake_case` (Dart convention).
- **Classes/types:** `PascalCase`.
- **Variáveis/funções:** `camelCase`.
- **Constantes top-level:** `camelCase` (não SNAKE_CASE — Dart convention).
- **Providers Riverpod:** sufixo `Provider` (ex.: `authStateProvider`).

### Camadas dentro de `features/<x>/`
- **`presentation/`** — widgets, telas, navegação.
- **`application/`** — providers, controllers, use-cases.
- **`data/`** — repositórios, fontes (HTTP, SQLite), DTOs.

Comunicação:
- `presentation` consome `application` (providers).
- `application` consome `data` (repositórios injetados via DI Riverpod).
- `data` é a única que toca em HTTP/SQLite/storage.

### Imports
Ordem:
1. `dart:` core
2. `package:flutter/`
3. `package:` third-party
4. relativos `../` ou `./`

Sem barrel files (`index.dart`) — gera ciclos.
