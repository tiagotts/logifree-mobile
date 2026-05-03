# POC - OCR com Google ML Kit

Esta é uma Prova de Conceito (POC) simples para demonstrar a capacidade de OCR (Optical Character Recognition) usando Google ML Kit no LogiFree Mobile.

## Funcionalidades

- ✅ Reconhecimento de texto em imagens
- ✅ Leitura de códigos de barras (QR Code, Code128, etc.)
- ✅ Seleção de imagem da galeria
- ✅ Captura de imagem com câmera
- ✅ Preview da imagem selecionada
- ✅ Exibição de resultados estruturados

## Arquitetura

A POC segue a estrutura documentada em `docs/LogiFree_Mobile_Estrutura.md`:

```
lib/features/scan/
├── data/
│   ├── ocr_result.dart       # Modelo de dados
│   └── ocr_service.dart      # Serviço de OCR (Google ML Kit)
└── presentation/
    └── scan_screen.dart      # Tela de interface
```

## Como Executar

### 1. Instalar dependências

```bash
flutter pub get
```

### 2. Executar no dispositivo/simulador

```bash
# iOS Simulator
flutter run -d ios

# Android Emulator
flutter run -d emulator

# Android Device
flutter run -d android
```

Ou use as configurações de launch do VSCode criadas em `.vscode/launch.json`.

### 3. Usar a aplicação

1. Toque no botão **Galeria** para selecionar uma imagem existente
2. Ou toque no botão **Câmera** para tirar uma foto
3. Aguarde o processamento (geralmente < 2 segundos)
4. Visualize os resultados:
   - **Texto Reconhecido**: Todo texto detectado na imagem
   - **Códigos de Barras**: Códigos QR, Code128, etc.
   - **Resumo**: Estatísticas sobre os dados extraídos

## Testando OCR

### Tipos de imagens para testar

1. **Etiquetas de encomendas** - Objetivo principal do LogiFree
   - Código de rastreio
   - Nome do destinatário
   - Endereço
   - Transportadora

2. **Documentos** - Texto impresso ou manuscrito
   - Faturas
   - Recibos
   - Cartas

3. **Códigos de barras**
   - QR Codes
   - Códigos de rastreio dos Correios (BR123456789BR)
   - Códigos Mercado Livre (MLB...)
   - Códigos Amazon (TBA...)

### Dicas para melhores resultados

- Use imagens com boa iluminação
- Evite reflexos ou sombras
- Mantenha a imagem focada
- Alinhe o texto horizontalmente quando possível
- Use resolução média (não é necessário alta resolução)

## Tecnologias Utilizadas

- **Google ML Kit Text Recognition** - Reconhecimento de texto on-device
- **Google ML Kit Barcode Scanning** - Leitura de códigos de barras
- **Image Picker** - Seleção de imagens da galeria/câmera

## Próximos Passos

Esta POC demonstra a viabilidade técnica. Para a implementação completa:

1. ✅ OCR básico funcionando
2. ⏳ Adicionar padrões de transportadora (regex) - `docs/LogiFree_Mobile_OCR.md`
3. ⏳ Implementar identificação automática de destinatário
4. ⏳ Integrar com câmera em tempo real (preview contínuo)
5. ⏳ Adicionar fallback manual para edição
6. ⏳ Implementar Riverpod para state management
7. ⏳ Adicionar testes unitários

## Observações

- Todo processamento é feito **on-device** (sem internet necessária)
- Performance: < 2 segundos para processar imagem média
- Privacidade: nenhuma imagem é enviada para servidores externos
- Funciona offline (ideal para porteiros em áreas sem conexão)

## Permissões Necessárias

### Android

Já configuradas no template padrão do Flutter:
- Camera (para tirar fotos)
- Storage (para acessar galeria)

### iOS

Já configuradas no template padrão do Flutter:
- Camera Usage
- Photo Library Usage

Se necessário, adicione descrições personalizadas em `ios/Runner/Info.plist`.
