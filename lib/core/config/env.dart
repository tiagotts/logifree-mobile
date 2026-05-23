/// Configurações de ambiente lidas via `--dart-define` em tempo de compilação.
///
/// Uso em produção:
/// ```bash
/// flutter run \
///   --dart-define=API_BASE_URL=https://api.logifree.com.br/api/v1 \
///   --dart-define=SENTRY_DSN=https://... \
///   --dart-define=ENVIRONMENT=production
/// ```
///
/// Em **desenvolvimento**, se você não passar `--dart-define=API_BASE_URL`,
/// o app usa [_developmentBaseUrl] como default. Ajuste aquela constante
/// conforme o cenário em que está testando — veja a documentação dela.
///
/// Todos os campos `const` são resolvidos em build time, sem custo em runtime.
class Env {
  const Env._();

  /// URL do backend local para uso em desenvolvimento.
  ///
  /// O backend escuta na porta **3333**. Use o valor correto conforme o
  /// destino do `flutter run`:
  /// - **iOS Simulator** → `http://localhost:3333/api/v1`
  ///   (o simulador compartilha o loopback do Mac).
  /// - **Android Emulator** → `http://10.0.2.2:3333/api/v1`
  ///   (`10.0.2.2` é o alias que o emulador usa para acessar o host).
  /// - **Celular Android físico** (mesma rede WiFi do Mac) →
  ///   `http://192.168.15.8:3333/api/v1` (IP da máquina na rede local).
  ///   Se mudar de rede, descubra o IP novo com `ipconfig getifaddr en0`.
  ///
  /// Para sobrescrever sem editar este arquivo, passe
  /// `--dart-define=API_BASE_URL=...` no `flutter run`.
  static const String _developmentBaseUrl =
      'http://192.168.15.8:3333/api/v1';

  /// Base URL da API LogiFree.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _developmentBaseUrl,
  );

  /// DSN do Sentry. Vazio quando observabilidade não está configurada.
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

  /// Ambiente de execução: `development`, `staging` ou `production`.
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  /// `true` quando rodando em ambiente de desenvolvimento.
  static bool get isDevelopment => environment == 'development';

  /// `true` quando rodando em ambiente de produção.
  static bool get isProduction => environment == 'production';

  /// `true` quando há DSN do Sentry configurado.
  static bool get hasSentry => sentryDsn.isNotEmpty;
}
