---
description: Roda o mobile-code-reviewer no diff atual antes de commit, conferindo lints e convenções do CLAUDE.md.
---

Delegue ao subagent `mobile-code-reviewer` para revisar o diff atual (`git status` + `git diff`) seguindo a checklist do `CLAUDE.md` e dos docs em `docs/LogiFree_Mobile_Boas_Praticas.md`. Quando ele retornar, mostre os achados ao usuário agrupados por severidade (must-fix / nice-to-have).

Cobertura esperada do reviewer:
- `flutter analyze` 0 issues
- `dart format --set-exit-if-changed lib/ test/`
- Sem `setState` para estado compartilhado
- Sem `dynamic` / sem `print()` / sem `.then()` quando `await` cabe
- Sem barrel files (`index.dart`)
- Widgets respeitam max ~200 linhas
- `BuildContext` async sempre com `mounted` check

Contexto adicional (opcional, ex: "foco em offline"): $ARGUMENTS
