# ai.md — Guia para Agentes de IA (mobile)

Este documento orienta agentes (Claude, Copilot, Cursor, etc.) sobre quais documentos consultar ao trabalhar no `logifree-mobile`.

> **Antes de qualquer coisa:** abra também os docs do repo sibling `logifree-back-front` em `../logifree-back-front/.claude/ia/`. As decisões arquiteturais centrais vivem lá; este repo só especializa para mobile.

---

## Convenções globais (sempre aplicar)

- Código, identificadores, slugs, valores de enum, eventos: **inglês**.
- Documentação narrativa (esta pasta) e UI exibida ao usuário: **português**.
- Não misturar idiomas no código.
- Toda decisão arquitetural já tomada está numa ADR no `LogiFree_Stack_Tecnologico.md` do back-front.

---

## Documentos deste repo (`docs/`)

### `LogiFree_Mobile_Stack.md`
Stack específico do mobile: Flutter 3.24+, Riverpod, go_router, Dio, Google ML Kit, sqflite, Sentry, Shorebird. Justificativas e versões.

**Quando consultar:** sempre antes de adicionar uma dependência ou tomar decisão técnica.

### `LogiFree_Mobile_Estrutura.md`
Layout do projeto: `lib/core/`, `lib/features/`, `lib/shared/`. Convenções de naming.

**Quando consultar:** ao criar arquivos novos — decidir em qual diretório.

### `LogiFree_Mobile_Auth.md`
Fluxo de autenticação mobile: login JWT, refresh rotativo, secure storage, interceptor Dio. Especialização do `LogiFree_Fluxo_Autenticacao.md` do back-front.

**Quando consultar:** ao implementar qualquer parte de auth ou integração HTTP.

### `LogiFree_Mobile_OCR.md`
Integração com Google ML Kit (text + barcode). Fluxo de captura, parsing de etiqueta por transportadora, fallback manual.

**Quando consultar:** ao mexer com câmera, leitura de etiqueta ou identificação de transportadora.

### `LogiFree_Mobile_Offline.md`
Fila local com sqflite, detecção de conectividade, sincronização ao reconectar, conflito.

**Quando consultar:** ao implementar qualquer operação que precise funcionar offline.

### `LogiFree_Mobile_Boas_Praticas.md`
Práticas de Flutter/Dart: state management com Riverpod, navigation com go_router, testes, lints.

**Quando consultar:** sempre antes de PR.

---


### `LogiFree_Mobile_Testes.md`
Infra de teste em `test/test_helpers/`, padrão de escrita, mocktail, plugins nativos, anti-padrões.

**Quando consultar:** sempre antes de escrever um `*_test.dart`.


## Documentos no repo sibling (`../logifree-back-front/.claude/ia/`)

Use estes como **fonte da verdade** para tudo que é cross-platform:

| Doc | Por quê é relevante para o mobile |
|---|---|
| `LogiFree_Stack_Tecnologico.md` | Lista todas as 28 ADRs. Mobile segue todas que se aplicam. |
| `LogiFree_Modelo_Dados.md` | Schemas (entity types). Use para gerar/conferir DTOs do mobile. |
| `LogiFree_Permissoes.md` | IDs de permissão, roles built-in. `can()` no mobile usa o mesmo catálogo. |
| `LogiFree_Fluxo_Autenticacao.md` | Endpoints `/auth/mobile/*`, regras de refresh rotativo, MFA. |
| `LogiFree_Tratamento_Erros.md` | Formato canônico de erro `{ error, message, code, details, requestId }`. Mobile mapeia para mensagens em pt-BR. |
| `LogiFree_Eventos_Mensageria.md` | Eventos de domínio que o mobile pode receber via push (futuro). |
| `LogiFree_Multi_Condominio.md` | Header `X-Condominium-Slug`, troca de contexto, switcher. |
| `LogiFree_Convite_Morador.md` | Mobile não cria convites; só visualiza histórico (futuro). |
| `LogiFree_Boas_Praticas.md` | Princípios gerais. Aplicam-se também ao mobile. |

---

## Mapeamento Rápido por Tarefa

| Tarefa | Docs a consultar |
|---|---|
| Criar tela nova | `LogiFree_Mobile_Estrutura.md`, `LogiFree_Mobile_Boas_Praticas.md` |
| Adicionar endpoint HTTP | `LogiFree_Mobile_Auth.md`, `LogiFree_Tratamento_Erros.md` (back-front) |
| Implementar fluxo auth | `LogiFree_Mobile_Auth.md`, `LogiFree_Fluxo_Autenticacao.md` (back-front) |
| Implementar scan/câmera | `LogiFree_Mobile_OCR.md` |
| Operação offline | `LogiFree_Mobile_Offline.md` |
| Adicionar dependência | `LogiFree_Mobile_Stack.md` |
| Verificar permissão | `LogiFree_Permissoes.md` (back-front) |
| Tipos compartilhados | `LogiFree_Modelo_Dados.md` (back-front) |
| Escrever teste | `LogiFree_Mobile_Testes.md` |

---

## Quando não encontrar resposta

Se um tema não está coberto **aqui** nem no back-front, **pare e pergunte** antes de codar. Implementar sem alinhamento gera retrabalho.
