import 'carrier.dart';
import 'package_event.dart';
import 'package_status.dart';

/// Um pacote registrado na portaria do condomínio.
class Package {
  const Package({
    required this.id,
    required this.trackingCode,
    required this.carrier,
    required this.status,
    required this.receivedAt,
    required this.receivedBy,
    required this.events,
    this.recipientName,
    this.unit,
    this.deliveredAt,
    this.pickedUpBy,
    this.notes,
    this.labelPhotoPath,
  });

  final String id;
  final String trackingCode;
  final Carrier carrier;
  final PackageStatus status;

  /// Quando o pacote foi recebido na portaria.
  final DateTime receivedAt;

  /// Porteiro que registrou o recebimento.
  final String receivedBy;

  /// Histórico de eventos, do mais antigo ao mais recente.
  final List<PackageEvent> events;

  /// Nome do destinatário, quando identificado.
  final String? recipientName;

  /// Unidade/apartamento do destinatário, quando identificado.
  final String? unit;

  /// Quando o pacote foi entregue ou devolvido.
  final DateTime? deliveredAt;

  /// Quem retirou o pacote (morador ou autorizado).
  final String? pickedUpBy;

  /// Observações livres.
  final String? notes;

  /// Caminho local da foto da etiqueta (preenchido quando vem do scan).
  final String? labelPhotoPath;

  /// `true` quando destinatário e unidade estão preenchidos.
  bool get isIdentified => recipientName != null && unit != null;

  /// Quanto tempo o pacote esperou (ou está esperando) na portaria.
  Duration get waitingTime =>
      (deliveredAt ?? DateTime.now()).difference(receivedAt);

  Package copyWith({
    PackageStatus? status,
    String? recipientName,
    String? unit,
    DateTime? deliveredAt,
    String? pickedUpBy,
    String? notes,
    List<PackageEvent>? events,
  }) {
    return Package(
      id: id,
      trackingCode: trackingCode,
      carrier: carrier,
      status: status ?? this.status,
      receivedAt: receivedAt,
      receivedBy: receivedBy,
      events: events ?? this.events,
      recipientName: recipientName ?? this.recipientName,
      unit: unit ?? this.unit,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      pickedUpBy: pickedUpBy ?? this.pickedUpBy,
      notes: notes ?? this.notes,
      labelPhotoPath: labelPhotoPath,
    );
  }
}
