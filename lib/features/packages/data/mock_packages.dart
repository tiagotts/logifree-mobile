import '../../auth/domain/doorman.dart';
import '../domain/carrier.dart';
import '../domain/package.dart';
import '../domain/package_event.dart';
import '../domain/package_status.dart';

/// Dados fictícios que alimentam o protótipo enquanto não há backend.
List<Package> seedPackages() {
  final now = DateTime.now();
  final doorman = demoDoorman.name;

  /// Monta um instante a `days` dias atrás, no horário `hour:minute`.
  DateTime at(int days, int hour, int minute) {
    final day = DateTime(now.year, now.month, now.day, hour, minute);
    return day.subtract(Duration(days: days));
  }

  return [
    Package(
      id: 'pkg-001',
      trackingCode: 'MLB4582930071',
      carrier: Carrier.mercadoLivre,
      status: PackageStatus.awaitingPickup,
      receivedAt: at(0, 8, 30),
      receivedBy: doorman,
      recipientName: 'Maria Silva',
      unit: 'Apto 101',
      events: [
        PackageEvent(
          type: PackageEventType.received,
          timestamp: at(0, 8, 30),
          actor: doorman,
        ),
        PackageEvent(
          type: PackageEventType.identified,
          timestamp: at(0, 8, 31),
          actor: doorman,
        ),
      ],
    ),
    Package(
      id: 'pkg-002',
      trackingCode: 'TBA309128847766',
      carrier: Carrier.amazon,
      status: PackageStatus.awaitingPickup,
      receivedAt: at(0, 10, 15),
      receivedBy: doorman,
      recipientName: 'Carlos Souza',
      unit: 'Apto 304',
      notes: 'Caixa grande, deixar no balcão.',
      events: [
        PackageEvent(
          type: PackageEventType.received,
          timestamp: at(0, 10, 15),
          actor: doorman,
        ),
        PackageEvent(
          type: PackageEventType.identified,
          timestamp: at(0, 10, 16),
          actor: doorman,
        ),
      ],
    ),
    Package(
      id: 'pkg-003',
      trackingCode: 'BR784512369BR',
      carrier: Carrier.correios,
      status: PackageStatus.awaitingPickup,
      receivedAt: at(1, 16, 40),
      receivedBy: doorman,
      recipientName: 'Ana Pereira',
      unit: 'Apto 502',
      events: [
        PackageEvent(
          type: PackageEventType.received,
          timestamp: at(1, 16, 40),
          actor: doorman,
        ),
        PackageEvent(
          type: PackageEventType.identified,
          timestamp: at(1, 16, 42),
          actor: doorman,
        ),
      ],
    ),
    Package(
      id: 'pkg-004',
      trackingCode: 'SPXBR0099231845',
      carrier: Carrier.shopee,
      status: PackageStatus.awaitingPickup,
      receivedAt: at(3, 11, 0),
      receivedBy: doorman,
      recipientName: 'Roberto Lima',
      unit: 'Apto 12',
      events: [
        PackageEvent(
          type: PackageEventType.received,
          timestamp: at(3, 11, 0),
          actor: doorman,
        ),
        PackageEvent(
          type: PackageEventType.identified,
          timestamp: at(3, 11, 1),
          actor: doorman,
        ),
      ],
    ),
    Package(
      id: 'pkg-005',
      trackingCode: 'BR550148872BR',
      carrier: Carrier.other,
      status: PackageStatus.pendingIdentification,
      receivedAt: at(0, 9, 50),
      receivedBy: doorman,
      notes: 'Etiqueta rasurada, sem nome legível.',
      events: [
        PackageEvent(
          type: PackageEventType.received,
          timestamp: at(0, 9, 50),
          actor: doorman,
        ),
      ],
    ),
    Package(
      id: 'pkg-006',
      trackingCode: 'BR221904557BR',
      carrier: Carrier.correios,
      status: PackageStatus.pendingIdentification,
      receivedAt: at(2, 15, 20),
      receivedBy: doorman,
      events: [
        PackageEvent(
          type: PackageEventType.received,
          timestamp: at(2, 15, 20),
          actor: doorman,
        ),
      ],
    ),
    Package(
      id: 'pkg-007',
      trackingCode: 'MLB4471188250',
      carrier: Carrier.mercadoLivre,
      status: PackageStatus.delivered,
      receivedAt: at(1, 9, 0),
      receivedBy: doorman,
      recipientName: 'Juliana Costa',
      unit: 'Apto 201',
      deliveredAt: at(0, 13, 30),
      pickedUpBy: 'Juliana Costa',
      events: [
        PackageEvent(
          type: PackageEventType.received,
          timestamp: at(1, 9, 0),
          actor: doorman,
        ),
        PackageEvent(
          type: PackageEventType.identified,
          timestamp: at(1, 9, 2),
          actor: doorman,
        ),
        PackageEvent(
          type: PackageEventType.delivered,
          timestamp: at(0, 13, 30),
          actor: 'Juliana Costa',
        ),
      ],
    ),
    Package(
      id: 'pkg-008',
      trackingCode: 'TBA771300925514',
      carrier: Carrier.amazon,
      status: PackageStatus.delivered,
      receivedAt: at(2, 17, 10),
      receivedBy: doorman,
      recipientName: 'Pedro Alves',
      unit: 'Apto 405',
      deliveredAt: at(1, 19, 5),
      pickedUpBy: 'Pedro Alves',
      events: [
        PackageEvent(
          type: PackageEventType.received,
          timestamp: at(2, 17, 10),
          actor: doorman,
        ),
        PackageEvent(
          type: PackageEventType.identified,
          timestamp: at(2, 17, 12),
          actor: doorman,
        ),
        PackageEvent(
          type: PackageEventType.delivered,
          timestamp: at(1, 19, 5),
          actor: 'Pedro Alves',
        ),
      ],
    ),
    Package(
      id: 'pkg-009',
      trackingCode: 'BR664210038BR',
      carrier: Carrier.correios,
      status: PackageStatus.returned,
      receivedAt: at(6, 14, 0),
      receivedBy: doorman,
      recipientName: 'Fernanda Dias',
      unit: 'Apto 88',
      deliveredAt: at(4, 10, 30),
      notes: 'Morador recusou a entrega.',
      events: [
        PackageEvent(
          type: PackageEventType.received,
          timestamp: at(6, 14, 0),
          actor: doorman,
        ),
        PackageEvent(
          type: PackageEventType.identified,
          timestamp: at(6, 14, 3),
          actor: doorman,
        ),
        PackageEvent(
          type: PackageEventType.returned,
          timestamp: at(4, 10, 30),
          actor: doorman,
          note: 'Morador recusou a entrega.',
        ),
      ],
    ),
  ];
}
