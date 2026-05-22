/// Exemplo de teste unitário (sem plugins nativos, sem widgets).
/// Padrão para testes de modelo/data classes.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:logifree_mobile/features/scan/data/ocr_result.dart';

import '../../../test_helpers/test_helpers.dart';

void main() {
  group('OcrResult', () {
    test('hasError é true quando error não é null', () {
      const result = OcrResult(error: 'falha');
      expect(result.hasError, isTrue);
      expect(result.hasData, isFalse);
    });

    test('hasText é true quando text é não-vazio', () {
      const result = OcrResult(text: SampleLabelTexts.correios);
      expect(result.hasText, isTrue);
      expect(result.hasData, isTrue);
    });

    test('hasText é false quando text é string vazia', () {
      const result = OcrResult(text: '');
      expect(result.hasText, isFalse);
    });

    test('hasBarcodes é true quando lista tem ao menos 1 item', () {
      const result = OcrResult(barcodes: [SampleTrackingCodes.correios]);
      expect(result.hasBarcodes, isTrue);
      expect(result.hasData, isTrue);
    });

    test('hasData é false quando vazio', () {
      const result = OcrResult();
      expect(result.hasData, isFalse);
      expect(result.hasError, isFalse);
    });
  });
}
