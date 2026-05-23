import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logifree_mobile/core/offline/sync_service.dart';
import 'package:logifree_mobile/features/offline/presentation/pending_operations_screen.dart';
import 'package:logifree_mobile/shared/widgets/connectivity_banner.dart';

/// Helper que envolve o banner em um `MaterialApp` mínimo + override
/// do [syncQueueStateProvider] para devolver um stream controlado.
Widget _harness({
  required Stream<SyncQueueState> stream,
  SyncQueueState? initial,
  Duration reconnectedFlashDuration = const Duration(seconds: 4),
}) {
  return ProviderScope(
    overrides: [
      syncQueueStateProvider.overrideWith((Ref ref) {
        if (initial != null) {
          // Funde o initial com o stream — espelha o comportamento do
          // provider real (yield + yield*).
          return _prefix<SyncQueueState>(initial, stream);
        }
        return stream;
      }),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ConnectivityBanner(
              reconnectedFlashDuration: reconnectedFlashDuration,
            ),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ),
    ),
  );
}

Stream<T> _prefix<T>(T first, Stream<T> rest) async* {
  yield first;
  yield* rest;
}

void main() {
  testWidgets('exibe banner offline quando estado isOnline=false', (
    WidgetTester tester,
  ) async {
    final StreamController<SyncQueueState> ctrl =
        StreamController<SyncQueueState>.broadcast();
    addTearDown(ctrl.close);

    await tester.pumpWidget(
      _harness(
        stream: ctrl.stream,
        initial: const SyncQueueState(
          operations: [],
          isSyncing: false,
          isOnline: false,
        ),
      ),
    );
    // Resolve o stream.
    await tester.pumpAndSettle();

    expect(
      find.text('Você está offline. Operações ficarão pendentes.'),
      findsOneWidget,
    );
  });

  testWidgets('não mostra banner quando online estável', (
    WidgetTester tester,
  ) async {
    final StreamController<SyncQueueState> ctrl =
        StreamController<SyncQueueState>.broadcast();
    addTearDown(ctrl.close);

    await tester.pumpWidget(
      _harness(
        stream: ctrl.stream,
        initial: const SyncQueueState(
          operations: [],
          isSyncing: false,
          isOnline: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Você está offline. Operações ficarão pendentes.'),
      findsNothing,
    );
    expect(find.text('Voltou online. Sincronizando...'), findsNothing);
  });

  testWidgets('exibe flash "Voltou online" na transição offline→online', (
    WidgetTester tester,
  ) async {
    final StreamController<SyncQueueState> ctrl =
        StreamController<SyncQueueState>.broadcast();
    addTearDown(ctrl.close);

    await tester.pumpWidget(
      _harness(
        stream: ctrl.stream,
        initial: const SyncQueueState(
          operations: [],
          isSyncing: false,
          isOnline: false,
        ),
        reconnectedFlashDuration: const Duration(seconds: 2),
      ),
    );
    await tester.pumpAndSettle();

    // Confirma estado offline inicial.
    expect(
      find.text('Você está offline. Operações ficarão pendentes.'),
      findsOneWidget,
    );

    // Emite transição para online.
    ctrl.add(
      const SyncQueueState(operations: [], isSyncing: true, isOnline: true),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Voltou online. Sincronizando...'), findsOneWidget);
    expect(
      find.text('Você está offline. Operações ficarão pendentes.'),
      findsNothing,
    );

    // Passa a duração do flash — o banner deve sumir.
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Voltou online. Sincronizando...'), findsNothing);
  });
}
