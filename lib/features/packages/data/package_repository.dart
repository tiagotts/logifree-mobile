import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_client.dart';
import 'dto/package_dto.dart';
import 'dto/receive_package_request.dart';

/// Chamadas HTTP relacionadas a pacotes.
class PackageRepository {
  PackageRepository(this._dio);

  final Dio _dio;

  /// `POST /api/v1/packages/receive` — registra um pacote recebido na
  /// portaria e dispara a notificação ao morador.
  Future<void> receive(ReceivePackageRequest request) async {
    await _dio.post<Map<String, dynamic>>(
      '/packages/receive',
      data: request.toJson(),
    );
  }

  /// `GET /api/v1/packages` — lista todos os pacotes do condomínio atual.
  ///
  /// Aceita resposta como **array direto** ou envelopada em
  /// `{ items: [...] }` — o que o back devolver hoje.
  Future<List<PackageDto>> list() async {
    final response = await _dio.get<dynamic>('/packages');
    final data = response.data;
    final List<dynamic> rawList;
    if (data is List) {
      rawList = data;
    } else if (data is Map<String, dynamic> && data['items'] is List) {
      rawList = data['items'] as List<dynamic>;
    } else {
      rawList = const <dynamic>[];
    }
    return rawList
        .map((item) => PackageDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

final Provider<PackageRepository> packageRepositoryProvider =
    Provider<PackageRepository>(
      (ref) => PackageRepository(ref.watch(dioClientProvider)),
    );
