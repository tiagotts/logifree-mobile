class OcrResult {
  final String? text;
  final List<String> barcodes;
  final String? error;

  const OcrResult({this.text, this.barcodes = const [], this.error});

  bool get hasError => error != null;
  bool get hasText => text != null && text!.isNotEmpty;
  bool get hasBarcodes => barcodes.isNotEmpty;
  bool get hasData => hasText || hasBarcodes;
}
