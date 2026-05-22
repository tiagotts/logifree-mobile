import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_packages.dart';
import '../domain/daily_summary.dart';
import '../domain/package.dart';
import '../domain/package_event.dart';
import '../domain/package_status.dart';

/// Estado central dos pacotes do protótipo, em memória.
///
/// Quando o backend entrar, este Notifier passa a delegar para um
/// `PackageRepository` HTTP — as telas que dependem dele não mudam.
final packagesProvider = NotifierProvider<PackagesNotifier, List<Package>>(
  PackagesNotifier.new,
);

class PackagesNotifier extends Notifier<List<Package>> {
  @override
  List<Package> build() => seedPackages();

  /// Registra um novo pacote (vindo da tela de confirmar recebimento).
  void register(Package package) {
    state = [package, ...state];
  }

  /// Marca um pacote como entregue ao morador.
  void deliver(String id, {required String pickedUpBy, String? note}) {
    _update(
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
    );
  }

  void _update(String id, Package Function(Package) change) {
    state = [
      for (final package in state)
        if (package.id == id) change(package) else package,
    ];
  }
}

/// Resumo do dia derivado da lista de pacotes.
final dailySummaryProvider = Provider<DailySummary>((ref) {
  final packages = ref.watch(packagesProvider);
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
});

/// Pacote por id, ou `null` se não encontrado.
final packageByIdProvider = Provider.family<Package?, String>((ref, id) {
  for (final package in ref.watch(packagesProvider)) {
    if (package.id == id) return package;
  }
  return null;
});

/// Os pacotes mais recentes, para a lista compacta da Home.
final recentPackagesProvider = Provider<List<Package>>((ref) {
  final packages = [...ref.watch(packagesProvider)]
    ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
  return packages.take(5).toList();
});
