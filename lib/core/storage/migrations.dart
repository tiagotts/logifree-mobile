import 'package:sqflite/sqflite.dart';

/// Versão atual do schema SQLite local.
///
/// Incrementar **sempre** que [schemaMigrations] ganhar uma nova
/// migration. O `sqflite` chama [onUpgrade] passando o gap entre
/// `oldVersion` e `newVersion` — esse índice precisa bater.
const int kSchemaVersion = 1;

/// Função de migração — recebe o [Database] e executa o DDL/DML
/// necessário para promover o schema da versão `n-1` para `n`.
typedef SchemaMigration = Future<void> Function(Database db);

/// Lista ordenada de migrações.
///
/// Por convenção: `schemaMigrations[i]` migra de versão `i` para `i+1`.
/// Ou seja, o índice 0 é a criação inicial (versão 0 → 1).
///
/// **Nunca remova nem reordene migrações antigas** — usuários com
/// versões legadas dependem de todas as migrações intermediárias.
final List<SchemaMigration> schemaMigrations = <SchemaMigration>[_createV1];

/// Cria o schema inicial (v1):
/// - Tabela `pending_operations` (fila offline).
Future<void> _createV1(Database db) async {
  await db.execute('''
    CREATE TABLE pending_operations (
      id TEXT PRIMARY KEY,
      method TEXT NOT NULL,
      url TEXT NOT NULL,
      headers TEXT,
      body TEXT,
      idempotency_key TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL,
      last_error TEXT
    )
  ''');

  // Índice por created_at: drenagem FIFO faz ORDER BY created_at ASC.
  await db.execute(
    'CREATE INDEX idx_pending_ops_created_at '
    'ON pending_operations(created_at)',
  );

  // Índice por status: queries de listagem filtram por status.
  await db.execute(
    'CREATE INDEX idx_pending_ops_status ON pending_operations(status)',
  );
}

/// Roda todas as migrações necessárias para criar o schema do zero.
///
/// Chamado pelo `onCreate` do `openDatabase`.
Future<void> runInitialMigrations(Database db) async {
  for (final SchemaMigration migration in schemaMigrations) {
    await migration(db);
  }
}

/// Roda as migrações pendentes entre [oldVersion] e [newVersion].
///
/// Chamado pelo `onUpgrade` do `openDatabase`.
Future<void> runUpgradeMigrations(
  Database db,
  int oldVersion,
  int newVersion,
) async {
  // schemaMigrations[i] cobre versão (i+1). Para subir de oldVersion
  // até newVersion, rodamos os índices [oldVersion .. newVersion-1].
  for (int i = oldVersion; i < newVersion; i++) {
    await schemaMigrations[i](db);
  }
}
