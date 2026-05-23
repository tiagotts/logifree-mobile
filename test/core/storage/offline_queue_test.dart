import 'package:flutter_test/flutter_test.dart';
import 'package:logifree_mobile/core/offline/pending_operation.dart';
import 'package:logifree_mobile/core/storage/migrations.dart';
import 'package:logifree_mobile/core/storage/offline_queue.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    // Inicializa o backend FFI para testes em memória (sem device).
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late OfflineQueue queue;

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: kSchemaVersion,
        onCreate: (Database db, int version) async {
          await runInitialMigrations(db);
        },
      ),
    );
    queue = OfflineQueue(db);
  });

  tearDown(() async {
    await queue.close();
  });

  PendingOperation buildOp(
    String id, {
    int attempts = 0,
    PendingOperationStatus status = PendingOperationStatus.pending,
    DateTime? createdAt,
  }) {
    return PendingOperation(
      id: id,
      method: 'POST',
      url: '/api/v1/packages',
      headers: <String, Object?>{'X-Condominium-Slug': 'central'},
      body: <String, Object?>{'tracking': 'AA1234'},
      idempotencyKey: 'idem-$id',
      createdAt: createdAt ?? DateTime.utc(2026, 5, 23, 12),
      attempts: attempts,
      status: status,
    );
  }

  group('OfflineQueue — resetForRetry', () {
    test(
      'resetForRetry zera attempts, limpa last_error e volta a pending',
      () async {
        await queue.enqueue(buildOp('op-1', attempts: 4));
        await queue.markFailed('op-1', 'timeout');

        final PendingOperation before = (await queue.findById('op-1'))!;
        expect(before.status, PendingOperationStatus.failed);
        expect(before.attempts, 4);
        expect(before.lastError, 'timeout');

        await queue.resetForRetry('op-1');

        final PendingOperation after = (await queue.findById('op-1'))!;
        expect(after.status, PendingOperationStatus.pending);
        expect(after.attempts, 0);
        expect(after.lastError, isNull);
      },
    );

    test('resetForRetry em id inexistente é no-op', () async {
      await queue.resetForRetry('inexistente');
      expect(await queue.listAll(), isEmpty);
    });
  });

  group('OfflineQueue — CRUD', () {
    test('enqueue + listAll devolve a operação persistida', () async {
      final PendingOperation op = buildOp('op-1');
      await queue.enqueue(op);

      final List<PendingOperation> all = await queue.listAll();
      expect(all, hasLength(1));
      expect(all.single.id, 'op-1');
      expect(all.single.headers['X-Condominium-Slug'], 'central');
      expect((all.single.body! as Map<String, Object?>)['tracking'], 'AA1234');
    });

    test('listPending ordena por created_at ASC e exclui failed', () async {
      await queue.enqueue(
        buildOp('a', createdAt: DateTime.utc(2026, 5, 23, 10)),
      );
      await queue.enqueue(
        buildOp('b', createdAt: DateTime.utc(2026, 5, 23, 12)),
      );
      await queue.enqueue(
        buildOp(
          'c',
          createdAt: DateTime.utc(2026, 5, 23, 11),
          status: PendingOperationStatus.failed,
        ),
      );

      final List<PendingOperation> pending = await queue.listPending();
      expect(pending.map((PendingOperation o) => o.id), <String>['a', 'b']);
    });

    test('markSending muda status', () async {
      await queue.enqueue(buildOp('x'));
      await queue.markSending('x');
      final PendingOperation? fetched = await queue.findById('x');
      expect(fetched, isNotNull);
      expect(fetched!.status, PendingOperationStatus.sending);
    });

    test('markFailed grava status + last_error', () async {
      await queue.enqueue(buildOp('x'));
      await queue.markFailed('x', 'HTTP 500 (badResponse)');
      final PendingOperation? fetched = await queue.findById('x');
      expect(fetched!.status, PendingOperationStatus.failed);
      expect(fetched.lastError, 'HTTP 500 (badResponse)');
    });

    test('markDone remove a operação', () async {
      await queue.enqueue(buildOp('x'));
      await queue.markDone('x');
      expect(await queue.findById('x'), isNull);
      expect(await queue.listAll(), isEmpty);
    });

    test('delete remove a operação', () async {
      await queue.enqueue(buildOp('x'));
      await queue.delete('x');
      expect(await queue.findById('x'), isNull);
    });

    test('incrementAttempts soma 1 e volta status para pending', () async {
      await queue.enqueue(buildOp('x', status: PendingOperationStatus.sending));
      final int newCount = await queue.incrementAttempts(
        'x',
        lastError: 'boom',
      );
      expect(newCount, 1);
      final PendingOperation? fetched = await queue.findById('x');
      expect(fetched!.attempts, 1);
      expect(fetched.status, PendingOperationStatus.pending);
      expect(fetched.lastError, 'boom');
    });

    test('changes stream emite snapshot após mutação', () async {
      // Captura o próximo snapshot.
      final Future<List<PendingOperation>> nextSnapshot = queue.changes.first;
      await queue.enqueue(buildOp('op-1'));
      final List<PendingOperation> snapshot = await nextSnapshot;
      expect(snapshot.map((PendingOperation o) => o.id), <String>['op-1']);
    });

    test('enqueue com id duplicado substitui (REPLACE)', () async {
      await queue.enqueue(buildOp('x'));
      await queue.enqueue(buildOp('x', attempts: 5));

      final PendingOperation? fetched = await queue.findById('x');
      expect(fetched!.attempts, 5);
      expect(await queue.listAll(), hasLength(1));
    });
  });

  group('PendingOperation — round-trip', () {
    test('toRow / fromRow preserva campos', () {
      final PendingOperation op = buildOp(
        'rt',
        attempts: 3,
        status: PendingOperationStatus.failed,
      );
      final Map<String, Object?> row = op.toRow();
      final PendingOperation rebuilt = PendingOperation.fromRow(row);
      expect(rebuilt, equals(op));
    });

    test('toJson / fromJson preserva campos', () {
      final PendingOperation op = buildOp('rt2', attempts: 2);
      final PendingOperation rebuilt = PendingOperation.fromJson(op.toJson());
      expect(rebuilt, equals(op));
    });

    test('copyWith preserva campos não passados', () {
      final PendingOperation op = buildOp('a');
      final PendingOperation copy = op.copyWith(attempts: 9);
      expect(copy.attempts, 9);
      expect(copy.id, op.id);
      expect(copy.lastError, op.lastError);
    });

    test('copyWith com clearLastError zera o campo', () {
      final PendingOperation op = buildOp('a').copyWith(lastError: 'x');
      expect(op.lastError, 'x');
      final PendingOperation cleaned = op.copyWith(clearLastError: true);
      expect(cleaned.lastError, isNull);
    });
  });
}
