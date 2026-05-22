# LogiFree Mobile — Telas Necessárias

App do porteiro (Flutter). Lista completa das telas que precisam existir, agrupadas por contexto e prioridade.

> Persona única no MVP: **porteiro**. Não há telas para morador (notifica via email) nem para síndico (web).

---

## 1. Telas públicas (sem autenticação)

### 1.1 Splash / Loading
Mostrada ao abrir o app enquanto:
- Verifica tokens em `flutter_secure_storage`.
- Decide rota inicial (login ou home).

Logo + spinner. Sem interação.

### 1.2 Login
- Inputs: email, senha.
- Botão "Entrar".
- Link "Esqueci minha senha".
- Toggle "mostrar senha".
- Erros: credenciais inválidas, conta bloqueada, MFA exigida.

Endpoint: `POST /api/v1/auth/mobile/sign-in`.

### 1.3 Esqueci minha senha
- Input: email.
- Botão "Enviar link".
- Confirmação: "Se o email estiver cadastrado, enviamos um link."
- Volta para login.

Endpoint: `POST /api/v1/auth/forgot-password`.

### 1.4 Redefinir senha (deep link)
Abre via `logifree://reset-password?token=...`.
- Inputs: nova senha, confirmação.
- Validação: mínimo 10 chars, igual à confirmação.
- Botão "Redefinir".
- Após sucesso, redireciona para login.

Endpoint: `POST /api/v1/auth/reset-password`.

### 1.5 MFA (TOTP)
Mostrada após login bem-sucedido se backend retornar `code: MFA_REQUIRED`.
- Input: código de 6 dígitos.
- Botão "Verificar".
- Link "Usar código de recuperação".

Para porteiro, MFA é opcional no MVP — esta tela só aparece se o admin do condomínio exigir.

---

## 2. Telas autenticadas — fluxo principal

### 2.1 Seletor de condomínio
Mostrada após login se o usuário tem **membership em mais de um condomínio**.
- Lista os condomínios com nome e cidade.
- Toca no item → seleciona contexto e vai para home.
- Switcher acessível depois pelo menu (perfil).

Se só tem 1 condomínio: pula direto pra home.

### 2.2 Home / Dashboard do dia
Tela principal pós-login. Resumo operacional:
- Botão grande **"Escanear Pacote"** (ação primária).
- Cards: pacotes recebidos hoje, aguardando retirada, entregues hoje.
- Lista compacta dos últimos 5 pacotes registrados.
- Badge se houver operações pendentes na fila offline.
- Acesso rápido para "Lista de Pacotes" e "Perfil".

### 2.3 Câmera + OCR (escanear etiqueta)
Tela de captura.
- `CameraPreview` em tela cheia.
- Overlay com mira (área esperada da etiqueta).
- Captura **automática** ao detectar código de barras OU manual via botão.
- Indicador de processamento ("Lendo etiqueta...").
- Vibração ao scan bem-sucedido.
- Botão "Cancelar" no canto superior.
- Botão "Modo manual" se OCR falhar repetidamente.

Tecnologia: `camera` + `google_mlkit_text_recognition` + `google_mlkit_barcode_scanning`.

### 2.4 Confirmar recebimento (revisar dados extraídos)
Após scan, mostra os dados extraídos para revisão:
- Foto da etiqueta (preview pequeno, expansível).
- Transportadora identificada (com logo, ou "Outra" se não reconhecida).
- Código de rastreio.
- Nome do destinatário (extraído).
- **Unidade sugerida** (cruzamento com cadastro) — pode estar em branco.
- **Morador sugerido** (idem).
- Campo de notas (opcional).
- Botões "Confirmar" e "Voltar/refazer".

Endpoint: `POST /api/v1/packages` com `Idempotency-Key`.

### 2.5 Identificar destinatário (manual)
Caso OCR não identifique unidade/morador, ou porteiro queira corrigir.
- Busca por unidade (autocomplete).
- Busca por morador (lista filtrada pela unidade).
- Botão "Confirmar identificação".
- Opção "Não consigo identificar" → cria pacote com `pending_identification`.

