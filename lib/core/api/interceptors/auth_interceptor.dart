import 'dart:async';

import 'package:dio/dio.dart';

import '../../storage/secure_storage.dart';
import '../../storage/secure_storage_keys.dart';

/// Interceptor que anexa `Authorization: Bearer <accessToken>` em todo
/// request, exceto endpoints públicos de auth (sign-in, refresh, etc.).
///
/// Esta é a versão mínima do CARD-MOBILE-008: só **anexa** o token. O
/// refresh transparente em 401 e o tratamento de fila de requests
/// concorrentes durante refresh ficam para uma próxima etapa.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);

  final SecureStorage _storage;

  /// Endpoints onde o token NÃO deve ser anexado.
  ///
  /// Marcam-se por prefixo do path para evitar match acidental.
  static const List<String> _publicPaths = <String>[
    '/auth/mobile/sign-in',
    '/auth/refresh',
    '/auth/forgot-password',
    '/auth/reset-password',
  ];

  bool _isPublic(String path) {
    for (final p in _publicPaths) {
      if (path.contains(p)) return true;
    }
    return false;
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isPublic(options.path)) {
      handler.next(options);
      return;
    }
    final token = await _storage.read(SecureStorageKeys.accessToken);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
