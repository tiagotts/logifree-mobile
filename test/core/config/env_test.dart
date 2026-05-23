import 'package:flutter_test/flutter_test.dart';
import 'package:logifree_mobile/core/config/env.dart';

void main() {
  group('Env', () {
    // Testes assumem execução de `flutter test` SEM `--dart-define` —
    // portanto os defaults compilados devem estar ativos.

    test('apiBaseUrl usa default quando --dart-define não passado', () {
      expect(Env.apiBaseUrl, 'http://localhost:3000/api/v1');
    });

    test('sentryDsn é string vazia quando não configurado', () {
      expect(Env.sentryDsn, isEmpty);
    });

    test('environment usa default development', () {
      expect(Env.environment, 'development');
    });

    test('isDevelopment é true com defaults', () {
      expect(Env.isDevelopment, isTrue);
    });

    test('isProduction é false com defaults', () {
      expect(Env.isProduction, isFalse);
    });

    test('hasSentry é false quando DSN vazio', () {
      expect(Env.hasSentry, isFalse);
    });
  });
}
