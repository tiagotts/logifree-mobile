import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dto/unit_dto.dart';
import '../data/unit_repository.dart';

/// Lista de unidades do condomínio atual, vinda do back via
/// `GET /api/v1/units`.
///
/// A lista raramente muda durante uma sessão do porteiro, então um
/// `FutureProvider` (cache vitalício) é suficiente. Quando precisar
/// recarregar (ex.: troca de condomínio), basta `ref.invalidate`.
final FutureProvider<List<UnitDto>> unitsProvider =
    FutureProvider<List<UnitDto>>((ref) async {
  return ref.read(unitRepositoryProvider).list();
});
