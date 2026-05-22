/// Fixtures comuns para testes.
///
/// Centralize aqui valores reutilizados em múltiplos arquivos de teste.
/// Inspirado em `apps/api/src/test/seed.ts` (back-front).
library;

/// Códigos de rastreio reais (formato público) para testar parsing de OCR.
class SampleTrackingCodes {
  static const correios = 'BR123456789BR';
  static const mercadoLivre = 'MLB1234567890';
  static const amazon = 'TBA123456789000';
  static const jadlog = 'JD0000000001';
  static const loggi = 'LOGGI-AB12CD';
}

/// Texto típico de etiquetas para testar text recognition.
class SampleLabelTexts {
  /// Etiqueta dos Correios.
  static const correios = '''
DESTINATÁRIO:
JOÃO SILVA
RUA DAS FLORES, 123 APT 101
EDIFÍCIO ÁGUAS CLARAS
70000-000 - BRASÍLIA - DF
CÓDIGO: BR123456789BR
''';

  /// Etiqueta Mercado Livre.
  static const mercadoLivre = '''
PEDIDO #MLB1234567890
DESTINATÁRIO: Maria Santos
RUA EXEMPLO, 456 - APT 302
70123-456 BRASÍLIA DF
''';
}

/// Email de morador padrão usado nos testes.
const String sampleResidentEmail = 'morador.teste@logifree.local';

/// Telefone E.164 brasileiro válido para testes.
const String sampleResidentPhone = '+5561999998888';
