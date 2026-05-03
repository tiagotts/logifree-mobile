# LogiFree Mobile — Estratégia Offline

App do porteiro precisa funcionar **sem internet** para registrar entradas. Operações ficam em fila local; sincronizam ao reconectar.

---

## Operações que vão para fila offline

- Registrar pacote recebido (`POST /packages`).
- Registrar entrega (`POST /packages/:id/deliver`).
- Registrar devolução (`POST /packages/:id/return`).
- Identificar destinatário (`PATCH /packages/:id/identify`).

---

## O que **não** funciona offline

- Login (precisa do backend para JWT).
- Listagem de unidades/moradores (precisa cache prévio carregado online).
- Histórico antigo (snapshot pode estar desatualizado).

---

## Storage

`sqflite` em `core/storage/offline_queue.dart`:

```sql
CREATE TABLE pending_operations (
  id TEXT PRIMARY KEY,             -- UUID v7 client-side
  type TEXT NOT NULL,              -- 'package.scan' | 'package.deliver' | ...
  endpoint TEXT NOT NULL,          -- 'POST /packages'
  payload TEXT NOT NULL,           -- JSON
  created_at INTEGER NOT NULL,
  retry_count INTEGER DEFAULT 0,
  last_error TEXT
);
```

---

## Fluxo

1. Porteiro escaneia → app cria registro em `pending_operations` + atualiza UI **otimisticamente**.
2. Se online: dispara HTTP imediatamente. Se sucesso, remove da fila.
3. Se offline: deixa na fila com badge "pendente" no item.
4. `connectivity_plus` notifica quando volta online → worker processa fila em ordem.
5. Item processado com sucesso → DELETE da tabela.
6. Falha (5xx ou timeout) → incrementa `retry_count`. Após 5 tentativas com falha → marca `last_error` e avisa porteiro (precisa intervenção).

---

## Conflitos

Cenário: porteiro registra entrega de um pacote que outro porteiro já entregou online.

Backend retorna 409 (`PACKAGE_ALREADY_DELIVERED`).
App marca operação como rejeitada e mostra ao porteiro o estado real do pacote.

---

## Idempotência

- ID do registro é gerado **no cliente** (UUID v7).
- Backend aceita `Idempotency-Key` header com o mesmo ID — duplicatas são rejeitadas com 409.
- Reprocessar a fila múltiplas vezes é seguro.

---

## UI

- Badge no header indica "X operações pendentes".
- Tela "Pendências" lista cada operação com status (`enviando`, `falhou: motivo`).
- Ação manual: tentar de novo, ou descartar.
