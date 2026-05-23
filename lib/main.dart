import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/api/dio_client.dart';
import 'core/api/interceptors/offline_fallback_interceptor.dart';
import 'core/offline/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Necessário para formatar datas em pt-BR (DateFormat com locale).
  await initializeDateFormatting('pt_BR');

  final ProviderContainer container = ProviderContainer();

  // Warm-up do SyncService: abre o banco, plugga o
  // OfflineFallbackInterceptor no Dio e começa a ouvir conectividade.
  // Roda em background — não bloqueia o `runApp` pra UI subir rápido.
  unawaited(_bootstrapOfflineSync(container));

  runApp(
    UncontrolledProviderScope(container: container, child: const LogiFreeApp()),
  );
}

Future<void> _bootstrapOfflineSync(ProviderContainer container) async {
  try {
    final OfflineFallbackInterceptor interceptor = await container.read(
      offlineFallbackInterceptorProvider.future,
    );
    attachOfflineFallback(container.read(dioClientProvider), interceptor);

    final SyncService sync = await container.read(syncServiceProvider.future);
    await sync.start();
  } on Object catch (e, st) {
    // Falha no boot do offline não deve derrubar o app — logamos e
    // seguimos. Os requests vão direto pra rede sem fallback até o
    // problema ser diagnosticado.
    developer.log(
      'offline sync bootstrap failed: $e',
      name: 'logifree.boot',
      error: e,
      stackTrace: st,
    );
  }
}

/// Helper local pro `unawaited` evitar o lint `discarded_futures` sem
/// importar `package:flutter/foundation.dart` só pra isso.
void unawaited(Future<void> future) {
  future.ignore();
}
