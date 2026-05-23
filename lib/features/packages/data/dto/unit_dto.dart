/// Unidade cadastrada no condomínio, conforme `GET /api/v1/units`.
class UnitDto {
  const UnitDto({
    required this.id,
    required this.condominiumId,
    required this.type,
    required this.number,
    required this.status,
    this.block,
    this.floor,
    this.complement,
  });

  final String id;
  final String condominiumId;

  /// Tipo da unidade: `apartment`, `house`, `commercial`, etc.
  final String type;

  /// Bloco/torre (opcional).
  final String? block;

  /// Andar (opcional).
  final int? floor;

  /// Número da unidade (ex.: `601`, `42A`).
  final String number;

  /// Texto livre adicional (ex.: nome de bloco antigo, "JALES").
  final String? complement;

  /// `active` ou `inactive`.
  final String status;

  /// Nome amigável para exibir no dropdown ("Apto 601", "Casa 12").
  String get displayName {
    final base = _typeLabel(type);
    return '$base $number';
  }

  /// Linha secundária com bloco/complemento ("Bloco A · JALES").
  String? get subtitle {
    final parts = <String>[
      if (block != null && block!.isNotEmpty) 'Bloco $block',
      if (complement != null && complement!.isNotEmpty) complement!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static String _typeLabel(String type) {
    switch (type) {
      case 'apartment':
        return 'Apto';
      case 'house':
        return 'Casa';
      case 'commercial':
        return 'Sala';
      default:
        return 'Unidade';
    }
  }

  factory UnitDto.fromJson(Map<String, dynamic> json) {
    return UnitDto(
      id: json['id'] as String,
      condominiumId: json['condominiumId'] as String,
      type: json['type'] as String,
      block: json['block'] as String?,
      floor: json['floor'] as int?,
      number: json['number'] as String,
      complement: json['complement'] as String?,
      status: json['status'] as String,
    );
  }
}
