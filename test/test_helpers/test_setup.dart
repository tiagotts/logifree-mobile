/// Setup global para testes.
///
/// Chame `ensureTestBinding()` no `setUpAll` quando o teste depende de
/// plugins nativos ou shared preferences/secure storage mockados.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Inicializa o binding do Flutter para testes que usam plugins nativos.
///
/// `TestWidgetsFlutterBinding.ensureInitialized()` é chamado por
/// `testWidgets` automaticamente; use este helper em testes plain `test()`.
void ensureTestBinding() {
  TestWidgetsFlutterBinding.ensureInitialized();
}

/// Substitui handler de um method channel — útil para mockar plugins nativos
/// (camera, ml_kit, secure_storage etc.) sem precisar do device.
///
/// Exemplo:
/// ```dart
/// stubMethodChannel('plugins.flutter.io/path_provider', (call) async {
///   if (call.method == 'getApplicationDocumentsDirectory') {
///     return '/tmp/test-docs';
///   }
///   return null;
/// });
/// ```
void stubMethodChannel(
  String channelName,
  Future<Object?>? Function(MethodCall call) handler,
) {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(MethodChannel(channelName), handler);
}
