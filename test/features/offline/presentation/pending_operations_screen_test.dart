import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logifree_mobile/core/offline/pending_operation.dart';
import 'package:logifree_mobile/core/offline/sync_service.dart';
import 'package:logifree_mobile/core/storage/migrations.dart';
import 'package:logifree_mobile/core/storage/offline_queue.dart';
import 'package:logifree_mobile/features/offline/presentation/pending_operations_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../test_helpers/test_helpers.dart';

PendingOperation _buildOp(
  String id, {
  String method = 'POST',
  String url = '/api/v1/packages',
  int attempts = 0,
  PendingOperationStatus status = PendingOperationStatus.pending,
  String? lastError,
}) {
  return PendingOperation(
    id: id,
    method: method,
    url: url,
    headers: const <String, Object?>{},
    body: const <String, Object?>{'tracking': 'AA1234'},
    idempotencyKey: 'idem-$id',
    createdAt: DateTime.utc(2026, 5, 23, 12),
    attempts: attempts,
    status: status,
    lastError: lastError,
  );
}

/// Constrói um `ProviderScope` com o [syncQueueStateProvider] forçado
/// para o [state] desejado. Evita instanciar um [SyncService] real —
/// que dispararia drenagem + HTTP — e mantém o teste focado em UI.
Widget _harness(SyncQueueState state, {OfflineQueue? queue}) {
  return ProviderScope(
    overrides: [
      syncQueueStateProvider.overrideWith((Ref ref) => Stream.value(state)),
      if (queue != null) offlineQueueProvider.overrideWith((Ref ref) async => queue),
    ],
    child: const MaterialApp(home: PendingOperationsScreen()),
  );
}

void main() {
  setUpAll(() {
    ensureTestBinding();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('empty state quando não há operações', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        const SyncQueueState(
          operations: <PendingOperation>[],
          isSyncing: false,
          isOnline: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Operações pendentes'), findsOneWidget);
    expect(find.text('Tudo sincronizado.'), findsOneWidget);
    expect(find.text('Nenhuma operação pendente.'), findsOneWidget);
  });

  testWidgets('lista renderiza item pendente com botões de ação', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        SyncQueueState(
          operations: <PendingOperation>[_buildOp('op-1')],
          isSyncing: false,
          isOnline: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recebimento de pacote'), findsOneWidget);
    expect(find.text('Pendente'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.text('Descartar'), findsOneWidget);
    expect(find.text('Tentativas: 0'), findsOneWidget);
  });

  testWidgets('item com status failed mostra chip "Falhou" e último erro', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        SyncQueueState(
          operations: <PendingOperation>[
            _buildOp(
              'op-fail',
              url: '/api/v1/packages/abc/deliver',
              attempts: 5,
              status: PendingOperationStatus.failed,
              lastError: 'HTTP 500 (badResponse)',
            ),
          ],
          isSyncing: false,
          isOnline: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Entrega de pacote'), findsOneWidget);
    expect(find.text('Falhou'), findsOneWidget);
    expect(find.text('Tentativas: 5'), findsOneWidget);
    expect(find.textContaining('Último erro'), findsOneWidget);
  });

  testWidgets('botão Descartar abre dialog de confirmação', (
    WidgetTester tester,
  ) async {
    // Aqui usamos uma queue real (em memória) para validar que
    // `delete(id)` é de fato invocada.
    final Database db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: kSchemaVersion,
        onCreate: (Database db, int version) async {
          await runInitialMigrations(db);
        },
      ),
    );
    final OfflineQueue queue = OfflineQueue(db);
    addTearDown(queue.close);
    await queue.enqueue(_buildOp('op-discard'));

    await tester.pumpWidget(
      _harness(
        SyncQueueState(
          operations: <PendingOperation>[_buildOp('op-discard')],
          isSyncing: false,
          isOnline: false,
        ),
        queue: queue,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();

    expect(find.text('Descartar operação?'), findsOneWidget);

    // Confirma — usa o FilledButton do dialog.
    await tester.tap(find.widgetWithText(FilledButton, 'Descartar'));
    await tester.pumpAndSettle();

    // O dialog fechou.
    expect(find.text('Descartar operação?'), findsNothing);
    // E a operação foi removida da fila real.
    expect(await queue.listAll(), isEmpty);
  });
}
