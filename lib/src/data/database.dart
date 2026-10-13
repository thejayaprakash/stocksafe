import 'package:drift/drift.dart';

import 'dao/movement_dao.dart';
import 'dao/product_dao.dart';
import 'dao/setting_dao.dart';
import 'tables.dart';

export 'dao/movement_dao.dart';
export 'dao/product_dao.dart';
export 'dao/setting_dao.dart';

part 'database.g.dart';

/// Known schema versions. Add a new `TableMigration` whenever tables
/// change and bump [AppDatabase.schemaVersion] — never destructive.
class DatabaseMigrations {
  DatabaseMigrations._();

  // Version history:
  // 1 — initial schema (products, movements, settings)
  static const int currentVersion = 1;

  /// Every migration ever shipped, keyed by the version it upgrades FROM.
  /// When you add version 2, append its migration here and add a schema
  /// JSON via `dart run drift_dev schema dump`.
  static final List<Migration> all = [
    // Future: Migration(
    //   from: 1, to: 2,
    //   onCreate: (m) async { await m.addColumn(products, products.foo); },
    // ),
  ];
}

@DriftDatabase(tables: [Products, Movements, Settings], daos: [ProductDao, MovementDao, SettingDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => DatabaseMigrations.currentVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: (m, from, to) async {
      for (final step in DatabaseMigrations.all) {
        if (step.from >= from && step.to <= to) {
          await step.onCreate(m);
        }
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

class Migration {
  const Migration({required this.from, required this.to, required this.onCreate});

  final int from;
  final int to;
  final Future<void> Function(Migrator m) onCreate;
}
