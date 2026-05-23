import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/auth_controller.dart';
import '../application/auth_state.dart';

/// Tela de abertura. Hidrata a sessão salva e decide se vai para a Home
/// ou para o Login.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  /// Tempo mínimo de exibição do splash, para não "piscar" se a hidratação
  /// for muito rápida.
  static const Duration _minimumDelay = Duration(milliseconds: 700);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final controller = ref.read(authStateProvider.notifier);
    await Future.wait<void>([
      controller.hydrate(),
      Future<void>.delayed(_minimumDelay),
    ]);
    if (!mounted) return;
    final state = ref.read(authStateProvider);
    context.go(state is Authenticated ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: colors.onPrimary,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                Icons.local_shipping_outlined,
                size: 52,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'LogiFree',
              style: TextStyle(
                color: colors.onPrimary,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Gestão de encomendas',
              style: TextStyle(
                color: colors.onPrimary.withValues(alpha: 0.8),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: colors.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
