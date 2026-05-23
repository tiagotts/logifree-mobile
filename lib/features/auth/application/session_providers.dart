import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/doorman.dart';
import 'auth_controller.dart';
import 'auth_state.dart';

/// Porteiro logado no momento.
///
/// Quando há sessão real (`Authenticated`), monta um `Doorman` a partir do
/// `UserDto` + primeira `MembershipDto`. Senão (login fake / sessão ainda
/// não hidratada), cai no `demoDoorman` fixo para o protótipo continuar
/// usável.
final Provider<Doorman> currentDoormanProvider = Provider<Doorman>((ref) {
  final state = ref.watch(authStateProvider);
  if (state is Authenticated) {
    final memberships = state.user.memberships;
    final condominium = memberships.isNotEmpty
        ? memberships.first.condominiumName
        : '—';
    return Doorman(
      name: state.user.name,
      email: state.user.email,
      condominium: condominium,
    );
  }
  return demoDoorman;
});
