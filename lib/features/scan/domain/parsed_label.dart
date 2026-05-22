import '../../packages/domain/carrier.dart';

/// Dados extraídos de uma etiqueta pelo `LabelParser`.
///
/// Todos os campos são palpites: a tela de conferência sempre deixa o
/// porteiro revisar e corrigir antes de registrar.
class ParsedLabel {
  const ParsedLabel({
    this.recipientName,
    this.unit,
    this.trackingCode,
    this.carrier,
  });

  /// Nenhum dado identificado.
  static const ParsedLabel empty = ParsedLabel();

  final String? recipientName;
  final String? unit;
  final String? trackingCode;
  final Carrier? carrier;

  /// `true` se destinatário ou unidade foram identificados.
  bool get hasRecipient => recipientName != null || unit != null;
}
