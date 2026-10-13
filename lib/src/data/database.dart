import 'package:drift/drift.dart';

import 'dao/audit_dao.dart';
import 'dao/batch_dao.dart';
import 'dao/movement_dao.dart';
import 'dao/product_dao.dart';
import 'dao/setting_dao.dart';
import 'dao/supplier_dao.dart';
import 'tables.dart';

export 'dao/audit_dao.dart';
export 'dao/batch_dao.dart';
export 'dao/movement_dao.dart';
export 'dao/product_dao.dart';
export 'dao/setting_dao.dart';
export 'dao/supplier_dao.dart';

part 'database.g.dart';

/// Known schema versions. Add a new migration whenever tables
/// change and bump [AppDatabase.schemaVersion] — never destructive.
class DatabaseMigrations {
  DatabaseMigrations._();

  // Version history:
  // 1 — initial schema (products, movements, settings)
  //     NOTE: builds up to commit 35073b4 created these tables with drift's
  //     default plural names. 35073b4 overrode tableName to the singular form
  //     without adding a migration and without bumping schemaVersion, so two
  //     different physical schemas exist reporting user_version = 1. The
  //     upgrade path repairs the plural variant — see _renameLegacyTables.
  // 2 — enterprise schema (category, stockAuditSessions, stockAuditItems, batches)
  // 3 — supplier directory schema (suppliers table, product.supplierId, movement.supplierId)
  static const int currentVersion = 3;

  /// Tables renamed in 35073b4, oldest name first. Order matters: renaming
  /// `products` first lets SQLite rewrite the foreign key in `movements`
  /// before that table is itself renamed.
  static const Map<String, String> legacyTableNames = {
    'products': 'product',
    'movements': 'movement',
    'settings': 'setting',
  };
}

@DriftDatabase(
  tables: [Products, Movements, Settings, StockAuditSessions, StockAuditItems, Batches, Suppliers],
  daos: [ProductDao, MovementDao, SettingDao, AuditDao, BatchDao, SupplierDao],
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
        // Must run before anything touches `product`/`movement`/`setting`:
        // a database created before 35073b4 still holds the plural names.
        await _renameLegacyTables();
        await m.addColumn(products, products.category);
        await m.addColumn(movements, movements.auditSessionId);
        await m.addColumn(movements, movements.batchId);
        await m.createTable(stockAuditSessions);
        await m.createTable(stockAuditItems);
        await m.createTable(batches);
      }
      if (from < 3) {
        await m.createTable(suppliers);
        await m.addColumn(products, products.supplierId);
        await m.addColumn(movements, movements.supplierId);
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

  /// Repairs databases created before commit 35073b4, which used drift's
  /// default plural table names. Renames each legacy table to its current
  /// name, but only when the legacy table is present and the current one is
  /// not — so a v1 database created after the rename is left untouched and
  /// an already-repaired database is never touched twice.
  ///
  /// This is a rename, never a drop: no row is read, written or deleted.
  Future<void> _renameLegacyTables() async {
    for (final entry in DatabaseMigrations.legacyTableNames.entries) {
      final hasLegacy = await _tableExists(entry.key);
      if (!hasLegacy) continue;

      final hasCurrent = await _tableExists(entry.value);
      if (hasCurrent) continue;

      await customStatement(
        'ALTER TABLE "${entry.key}" RENAME TO "${entry.value}"',
      );
    }
  }

  Future<bool> _tableExists(String name) async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?1",
      variables: [Variable<String>(name)],
    ).get();
    return rows.isNotEmpty;
  }

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
