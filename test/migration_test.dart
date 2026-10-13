// Migration safety net.
//
// The competitor this app exists to beat loses user data on update. Rule 2 in
// the README — "every schema change ships with a tested migration" — is only
// true if something actually runs the migrations. This is that something.
//
// Regenerate the fixtures after any schema change:
//   dart run drift_dev schema dump lib/src/data/database.dart drift_schemas/
//   dart run drift_dev schema generate --data-classes --companions \
//       drift_schemas/ test/generated_migrations/
//   bash tool/fix_generated_migrations.sh
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stocksafe/src/data/database.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v1.dart' as v1;
import 'generated_migrations/schema_v2.dart' as v2;

/// Drift stores `DateTimeColumn` as unix seconds; the generated historical
/// schemas expose those columns as plain ints.
int _secs(DateTime dt) => dt.millisecondsSinceEpoch ~/ 1000;

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('Schema shape', () {
    // Every starting point must reach the current version with a schema that
    // exactly matches what a fresh install would create.
    for (final from in GeneratedHelper.versions) {
      test('migrates v$from to v${DatabaseMigrations.currentVersion}', () async {
        final connection = await verifier.schemaAt(from);
        final db = AppDatabase(connection.newConnection());
        await verifier.migrateAndValidate(db, DatabaseMigrations.currentVersion);
        await db.close();
      });
    }

    test('fresh install creates the current schema', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await verifier.migrateAndValidate(db, DatabaseMigrations.currentVersion);
      await db.close();
    });
  });

  group('Data preservation', () {
    test('v1 data survives the full migration to v3 unchanged', () async {
      final schema = await verifier.schemaAt(1);
      final createdAt = DateTime.utc(2026, 1, 15, 10, 30);
      final updatedAt = DateTime.utc(2026, 2, 20, 14, 45);
      final deletedAt = DateTime.utc(2026, 3, 1, 9, 0);

      // ── Write through the real v1 schema ──────────────────────────
      final oldDb = v1.DatabaseAtV1(schema.newConnection());

      await oldDb.into(oldDb.products).insert(
            v1.ProductsCompanion.insert(
              name: 'Aachi Chilli Powder 100g',
              sku: const Value('ACP-100'),
              barcode: const Value('8901234567890'),
              unit: const Value('pkt'),
              buyPrice: const Value(42.5),
              sellPrice: const Value(55.0),
              lowStockLevel: const Value(10),
              stockQty: const Value(0),
              createdAt: _secs(createdAt),
              updatedAt: _secs(updatedAt),
            ),
          );

      // A soft-deleted product must stay soft-deleted, not vanish.
      await oldDb.into(oldDb.products).insert(
            v1.ProductsCompanion.insert(
              name: 'Discontinued Soap',
              createdAt: _secs(createdAt),
              updatedAt: _secs(updatedAt),
              deletedAt: Value(_secs(deletedAt)),
            ),
          );

      // Ledger rows: +100, -30, -5 => 65.
      for (final entry in [
        (100, 'opening_stock'),
        (-30, 'sale'),
        (-5, 'damage'),
      ]) {
        await oldDb.into(oldDb.movements).insert(
              v1.MovementsCompanion.insert(
                productId: 1,
                qtyDelta: entry.$1,
                reason: entry.$2,
                note: Value('v1 row: ${entry.$2}'),
                createdAt: _secs(createdAt),
              ),
            );
      }

      await oldDb.into(oldDb.settings).insert(
            v1.SettingsCompanion.insert(
              key: 'shop_name',
              value: 'Sri Lakshmi Stores',
            ),
          );

      await oldDb.close();

      // ── Migrate v1 -> v3 ──────────────────────────────────────────
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, DatabaseMigrations.currentVersion);

      // ── Nothing lost, nothing altered ─────────────────────────────
      final active = await db.productDao.getAllForExport();
      expect(active, hasLength(1),
          reason: 'soft-deleted product must stay filtered, not dropped');

      final product = active.single;
      expect(product.id, 1);
      expect(product.name, 'Aachi Chilli Powder 100g');
      expect(product.sku, 'ACP-100');
      expect(product.barcode, '8901234567890');
      expect(product.unit, 'pkt');
      expect(product.buyPrice, 42.5);
      expect(product.sellPrice, 55.0);
      expect(product.lowStockLevel, 10);
      expect(_secs(product.createdAt), _secs(createdAt));
      expect(_secs(product.updatedAt), _secs(updatedAt));

      // Columns added in v2/v3 must be null, never defaulted to junk.
      expect(product.category, isNull);
      expect(product.supplierId, isNull);

      // The soft-deleted row is still physically present.
      final all = await db.select(db.products).get();
      expect(all, hasLength(2),
          reason: 'soft-deleted rows must never be dropped by a migration');
      final removed = all.firstWhere((p) => p.id == 2);
      expect(removed.name, 'Discontinued Soap');
      expect(_secs(removed.deletedAt!), _secs(deletedAt));

      // The ledger is intact.
      final movements = await db.movementDao.getAllForExport();
      expect(movements, hasLength(3));
      expect(movements.map((m) => m.qtyDelta).toList()..sort(), [-30, -5, 100]);
      for (final m in movements) {
        expect(m.productId, 1);
        expect(_secs(m.createdAt), _secs(createdAt));
        expect(m.note, startsWith('v1 row: '));
        expect(m.batchId, isNull);
        expect(m.auditSessionId, isNull);
        expect(m.supplierId, isNull);
      }

      // beforeOpen rebuilds the cache on upgrade: 100 - 30 - 5 = 65.
      expect(product.stockQty, 65,
          reason: 'cache must be rebuilt from the ledger after a schema upgrade');

      expect(await db.settingDao.get('shop_name'), 'Sri Lakshmi Stores');

      await db.close();
    });

    test('v2 data survives the migration to v3 unchanged', () async {
      final schema = await verifier.schemaAt(2);
      final ts = DateTime.utc(2026, 5, 10, 8, 0);
      final expiry = DateTime.utc(2026, 11, 30);

      final oldDb = v2.DatabaseAtV2(schema.newConnection());

      await oldDb.into(oldDb.product).insert(
            v2.ProductCompanion.insert(
              name: 'Britannia Good Day 100g',
              category: const Value('Biscuits'),
              buyPrice: const Value(8.0),
              sellPrice: const Value(10.0),
              createdAt: _secs(ts),
              updatedAt: _secs(ts),
            ),
          );

      await oldDb.into(oldDb.movement).insert(
            v2.MovementCompanion.insert(
              productId: 1,
              qtyDelta: 48,
              reason: 'opening_stock',
              createdAt: _secs(ts),
            ),
          );

      // v2 introduced batches and audit sessions — they must survive too.
      await oldDb.into(oldDb.batchTable).insert(
            v2.BatchCompanion.insert(
              productId: 1,
              batchNumber: 'B-2026-05',
              expiryDate: Value(_secs(expiry)),
              stockQty: const Value(48),
              createdAt: _secs(ts),
              updatedAt: _secs(ts),
            ),
          );

      await oldDb.into(oldDb.stockAuditSession).insert(
            v2.StockAuditSessionCompanion.insert(
              name: 'Diwali stocktake',
              startedAt: _secs(ts),
            ),
          );

      await oldDb.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, DatabaseMigrations.currentVersion);

      final product = (await db.productDao.getAllForExport()).single;
      expect(product.name, 'Britannia Good Day 100g');
      expect(product.category, 'Biscuits', reason: 'v2 column must carry forward');
      expect(product.supplierId, isNull,
          reason: 'v3 column must be null, not defaulted');
      expect(product.stockQty, 48);

      final batch = (await db.batchDao.getBatchesForProduct(1)).single;
      expect(batch.batchNumber, 'B-2026-05');
      expect(batch.stockQty, 48);
      expect(_secs(batch.expiryDate!), _secs(expiry));

      final session = await db.auditDao.getSession(1);
      expect(session, isNotNull);
      expect(session!.name, 'Diwali stocktake');
      expect(session.status, 'in_progress');

      expect(await db.movementDao.getAllForExport(), hasLength(1));

      await db.close();
    });
  });

  group('Legacy table naming', () {
    // Commit 35073b4 renamed the SQL tables from drift's default plural
    // (products/movements/settings) to singular, while leaving schemaVersion
    // at 1. Both shapes therefore exist in the wild reporting user_version = 1,
    // and the upgrade path must cope with either or the data is unreachable.
    test('a pre-rename v1 database keeps its data after upgrade', () async {
      // A real file, because the legacy schema has to be created and closed
      // before the app database opens it — exactly as it happens on a phone
      // that upgrades from a pre-35073b4 build.
      final dir = await Directory.systemTemp.createTemp('stocksafe_legacy');
      addTearDown(() => dir.delete(recursive: true));
      final file = File(p.join(dir.path, 'stocksafe.sqlite'));

      final legacy = _LegacyV1Database(NativeDatabase(file));
      await legacy.createLegacySchema();

      final ts = DateTime.utc(2026, 4, 1, 12, 0);
      await legacy.customStatement(
        'INSERT INTO products (name, unit, buy_price, sell_price, '
        'low_stock_level, stock_qty, created_at, updated_at) VALUES '
        "('Legacy Rice 5kg', 'bag', 250.0, 300.0, 2, 0, ${_secs(ts)}, ${_secs(ts)})",
      );
      await legacy.customStatement(
        'INSERT INTO movements (product_id, qty_delta, reason, created_at) '
        "VALUES (1, 20, 'opening_stock', ${_secs(ts)})",
      );
      await legacy.customStatement(
        "INSERT INTO settings (key, value) VALUES ('shop_name', 'Legacy Store')",
      );
      await legacy.close();

      // Reopen the same file through the real app database so the upgrade runs.
      final db = AppDatabase(NativeDatabase(file));
      final products = await db.productDao.getAllForExport();

      expect(products, hasLength(1),
          reason: 'a pre-rename v1 database must not lose its products');
      expect(products.single.name, 'Legacy Rice 5kg');
      expect(products.single.buyPrice, 250.0);
      expect(products.single.stockQty, 20,
          reason: 'ledger must still back the cache after the rename');
      expect(await db.settingDao.get('shop_name'), 'Legacy Store');
      expect(await db.movementDao.getAllForExport(), hasLength(1));

      await db.close();
    });
  });
}

/// Minimal harness that creates the exact SQL schema shipped at commit
/// `cdba294` — drift's default plural table names, `user_version = 1`.
class _LegacyV1Database extends GeneratedDatabase {
  _LegacyV1Database(super.executor);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(onCreate: (_) async {});

  Future<void> createLegacySchema() async {
    await customStatement('''
      CREATE TABLE products (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sku TEXT NULL,
        barcode TEXT NULL,
        unit TEXT NOT NULL DEFAULT 'pcs',
        buy_price REAL NOT NULL DEFAULT 0,
        sell_price REAL NOT NULL DEFAULT 0,
        low_stock_level INTEGER NOT NULL DEFAULT 0,
        stock_qty INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE movements (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL REFERENCES products (id) ON DELETE CASCADE,
        qty_delta INTEGER NOT NULL,
        reason TEXT NOT NULL,
        note TEXT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE settings (
        key TEXT NOT NULL,
        value TEXT NOT NULL,
        PRIMARY KEY (key)
      )
    ''');
    await customStatement('PRAGMA user_version = 1');
  }
}
