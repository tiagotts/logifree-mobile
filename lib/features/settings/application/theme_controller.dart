import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modo de tema escolhido pelo usuário (claro / escuro / automático).
///
/// No protótipo o valor é volátil — não é persistido entre sessões. Quando
/// o `flutter_secure_storage` for usado para preferências (ou entrar
/// `shared_preferences`), a persistência ganha um lugar para morar.
final NotifierProvider<ThemeModeNotifier, ThemeMode> themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void setMode(ThemeMode mode) {
    state = mode;
  }
}
