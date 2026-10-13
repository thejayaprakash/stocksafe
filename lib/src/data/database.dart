import 'package:drift/drift.dart';

import 'dao/audit_dao.dart';
import 'dao/batch_dao.dart';
import 'dao/movement_dao.dart';
import 'dao/product_dao.dart';
import 'dao/setting_dao.dart';
import 'tables.dart';

export 'dao/audit_dao.dart';
export 'dao/batch_dao.dart';
export 'dao/movement_dao.dart';
export 'dao/product_dao.dart';
export 'dao/setting_dao.dart';

part 'database.g.dart';

/// Known schema versions. Add a new migration whenever tables
/// change and bump [AppDatabase.schemaVersion] — never destructive.
class DatabaseMigrations {
  DatabaseMigrations._();

  // Version history:
  // 1 — initial schema (products, movements, settings)
  // 2 — enterprise schema (category, stockAuditSessions, stockAuditItems, batches)
  static const int currentVersion = 2;
}

@DriftDatabase(
  tables: [Products, Movements, Settings, StockAuditSessions, StockAuditItems, Batches],
  daos: [ProductDao, MovementDao, SettingDao, AuditDao, BatchDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => DatabaseMigrations.currentVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(products, products.category);
        await m.addColumn(movements, movements.auditSessionId);
        await m.addColumn(movements, movements.batchId);
        await m.createTable(stockAuditSessions);
        await m.createTable(stockAuditItems);
        await m.createTable(batches);
      }
    },
    beforeOpen: (details) async {
      // Enforce FK constraints and keep the cache consistent on open.
      await customStatement('PRAGMA foreign_keys = ON');
      if (details.hadUpgrade) {
        await rebuildAllStockCaches();
      }
    },
  );

  /// Recomputes every product's cached stockQty from the movement ledger.
  /// Callable from settings/debug and after any schema upgrade.
  Future<void> rebuildAllStockCaches() async {
    await customStatement('''
      UPDATE product SET stock_qty = COALESCE(
        (SELECT SUM(qty_delta) FROM movement WHERE movement.product_id = product.id),
        0
      ) WHERE deleted_at IS NULL
    ''');
  }
}
