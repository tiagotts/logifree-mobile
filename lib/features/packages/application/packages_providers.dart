import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dto/package_dto.dart';
import '../data/dto/unit_dto.dart';
import '../data/package_repository.dart';
import '../domain/carrier.dart';
import '../domain/daily_summary.dart';
import '../domain/package.dart';
import '../domain/package_event.dart';
import '../domain/package_status.dart';
import 'units_provider.dart';

/// Estado central dos pacotes, agora alimentado pelo back via
/// `GET /api/v1/packages`.
///
/// Os mutadores (`identify`, `deliver`, `markReturned`) ainda atualizam
/// **só o estado local** — os endpoints HTTP correspondentes serão
/// implementados em cards posteriores. Quando isso acontecer, eles
/// passam a chamar o `PackageRepository` e invalidar o provider.
final AsyncNotifierProvider<PackagesNotifier, List<Package>> packagesProvider =
    AsyncNotifierProvider<PackagesNotifier, List<Package>>(
      PackagesNotifier.new,
    );

class PackagesNotifier extends AsyncNotifier<List<Package>> {
  @override
  Future<List<Package>> build() async {
    final repo = ref.read(packageRepositoryProvider);
    // Reutiliza o cache do `unitsProvider` para fazer o lookup
    // unidade-por-id sem disparar outro GET /units.
    final List<UnitDto> units = await ref.watch(unitsProvider.future);
    final Map<String, UnitDto> unitsById = <String, UnitDto>{
      for (final u in units) u.id: u,
    };

    final dtos = await repo.list();
    final list = dtos.map((PackageDto dto) {
      final UnitDto? unit = dto.unitId != null ? unitsById[dto.unitId] : null;
      return _packageFromDto(dto, unit: unit ?? dto.unit);
    }).toList();
    list.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    return list;
  }

  /// Refaz a chamada de `GET /packages`. Use após mutações HTTP
  /// (ex.: `POST /packages/receive`) para refletir o novo estado.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Identifica destinatário **localmente** (back ainda sem endpoint).
  void identify(
    String id, {
    required String recipientName,
    required String unit,
    String? actor,
  }) {
    state = state.whenData(
      (list) => _replace(
        list,
        id,
        (package) => package.copyWith(
          status: PackageStatus.awaitingPickup,
          recipientName: recipientName,
          unit: unit,
          events: [
            ...package.events,
            PackageEvent(
              type: PackageEventType.identified,
              timestamp: DateTime.now(),
              actor: actor,
            ),
          ],
        ),
      ),
    );
  }

  /// Marca como entregue **localmente** (back ainda sem endpoint).
  void deliver(String id, {required String pickedUpBy, String? note}) {
    state = state.whenData(
      (list) => _replace(
        list,
        id,
        (package) => package.copyWith(
          status: PackageStatus.delivered,
          deliveredAt: DateTime.now(),
          pickedUpBy: pickedUpBy,
          events: [
            ...package.events,
            PackageEvent(
              type: PackageEventType.delivered,
              timestamp: DateTime.now(),
              actor: pickedUpBy,
              note: note,
            ),
          ],
        ),
      ),
    );
  }

  /// Marca como devolvido **localmente** (back ainda sem endpoint).
  void markReturned(String id, {String? reason, String? actor}) {
    state = state.whenData(
      (list) => _replace(
        list,
        id,
        (package) => package.copyWith(
          status: PackageStatus.returned,
          deliveredAt: DateTime.now(),
          notes: reason == null || reason.isEmpty ? package.notes : reason,
          events: [
            ...package.events,
            PackageEvent(
              type: PackageEventType.returned,
              timestamp: DateTime.now(),
              actor: actor,
              note: reason == null || reason.isEmpty ? null : reason,
            ),
          ],
        ),
      ),
    );
  }

  List<Package> _replace(
    List<Package> list,
    String id,
    Package Function(Package) change,
  ) {
    return [
      for (final package in list)
        if (package.id == id) change(package) else package,
    ];
  }
}

Package _packageFromDto(PackageDto dto, {UnitDto? unit}) {
  return Package(
    id: dto.id,
    trackingCode: dto.trackingCode,
    carrier: Carrier.other,
    status: _mapStatus(dto.status),
    receivedAt: dto.receivedAt,
    receivedBy: dto.receivedBy ?? '',
    events: const <PackageEvent>[],
    unit: unit?.displayName,
    deliveredAt: dto.deliveredAt,
    pickedUpBy: dto.deliveredBy,
    notes: dto.description,
  );
}

PackageStatus _mapStatus(String raw) {
  final s = raw.toLowerCase();
  if (s.contains('deliver')) return PackageStatus.delivered;
  if (s.contains('return')) return PackageStatus.returned;
  if (s.contains('cancel')) return PackageStatus.canceled;
  if (s.contains('pending') && s.contains('ident')) {
    return PackageStatus.pendingIdentification;
  }
  return PackageStatus.awaitingPickup;
}

/// Resumo do dia derivado da lista de pacotes carregada.
///
/// Durante loading/erro do `packagesProvider`, devolve contadores zerados.
final Provider<DailySummary> dailySummaryProvider = Provider<DailySummary>(
  (ref) {
    final List<Package> packages =
        ref.watch(packagesProvider).asData?.value ?? const <Package>[];
    final now = DateTime.now();

    bool isToday(DateTime date) =>
        date.year == now.year && date.month == now.month && date.day == now.day;

    return DailySummary(
      receivedToday: packages.where((p) => isToday(p.receivedAt)).length,
      awaitingPickup: packages
          .where((p) => p.status == PackageStatus.awaitingPickup)
          .length,
      deliveredToday: packages
          .where((p) => p.deliveredAt != null && isToday(p.deliveredAt!))
          .length,
    );
  },
);

/// Pacote por id, ou `null` se não encontrado / lista ainda não carregada.
final packageByIdProvider = Provider.family<Package?, String>((ref, id) {
  final list = ref.watch(packagesProvider).asData?.value ?? const <Package>[];
  for (final package in list) {
    if (package.id == id) return package;
  }
  return null;
});

/// Os pacotes mais recentes, para a lista compacta da Home.
final Provider<List<Package>> recentPackagesProvider =
    Provider<List<Package>>((ref) {
      final list =
          ref.watch(packagesProvider).asData?.value ?? const <Package>[];
      // Já vem ordenada desc por receivedAt no `build()`.
      return list.take(5).toList();
    });