Endpoint: `PATCH /api/v1/packages/:id/identify`.

### 2.6 Lista de pacotes
Lista filtrada e paginada.
- Filtros: status (todos, aguardando retirada, pendente identificação, entregues, devolvidos).
- Filtro por data.
- Busca por nome do destinatário, unidade ou tracking.
- Cada item: unidade, nome, status (chip), tempo aguardando, ícone da transportadora.
- Tap → detalhes.
- Pull-to-refresh.

Endpoint: `GET /api/v1/packages?status=...&page=...`.

### 2.7 Detalhes do pacote
Tela completa de um pacote.
- Foto da etiqueta.
- Todos os campos: transportadora, código, destinatário, unidade, datas, quem recebeu/entregou.
- Histórico (timeline) de eventos.
- Botões de ação contextuais:
  - "Identificar" (se `pending_identification`).
  - "Registrar entrega" (se `awaiting_pickup`).
  - "Registrar devolução" (se `awaiting_pickup`).
  - "Cancelar" (se ainda não entregue).

Endpoint: `GET /api/v1/packages/:id`.

### 2.8 Registrar entrega
Confirmação de retirada.
- Resumo do pacote.
- Quem retirou: nome (texto livre) **ou** valida token de retirada (próxima tela).
- Campo de observações (opcional).
- Botões "Confirmar entrega" e "Cancelar".

Endpoint: `POST /api/v1/packages/:id/deliver`.

### 2.9 Validar token de retirada
Retirada por terceiro (morador autorizou).
- Input: código do token (6 chars).
- Botão "Validar".
- Mostra: nome autorizado, validade, pacote relacionado.
- Após validação OK, navega para "Registrar entrega" pré-preenchida.

Endpoint: `GET /api/v1/pickup-tokens/:code`.

### 2.10 Registrar devolução
Pacote retorna à transportadora.
- Resumo do pacote.
- Motivo (opcional).
- Botão "Confirmar devolução".

Endpoint: `POST /api/v1/packages/:id/return`.

---

## 3. Telas auxiliares

### 3.1 Operações pendentes (fila offline)
Mostra operações que não conseguiram subir.
- Lista com tipo (recebimento, entrega, etc.), data, status (`enviando`, `falhou`).
- Botão "Tentar novamente" por item.
- Botão "Descartar" (com confirmação).
- Indicador de conectividade no topo.

Acessível pelo badge na home.

### 3.2 Perfil
Dados do usuário logado.
- Nome, email, role.
- Lista de condomínios em que tem membership.
- Botão "Trocar condomínio" (se múltiplos).
- Link para Configurações.
- Botão "Sair" (logout).

### 3.3 Configurações
- Tema: claro / escuro / automático.
- MFA: ativar/desativar (se opcional).
- Versão do app + commit hash + ambiente.
- Política de privacidade (link externo).
- Termos de uso (link externo).
- Solicitar exclusão da conta (link para suporte).

### 3.4 Configurar MFA (TOTP)
- Mostra QR code para escanear no Google Authenticator/1Password.
- Input para validar primeiro código.
- Lista de códigos de recuperação (10) — botão para copiar/salvar.
- Avisa que recovery codes são únicos.

Endpoint: `POST /api/v1/auth/mfa/setup`.

---

## 4. Estados especiais (não são telas, mas precisam ser tratados)

### 4.1 Banner de conectividade
- "Você está offline. Operações ficarão pendentes." — banner persistente no topo.
- "Voltou online — sincronizando..." — toast temporário.

### 4.2 Erros padrão
- **401:** redireciona para login (após tentar refresh).
- **403:** "Você não tem permissão para esta ação."
- **5xx:** "Serviço temporariamente indisponível."
- **Timeout:** "Conexão lenta — tente novamente."

Mapping: `LogiFree_Tratamento_Erros.md` no back-front.

### 4.3 Empty states
- Lista de pacotes vazia: "Nenhum pacote ainda. Toque em 'Escanear' para começar."
- Sem condomínios: "Você não tem acesso a nenhum condomínio. Fale com o síndico."

