import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../offline/pending_operation.dart';
import 'migrations.dart';

/// Nome padrão do arquivo do banco local.
const String kOfflineQueueDbName = 'logifree_offline.db';

/// DAO da fila de operações offline.
///
/// Pode ser construído com um [Database] explícito (em testes,
/// `openDatabase` em memória via `sqflite_common_ffi`) ou via
/// [OfflineQueue.open] em produção, que abre o arquivo no diretório
/// padrão do `sqflite`.
///
/// **Responsabilidades:**
/// - CRUD da tabela `pending_operations`.
/// - Conversão entre [PendingOperation] e linhas SQL.
/// - Stream de mudanças (consumida pela UI).
///
/// **Não** faz HTTP, **não** observa conectividade — isso é do
/// [SyncService].
class OfflineQueue {
  /// Cria o DAO com um [Database] já aberto.
  ///
  /// Em produção, use [OfflineQueue.open]; este construtor é útil
  /// para testes que controlam a abertura do DB manualmente.
  OfflineQueue(this._db);

  /// Abre o banco padrão do app (no diretório retornado por
  /// `getDatabasesPath`) e devolve um [OfflineQueue] pronto pra uso.
  ///
  /// O parâmetro [databaseName] existe para isolar testes que rodam
  /// em paralelo.
  static Future<OfflineQueue> open({
    String databaseName = kOfflineQueueDbName,
  }) async {
    final String basePath = await getDatabasesPath();
    final String fullPath = p.join(basePath, databaseName);
    final Database db = await openDatabase(
      fullPath,
      version: kSchemaVersion,
      onCreate: (Database db, int version) async {
        await runInitialMigrations(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        await runUpgradeMigrations(db, oldVersion, newVersion);
      },
    );
    return OfflineQueue(db);
  }

  final Database _db;

  static const String _table = 'pending_operations';

  final StreamController<List<PendingOperation>> _changes =
      StreamController<List<PendingOperation>>.broadcast();

  /// Stream das pendências atualizadas após cada mutação no banco.
  ///
  /// **Não** dispara automaticamente um snapshot inicial — para isso,
  /// chame [listAll] e combine com o stream conforme a necessidade.
  Stream<List<PendingOperation>> get changes => _changes.stream;

  /// Fecha o banco e o stream. Chame em testes/teardown.
  Future<void> close() async {
    await _changes.close();
    await _db.close();
  }

  /// Insere (ou substitui, se o `id` colidir) uma operação na fila.
  ///
  /// Após persistir, emite o snapshot atualizado em [changes].
  Future<void> enqueue(PendingOperation op) async {
    await _db.insert(
      _table,
      op.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _emitSnapshot();
  }

  /// Retorna apenas operações em estado `pending` ou `sending`,
  /// ordenadas por `created_at ASC` (FIFO).
  ///
  /// Itens em `failed` ficam fora — são visíveis na tela de
  /// pendências (CARD-022) via [listAll].
  Future<List<PendingOperation>> listPending() async {
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      where: 'status IN (?, ?)',
      whereArgs: <String>[
        PendingOperationStatus.pending.toDbValue(),
        PendingOperationStatus.sending.toDbValue(),
      ],
      orderBy: 'created_at ASC',
    );
    return rows.map(PendingOperation.fromRow).toList();
  }

  /// Retorna todas as operações (inclusive `failed`), ordenadas por
  /// `created_at ASC`.
  Future<List<PendingOperation>> listAll() async {
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      orderBy: 'created_at ASC',
    );
    return rows.map(PendingOperation.fromRow).toList();
  }

  /// Busca uma operação por id. Retorna `null` se não existir.
  Future<PendingOperation?> findById(String id) async {
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      where: 'id = ?',
      whereArgs: <String>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return PendingOperation.fromRow(rows.first);
  }

  /// Marca a operação como `sending` (em trânsito).
  Future<void> markSending(String id) async {
    await _db.update(
      _table,
      <String, Object?>{'status': PendingOperationStatus.sending.toDbValue()},
      where: 'id = ?',
      whereArgs: <String>[id],
    );
    await _emitSnapshot();
  }

  /// Marca como `failed` (atingiu `maxAttempts`).
  ///
  /// O parâmetro [error] é gravado em `last_error` para diagnóstico.
  Future<void> markFailed(String id, String error) async {
    await _db.update(
      _table,
      <String, Object?>{
        'status': PendingOperationStatus.failed.toDbValue(),
        'last_error': error,
      },
      where: 'id = ?',
      whereArgs: <String>[id],
    );
    await _emitSnapshot();
  }

  /// Remove a operação após sincronização bem-sucedida.
  ///
  /// Mesmo efeito de [delete] — existe por simetria com [markFailed]
  /// e para deixar o intent explícito no chamador.
  Future<void> markDone(String id) async {
    await delete(id);
  }

  /// Deleta a operação pelo id.
  Future<void> delete(String id) async {
    await _db.delete(_table, where: 'id = ?', whereArgs: <String>[id]);
    await _emitSnapshot();
  }

  /// Incrementa `attempts` e devolve o pacote opcionalmente com o
  /// novo número, voltando a operação ao estado `pending`.
  ///
  /// Também grava [lastError] caso fornecido.
  Future<int> incrementAttempts(String id, {String? lastError}) async {
    final PendingOperation? existing = await findById(id);
    if (existing == null) {
      return 0;
    }
    final int newAttempts = existing.attempts + 1;
    await _db.update(
      _table,
      <String, Object?>{
        'attempts': newAttempts,
        'status': PendingOperationStatus.pending.toDbValue(),
        'last_error': lastError,
      },
      where: 'id = ?',
      whereArgs: <String>[id],
    );
    await _emitSnapshot();
    return newAttempts;
  }

  /// Reseta uma operação para um novo ciclo de tentativas.
  ///
  /// Usado pela tela de pendências (CARD-022) quando o usuário toca em
  /// "Tentar novamente" — zera `attempts`, limpa `last_error` e volta o
  /// status para `pending` para que o [SyncService] possa drenar de novo.
  ///
  /// Se a operação não existe, é no-op.
  Future<void> resetForRetry(String id) async {
    final int affected = await _db.update(
      _table,
      <String, Object?>{
        'attempts': 0,
        'status': PendingOperationStatus.pending.toDbValue(),
        'last_error': null,
      },
      where: 'id = ?',
      whereArgs: <String>[id],
    );
    if (affected > 0) {
      await _emitSnapshot();
    }
  }

  /// Atalho de teste/admin: limpa toda a fila.
  Future<void> clear() async {
    await _db.delete(_table);
    await _emitSnapshot();
  }

  Future<void> _emitSnapshot() async {
    if (_changes.isClosed) {
      return;
    }
    final List<PendingOperation> snapshot = await listAll();
    _changes.add(snapshot);
  }
}

/// Provider Riverpod do [OfflineQueue].
///
/// Manual (sem codegen) por decisão do projeto. O `FutureProvider` lida
/// com a abertura assíncrona do banco; consumidores devem usar
/// `ref.watch(offlineQueueProvider.future)` ou ler o `.value` quando já
/// resolvido.
///
/// O provider tem um `onDispose` que **não** fecha o banco — em
/// produção o ciclo de vida é o do app inteiro. Testes que precisam
/// de cleanup devem chamar `OfflineQueue.close()` explicitamente.
final FutureProvider<OfflineQueue> offlineQueueProvider =
    FutureProvider<OfflineQueue>((Ref ref) async {
      return OfflineQueue.open();
    });
