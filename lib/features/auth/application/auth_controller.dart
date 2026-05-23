import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/storage/secure_storage_keys.dart';
import '../data/auth_repository.dart';
import '../data/dto/user_dto.dart';
import 'auth_state.dart';

/// Estado central da autenticação.
///
/// Fluxo geral:
/// 1. App sobe → `hydrate()` checa o secure storage e decide se já há
///    sessão ativa para mandar direto pra Home, ou se vai pro Login.
/// 2. Login chama `signIn(email, password)`.
/// 3. Logout chama `signOut()`.
final NotifierProvider<AuthController, AuthState> authStateProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const Unauthenticated();

  /// Tenta restaurar uma sessão salva no secure storage. Chamado pelo
  /// splash. Não faz chamada HTTP — confia no token salvo. Se ele
  /// estiver expirado, o `AuthInterceptor` (CARD-008) cuida do refresh
  /// no primeiro request autenticado.
  Future<void> hydrate() async {
    final storage = ref.read(secureStorageProvider);
    try {
      final accessToken = await storage.read(SecureStorageKeys.accessToken);
      final refreshToken = await storage.read(SecureStorageKeys.refreshToken);
      final userJson = await storage.read(SecureStorageKeys.userSnapshot);

      if (accessToken == null || refreshToken == null || userJson == null) {
        state = const Unauthenticated();
        return;
      }

      final user = UserDto.fromJson(
        jsonDecode(userJson) as Map<String, dynamic>,
      );
      state = Authenticated(
        user: user,
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    } on Object catch (e, st) {
      developer.log(
        'Falha ao hidratar sessão; voltando para Unauthenticated.',
        name: 'logifree.auth',
        error: e,
        stackTrace: st,
      );
      state = const Unauthenticated();
    }
  }

  /// Autentica com e-mail e senha. Trata o caso especial de MFA exigida.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const Authenticating();
    final repo = ref.read(authRepositoryProvider);
    final storage = ref.read(secureStorageProvider);

    try {
      final response = await repo.signIn(email: email, password: password);
      await storage.write(
        SecureStorageKeys.accessToken,
        response.accessToken,
      );
      await storage.write(
        SecureStorageKeys.refreshToken,
        response.refreshToken,
      );
      await storage.write(SecureStorageKeys.userId, response.user.id);
      await storage.write(
        SecureStorageKeys.userSnapshot,
        jsonEncode(response.user.toJson()),
      );

      state = Authenticated(
        user: response.user,
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
      );
    } on DioException catch (e, st) {
      developer.log(
        'signIn falhou com DioException',
        name: 'logifree.auth',
        error:
            'type=${e.type} status=${e.response?.statusCode} '
            'message=${e.message} responseBody=${e.response?.data} '
            'innerError=${e.error}',
        stackTrace: st,
      );
      final error = e.error;
      if (error is AppError && error.code == 'MFA_REQUIRED') {
        state = const MfaRequired();
        return;
      }
      state = AuthFailure(
        error is AppError ? error : _unknownError(e),
      );
    } on Object catch (e, st) {
      developer.log(
        'signIn falhou com exception inesperada',
        name: 'logifree.auth',
        error: '$e (${e.runtimeType})',
        stackTrace: st,
      );
      state = const AuthFailure(
        AppError(
          code: 'UNKNOWN',
          userMessage: 'Não foi possível completar o login. Tente novamente.',
        ),
      );
    }
  }

  /// Encerra a sessão: tenta avisar o back e sempre limpa o storage local.
  Future<void> signOut() async {
    final repo = ref.read(authRepositoryProvider);
    final storage = ref.read(secureStorageProvider);

    await repo.signOut();
    await storage.delete(SecureStorageKeys.accessToken);
    await storage.delete(SecureStorageKeys.refreshToken);
    await storage.delete(SecureStorageKeys.userId);
    await storage.delete(SecureStorageKeys.userSnapshot);

    state = const Unauthenticated();
  }

  AppError _unknownError(DioException e) {
    return AppError(
      code: 'UNKNOWN',
      userMessage: 'Não foi possível completar o login. Tente novamente.',
      requestId: e.response?.headers.value('x-request-id'),
    );
  }
}
