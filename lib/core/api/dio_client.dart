import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../config/env.dart';
import '../storage/secure_storage.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/offline_fallback_interceptor.dart';
import 'interceptors/retry_interceptor.dart';

/// Hook opcional pra fornecer o slug de tenant atual.
///
/// Quando o módulo de auth/tenant estiver no ar, esta função será
/// substituída por algo que lê o slug do estado global (ex.: provider
/// Riverpod). Enquanto isso, retorna `null` e o header não é anexado.
typedef CondominiumSlugProvider = String? Function();

/// Cria e configura uma instância do [Dio] pronta pra consumir a
/// API LogiFree.
///
/// Comportamento:
/// - Base URL vinda de [Env.apiBaseUrl].
/// - Timeouts: `connect` 10s / `receive` 15s.
/// - Header `X-Condominium-Slug` injetado dinamicamente via
///   [slugProvider] — quando este retorna `null`, o header é
///   omitido. Isso é só um hook; o sistema completo de tenant
///   entra em outro card.
/// - Interceptors na ordem: logging → retry → error.
///   - Logging primeiro pra registrar tudo, inclusive a request
///     original antes de qualquer retry.
///   - Retry no meio pra reexecutar antes do error mapping decidir
///     o `AppError` final.
///   - Error por último pra mapear o erro definitivo (depois das
///     tentativas) para [AppError].
Dio createDioClient({
  CondominiumSlugProvider? slugProvider,
  String? baseUrl,
  OfflineFallbackInterceptor? offlineFallback,
  AuthInterceptor? authInterceptor,
}) {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: baseUrl ?? Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  if (slugProvider != null) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          final String? slug = slugProvider();
          if (slug != null && slug.isNotEmpty) {
            options.headers['X-Condominium-Slug'] = slug;
          }
          handler.next(options);
        },
      ),
    );
  }

  if (authInterceptor != null) {
    dio.interceptors.add(authInterceptor);
  }

  // Ordem propositadamente: o OfflineFallback vai **antes** do retry
  // e do error mapper, pra capturar a falha de rede primeiro e
  // "resolver" a request com 202 sintético, evitando que o erro
  // chegue ao chamador. Logging fica no topo pra registrar tudo.
  dio.interceptors.add(LoggingInterceptor());
  if (offlineFallback != null) {
    dio.interceptors.add(offlineFallback);
  }
  dio.interceptors.add(RetryInterceptor(dio));
  dio.interceptors.add(const ErrorInterceptor());

  return dio;
}

/// Plugga o [OfflineFallbackInterceptor] em uma instância já criada
/// de [Dio].
///
/// Útil quando o cliente Dio é criado sincronamente (no `dioClientProvider`)
/// mas o `OfflineQueue` depende de I/O assíncrono. O `main.dart` chama
/// esta função após o warm-up do SyncService.
///
/// Inserido na posição correta (logo após o LoggingInterceptor, antes do
/// RetryInterceptor) — se Logging não estiver presente, insere no índice 0.
void attachOfflineFallback(Dio dio, OfflineFallbackInterceptor interceptor) {
  // Garante que não plugamos duas vezes.
  for (final Interceptor existing in dio.interceptors) {
    if (existing is OfflineFallbackInterceptor) {
      return;
    }
  }
  final int loggingIdx = dio.interceptors.indexWhere(
    (Interceptor i) => i is LoggingInterceptor,
  );
  final int insertAt = loggingIdx >= 0 ? loggingIdx + 1 : 0;
  dio.interceptors.insert(insertAt, interceptor);
}

/// Provider Riverpod do cliente Dio compartilhado pelo app.
///
/// Decisão registrada no backlog: o projeto **não usa codegen**
/// (sem `riverpod_generator`). Provider declarado manualmente.
///
/// Conecta o `slugProvider` ao estado de auth — o `X-Condominium-Slug`
/// é injetado dinamicamente a partir da primeira membership do usuário
/// logado. Quando o seletor de condomínio (CARD-010) entrar, este hook
/// passa a ler do `tenantControllerProvider`.
///
/// O `AuthInterceptor` lê o token diretamente do `SecureStorage` em
/// cada request — não precisa reagir a mudanças do `authStateProvider`
/// (sign-in/out já reescrevem o storage).
final Provider<Dio> dioClientProvider = Provider<Dio>((Ref ref) {
  final SecureStorage storage = ref.read(secureStorageProvider);
  return createDioClient(
    slugProvider: () {
      final AuthState state = ref.read(authStateProvider);
      if (state is! Authenticated || state.user.memberships.isEmpty) {
        return null;
      }
      // TODO(CARD-010): substituir por seleção real do usuário.
      // Por enquanto preferimos `jales-machado` (condomínio onde o time
      // configurou os mocks de teste) e caímos na primeira membership
      // como fallback.
      const String preferredSlug = 'jales-machado';
      for (final m in state.user.memberships) {
        if (m.condominiumSlug == preferredSlug) return m.condominiumSlug;
      }
      return state.user.memberships.first.condominiumSlug;
    },
    authInterceptor: AuthInterceptor(storage),
  );
});
