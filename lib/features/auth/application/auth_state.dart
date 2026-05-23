import '../../../core/api/api_error.dart';
import '../data/dto/user_dto.dart';

/// Estados possíveis da sessão de autenticação.
sealed class AuthState {
  const AuthState();
}

/// Estado inicial: nenhum token salvo, ninguém logado.
class Unauthenticated extends AuthState {
  const Unauthenticated();
}

/// Em meio a uma chamada de sign-in.
class Authenticating extends AuthState {
  const Authenticating();
}

/// Sessão ativa: tokens e usuário disponíveis.
class Authenticated extends AuthState {
  const Authenticated({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  final UserDto user;
  final String accessToken;
  final String refreshToken;
}

/// Backend pediu segundo fator. Para o protótipo, o porteiro ainda não tem
/// fluxo de MFA — esta classe existe para a tela de login mostrar
/// mensagem clara ("Verificação em duas etapas necessária").
class MfaRequired extends AuthState {
  const MfaRequired();
}

/// Falha na autenticação. `error.userMessage` está em pt-BR e é pronta
/// para mostrar na UI.
class AuthFailure extends AuthState {
  const AuthFailure(this.error);

  final AppError error;
}
