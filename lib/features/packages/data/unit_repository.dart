import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_client.dart';
import 'dto/unit_dto.dart';

/// Chamadas HTTP relacionadas a unidades do condomínio.
class UnitRepository {
  UnitRepository(this._dio);

  final Dio _dio;

  /// `GET /api/v1/units` — lista todas as unidades do condomínio atual.
  Future<List<UnitDto>> list() async {
    final response = await _dio.get<List<dynamic>>('/units');
    final items = response.data ?? <dynamic>[];
    return items
        .map((item) => UnitDto.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) {
        // Ordena por bloco e depois por número (numérico quando der).
        final byBlock = (a.block ?? '').compareTo(b.block ?? '');
        if (byBlock != 0) return byBlock;
        final na = int.tryParse(a.number);
        final nb = int.tryParse(b.number);
        if (na != null && nb != null) return na.compareTo(nb);
        return a.number.compareTo(b.number);
      });
  }
}

final Provider<UnitRepository> unitRepositoryProvider =
    Provider<UnitRepository>(
      (ref) => UnitRepository(ref.watch(dioClientProvider)),
    );
