import 'dart:io';

import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'ocr_result.dart';

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer();
  final BarcodeScanner _barcodeScanner = BarcodeScanner();

  Future<OcrResult> processImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFile(File(imagePath));

      // Processar texto e códigos de barras em paralelo
      final results = await Future.wait([
        _recognizeText(inputImage),
        _scanBarcodes(inputImage),
      ]);

      final text = results[0] as String?;
      final barcodes = results[1] as List<String>;

      return OcrResult(text: text, barcodes: barcodes);
    } catch (e) {
      return OcrResult(error: 'Erro ao processar imagem: $e');
    }
  }

  Future<String?> _recognizeText(InputImage inputImage) async {
    try {
      final recognizedText = await _textRecognizer.processImage(inputImage);
      return recognizedText.text.isEmpty ? null : recognizedText.text;
    } catch (e) {
      return null;
    }
  }

  Future<List<String>> _scanBarcodes(InputImage inputImage) async {
    try {
      final barcodes = await _barcodeScanner.processImage(inputImage);
      return barcodes
          .where((barcode) => barcode.rawValue != null)
          .map((barcode) => barcode.rawValue!)
          .toList();
    } catch (e) {
      return [];
    }
  }

  void dispose() {
    _textRecognizer.close();
    _barcodeScanner.close();
  }
}
