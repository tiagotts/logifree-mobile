import '../data/ocr_result.dart';
import 'parsed_label.dart';

/// Resultado de uma captura de etiqueta: a foto, o texto bruto do OCR e os
/// dados já interpretados pelo `LabelParser`.
///
/// Trafega da [ScanScreen] para a tela de confirmar recebimento via
/// `GoRouterState.extra`.
class ScanCapture {
  const ScanCapture({
    required this.photoPath,
    required this.ocr,
    required this.label,
  });

  /// Caminho local da imagem capturada.
  final String photoPath;

  /// Texto e códigos de barras extraídos pelo OCR.
  final OcrResult ocr;

  /// Destinatário, unidade e código identificados na etiqueta.
  final ParsedLabel label;
}
