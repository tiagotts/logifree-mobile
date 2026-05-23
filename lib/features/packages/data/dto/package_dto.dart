import 'unit_dto.dart';

/// Pacote conforme `GET /api/v1/packages`.
///
/// Modelo tolerante: campos que ainda não foram confirmados no contrato
/// real são marcados como opcionais e o `fromJson` segue funcionando se
/// faltarem.
class PackageDto {
  const PackageDto({
    required this.id,
    required this.trackingCode,
    required this.status,
    required this.receivedAt,
    this.unitId,
    this.unit,
    this.description,
    this.deliveredAt,
    this.receivedBy,
    this.deliveredBy,
  });

  final String id;
  final String trackingCode;
  final String status;
  final DateTime receivedAt;

  /// UUID da unidade destinatária. Pode vir como campo solto (`unitId`) ou
  /// embutido em `unit.id`.
  final String? unitId;

  /// Unidade embutida no payload (quando o back populates).
  final UnitDto? unit;

  /// Observação livre (`description` no body do receive).
  final String? description;

  final DateTime? deliveredAt;
  final String? receivedBy;
  final String? deliveredBy;

  factory PackageDto.fromJson(Map<String, dynamic> json) {
    // Aceita 'unit' embutido (objeto) ou só 'unitId' solto.
    UnitDto? embeddedUnit;
    if (json['unit'] is Map<String, dynamic>) {
      embeddedUnit = UnitDto.fromJson(json['unit'] as Map<String, dynamic>);
    }
    final String? unitIdField = json['unitId'] as String? ?? embeddedUnit?.id;

    return PackageDto(
      id: json['id'] as String,
      trackingCode: json['trackingCode'] as String,
      status: json['status'] as String,
      receivedAt: _parseDate(json['receivedAt']) ?? DateTime.now(),
      unitId: unitIdField,
      unit: embeddedUnit,
      description: json['description'] as String?,
      deliveredAt: _parseDate(json['deliveredAt']),
      receivedBy: json['receivedBy'] as String?,
      deliveredBy: json['deliveredBy'] as String?,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }
}
