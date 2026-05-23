import 'dart:async';
import 'dart:developer' as developer;

import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ocr_result.dart';
import '../data/ocr_service.dart';
import '../domain/label_parser.dart';
import '../domain/parsed_label.dart';
import '../domain/scan_capture.dart';

/// Provider de `OcrService` — libera os recognizers quando o provider for descartado.
final ocrServiceProvider = Provider<OcrService>((ref) {
  final service = OcrService();
  ref.onDispose(service.dispose);
  return service;
});

/// Provider que entrega o `ScanCaptureService` — orquestrador de captura.
final scanCaptureServiceProvider = Provider<ScanCaptureService>((ref) {
  return ScanCaptureService(ref.watch(ocrServiceProvider));
});

/// Orquestra: tirar foto → rodar OCR → montar `ScanCapture` com `ParsedLabel`.
///
/// Sem estado próprio — é um serviço puro injetado via Riverpod. Mantém o
/// controller da câmera (`ScanCameraNotifier`) e a UI desacoplados do
/// `OcrService`.
class ScanCaptureService {
  const ScanCaptureService(this._ocr);

  final OcrService _ocr;

  /// Captura um frame usando o `CameraController` e roda o OCR sobre ele.
  ///
  /// Retorna `null` se a câmera não estiver pronta — a UI decide o que fazer.
  Future<ScanCapture?> captureFromCamera(CameraController controller) async {
    if (!controller.value.isInitialized) return null;
    try {
      final file = await controller.takePicture();
      return _runOcr(file.path);
    } on CameraException catch (e, st) {
      developer.log(
        'Falha ao capturar foto',
        name: 'ScanCaptureService',
        error: e,
        stackTrace: st,
      );
      return ScanCapture(
        photoPath: '',
        ocr: OcrResult(error: 'Falha ao capturar foto: ${e.description}'),
        label: ParsedLabel.empty,
      );
    }
  }

  /// Roda o OCR sobre uma imagem já existente em disco (galeria, etc.).
  Future<ScanCapture> captureFromFile(String path) => _runOcr(path);

  Future<ScanCapture> _runOcr(String path) async {
    final result = await _ocr.processImage(path);
    return ScanCapture(
      photoPath: path,
      ocr: result,
      label: LabelParser.parse(result),
    );
  }
}
