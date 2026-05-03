# LogiFree Mobile — OCR e Captura de Etiqueta

## Stack

- **`google_mlkit_text_recognition`** — extrair texto livre (nome, endereço).
- **`google_mlkit_barcode_scanning`** — código de barras (Code128, padrão Correios) e QR (Mercado Livre, Amazon).
- **`camera`** — controle do hardware.

Tudo on-device. Sem chamada externa para análise primária.

---

## Fluxo de captura

1. Porteiro abre tela de scan.
2. `CameraPreview` + overlay (área de mira).
3. Captura automática quando código de barras é detectado, OU manual (botão).
4. Extrai:
   - Texto via ML Kit text recognition.
   - Código(s) via ML Kit barcode scanning.
5. Tenta identificar **transportadora** via padrão (regex em `tracking_code`).
6. Tenta identificar **unit/morador** via cruzamento de texto + cadastro do condomínio.
7. Mostra preview ao porteiro com dados pré-preenchidos.
8. Porteiro confirma ou edita; submete para `POST /api/v1/packages`.

---

## Identificação de transportadora

Catálogo em `core/carriers/carrier_patterns.dart`:

```dart
const carrierPatterns = [
  CarrierPattern(slug: 'correios',     regex: r'^[A-Z]{2}\d{9}[A-Z]{2}$'),
  CarrierPattern(slug: 'mercadolivre', regex: r'^MLB\d+$'),
  CarrierPattern(slug: 'amazon',       regex: r'^TBA\d+$'),
  // ...
];
```

Lista cresce conforme padrões reais aparecem no piloto. Tabela `carrier` no backend é fonte da verdade longo prazo.

---

## Fallback manual

Se OCR não conseguir identificar:
- Tela de form simples para porteiro digitar manualmente: nome destinatário, transportadora (dropdown), código rastreio (opcional).
- Foto da etiqueta enviada como anexo.

---

## Performance

- Câmera com resolução **medium** (suficiente para OCR, leve em memória).
- Processamento em isolate quando possível para não travar UI.
- Cancelar análise se nova frame entra antes da anterior terminar.

---

## Critérios de aceitação (POC Sprint 2)

- Taxa de identificação de transportadora ≥ 95% em condições normais.
- Tempo de leitura < 2s.
- Funciona em hardware Android baixo (testar em Galaxy A03 ou similar).
