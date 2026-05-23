import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_client.dart';
import 'dto/refresh_response.dart';
import 'dto/sign_in_request.dart';
import 'dto/sign_in_response.dart';

/// Chamadas HTTP de autenticação.
///
/// Endpoints (ver `LogiFree_Fluxo_Autenticacao.md` no back-front):
/// - `POST /api/v1/auth/mobile/sign-in`
/// - `POST /api/v1/auth/refresh`
/// - `POST /api/v1/auth/sign-out`
///
/// Erros do back já chegam mapeados em `AppError` pelo `ErrorInterceptor`
/// (anexado em `DioException.error`).
class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<SignInResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/mobile/sign-in',
      data: SignInRequest(email: email, password: password).toJson(),
    );
    return SignInResponse.fromJson(response.data!);
  }

  Future<RefreshResponse> refresh(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: <String, dynamic>{'refreshToken': refreshToken},
    );
    return RefreshResponse.fromJson(response.data!);
  }

  /// Encerra a sessão no back. Tolera falhas — o cliente já vai limpar o
  /// secure storage de qualquer jeito.
  Future<void> signOut() async {
    try {
      await _dio.post<void>('/auth/sign-out');
    } on DioException {
      // intencional: logout local sempre acontece mesmo se o back falhar.
    }
  }
}

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>(
      (ref) => AuthRepository(ref.watch(dioClientProvider)),
    );
