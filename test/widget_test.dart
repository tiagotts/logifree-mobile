/// Smoke test: o app sobe no splash e navega para o login.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logifree_mobile/app.dart';

void main() {
  testWidgets('app sobe no splash e segue para o login', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LogiFreeApp()));

    // Tela de abertura visível.
    expect(find.text('LogiFree'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // O timer do splash dispara e leva ao login.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Entrar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
