/// Corpo do `POST /api/v1/packages/receive`.
class ReceivePackageRequest {
  const ReceivePackageRequest({
    required this.trackingCode,
    required this.unitId,
    this.description,
  });

  /// Código de rastreio lido da etiqueta.
  final String trackingCode;

  /// UUID da unidade destinatária.
  final String unitId;

  /// Observações livres (vai para `description` no back).
  final String? description;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'trackingCode': trackingCode,
    'unitId': unitId,
    if (description != null && description!.isNotEmpty)
      'description': description,
  };
}
