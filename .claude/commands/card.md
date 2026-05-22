---
description: Mostra detalhes de um CARD-MOBILE específico, status real no código, ou marca como concluído / adiciona / reordena cards no backlog.
---

Delegue ao subagent `mobile-backlog-manager` para trabalhar com o card abaixo. Ele tem permissão de editar `docs/LogiFree_Mobile_Backlog.md` quando solicitado (marcar concluído, adicionar, reordenar), mas SEMPRE confirma antes.

Ação possível:
- "CARD-MOBILE-XXX" → mostra detalhes + status real cruzando com `lib/`
- "concluído CARD-MOBILE-XXX" → confere se os arquivos/testes existem e move pra seção Concluído
- "novo: <descrição>" → cria card novo seguindo o template
- "reprioriza CARD-MOBILE-XXX para 🔴/🟠/🟡/🟢" → atualiza prioridade

Argumento: $ARGUMENTS
