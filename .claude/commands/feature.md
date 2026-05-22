---
description: Orquestra a equipe mobile pra implementar um CARD-MOBILE ponta-a-ponta (backlog-manager refina → flutter implementa → tester escreve testes → reviewer revisa).
---

Você é o **orquestrador** da implementação deste card: `$ARGUMENTS`

Execute o fluxo abaixo em ordem, **delegando** cada etapa via Task tool ao subagent indicado. Espere o retorno de cada um antes de seguir, e mostre ao usuário um resumo entre etapas.

1. **Refinar o card** → `mobile-backlog-manager`
   - Peça que abra o card em `docs/LogiFree_Mobile_Backlog.md`, valide dependências (todas atendidas?), liste arquivos exatos a criar/alterar e critérios de aceite.
   - Se houver bloqueio (dependência não pronta, decisão pendente, endpoint do back faltando), PARE e avise o usuário.
   - Mostre o plano refinado ao usuário e peça aprovação antes de continuar.

2. **Implementar** → `mobile-flutter`
   - Passe o plano refinado + lista de arquivos a criar/alterar + critérios de aceite.
   - Cobre: estrutura de camadas (presentation/application/data), Riverpod ao invés de setState, sem useEffect, sem dynamic.

3. **Testar** → `mobile-tester`
   - Passe os critérios de aceite do card como contratos de teste.
   - Cobertura mínima: caminho feliz, erro de validação, comportamento offline (se aplicável), permissões.
   - Roda `flutter test` ao final.

4. **Revisar** → `mobile-code-reviewer`
   - Revisa todo o diff acumulado, roda `flutter analyze` e `dart format --set-exit-if-changed lib/ test/`.
   - Se houver "must-fix", volte para `mobile-flutter` ou `mobile-tester` pra corrigir, e revise de novo. Só siga quando review estiver limpo.

5. **Atualizar backlog** → `mobile-backlog-manager`
   - Peça que mova o card para a seção "Concluído" e atualize a tabela do Resumo executivo.

6. **Resumo final** ao usuário:
   - Arquivos alterados (agrupados por camada).
   - Comando para rodar local: `flutter run --dart-define=...`.
   - Sugestão de mensagem de commit Conventional Commits.

**Regras de orquestração:**
- Nunca pule etapas.
- Se algum agent retornar "preciso de decisão", PARE e pergunte ao usuário humano.
- Não escreva código você mesmo — você só coordena.
