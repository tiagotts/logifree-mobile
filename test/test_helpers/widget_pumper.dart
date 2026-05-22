/// Helpers para pumpar widgets em testes.
///
/// Embrulha o widget alvo em um `MaterialApp` minimal — evita repetir
/// boilerplate em todo `testWidgets`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumpa um widget dentro de um `MaterialApp` mínimo + ajusta tamanho de tela
/// para um valor previsível (iPhone-ish).
///
/// Exemplo:
/// ```dart
/// await pumpAppWidget(tester, const ScanScreen());
/// expect(find.text('Escanear'), findsOneWidget);
/// ```
Future<void> pumpAppWidget(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
  NavigatorObserver? navigatorObserver,
  Locale locale = const Locale('pt', 'BR'),
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    MaterialApp(
      title: 'LogiFree Test',
      debugShowCheckedModeBanner: false,
      theme: theme ?? ThemeData(useMaterial3: true),
      locale: locale,
      home: child,
      navigatorObservers:
          navigatorObserver != null ? [navigatorObserver] : const [],
    ),
  );
  await tester.pumpAndSettle();
}

/// Espera animações finalizarem com timeout padrão.
/// Use quando `pumpAndSettle()` puro pode travar por animação infinita.
Future<void> settle(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, timeout);
}