### 4.4 Loading states
- Skeleton em listas (não spinner genérico).
- Progress bar inline nos botões durante submit.

---

## 5. Navegação (rotas)

```
/                          → splash, decide próximo
/login                     → tela 1.2
/forgot-password           → tela 1.3
/reset-password            → tela 1.4 (deep link)
/mfa-prompt                → tela 1.5

/select-condominium        → tela 2.1
/c/:slug/                  → home (tela 2.2)
/c/:slug/scan              → tela 2.3
/c/:slug/scan/confirm      → tela 2.4
/c/:slug/packages          → tela 2.6
/c/:slug/packages/:id      → tela 2.7
/c/:slug/packages/:id/identify → tela 2.5
/c/:slug/packages/:id/deliver  → tela 2.8
/c/:slug/packages/:id/return   → tela 2.10
/c/:slug/pickup-token      → tela 2.9
/c/:slug/pending           → tela 3.1
/c/:slug/profile           → tela 3.2
/c/:slug/settings          → tela 3.3
/c/:slug/settings/mfa      → tela 3.4
```

Configurado via `go_router`. Guard de auth redireciona não-autenticado para `/login`.

---

## 6. Convenções UX para porteiro

- **Tap targets ≥ 48dp.** Porteiro pode estar usando uma mão.
- **Operações de risco com confirmação** (cancelar, devolver). Outras (escanear, registrar) sem fricção.
- **Feedback visual e háptico** após ação (vibração curta no scan, no submit).
- **Português pt-BR.** Sem jargão técnico.
- **Modo escuro disponível** — útil em portarias com pouca luz.
- **Botão de ação primária sempre visível** (FAB ou bottom bar).
- **Sem scroll horizontal.** Tudo vertical.
- **Mensagens de erro acionáveis** ("Verifique a conexão" + botão "Tentar de novo").

---

## 7. Telas que NÃO entram no MVP

- Notificações in-app em tempo real (WebSocket adiado).
- Chat com síndico/morador.
- Galeria/mural de avisos do condomínio.
- Marketplace de transportadoras.
- Configuração de templates de email (síndico faz no painel).
- Cadastro de moradores/unidades (síndico faz no painel).
- Convite de morador (síndico faz no painel).

---

## 8. Prioridade de implementação (ordem sugerida)

| # | Tela | Sprint sugerido |
|---|---|---|
| 1 | Login (1.2) | 3 |
| 2 | Splash (1.1) | 3 |
| 3 | Home (2.2) | 3 |
| 4 | Câmera + OCR (2.3) | 4 |
| 5 | Confirmar recebimento (2.4) | 4 |
| 6 | Identificar destinatário (2.5) | 4 |
| 7 | Lista de pacotes (2.6) | 5 |
| 8 | Detalhes do pacote (2.7) | 5 |
| 9 | Registrar entrega (2.8) | 5 |
| 10 | Validar token de retirada (2.9) | 6 |
| 11 | Registrar devolução (2.10) | 6 |
| 12 | Operações pendentes (3.1) | 7 |
| 13 | Perfil (3.2) + Configurações (3.3) | 7 |
| 14 | Esqueci/Reset senha (1.3, 1.4) | 7 |
| 15 | Seletor de condomínio (2.1) | 8 |
| 16 | MFA (1.5, 3.4) | 8 |

---

## Docs relacionadas

- `LogiFree_Mobile_Estrutura.md` — onde cada tela vive em `lib/features/`.
- `LogiFree_Mobile_Auth.md` — fluxo de autenticação detalhado.
- `LogiFree_Mobile_OCR.md` — câmera, leitura de etiqueta, parsing.
- `LogiFree_Mobile_Offline.md` — fila pendente.
- `../logifree-back-front/.claude/ia/LogiFree_Tratamento_Erros.md` — códigos de erro a mapear.
- `../logifree-back-front/.claude/ia/LogiFree_Multi_Condominio.md` — `X-Condominium-Slug` em cada request.
