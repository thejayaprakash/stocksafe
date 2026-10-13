// Migration safety net.
//
// The competitor this app exists to beat loses user data on update. Rule 2 in
// the README — "every schema change ships with a tested migration" — is only
// true if something actually runs the migrations. This is that something.
//
// Regenerate the fixtures after any schema change — all four steps:
//   dart run drift_dev schema dump lib/src/data/database.dart drift_schemas/
//   dart run drift_dev schema steps drift_schemas/ lib/src/data/schema_versions.dart
//   dart run drift_dev schema generate --data-classes --companions \
//       drift_schemas/ test/generated_migrations/
//   bash tool/fix_generated_migrations.sh
//
// Then add the new `fromNToN+1` step to AppDatabase.migration and a matching
// case to the 'Individual migration steps' group below.
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
import 'generated_migrations/schema_v3.dart' as v3;
import 'generated_migrations/schema_v5.dart' as v5;

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

  group('Individual migration steps', () {
    // stepByStep applies one function per version transition. Testing only
    // v1 -> current would hide a step that is wrong but compensated for by a
    // later one, so each boundary is exercised on its own.

    test('step 1 to 2 adds the enterprise schema and keeps v1 data', () async {
      final schema = await verifier.schemaAt(1);
      final ts = DateTime.utc(2026, 6, 1, 9, 0);

      final oldDb = v1.DatabaseAtV1(schema.newConnection());
      await oldDb.into(oldDb.products).insert(
            v1.ProductsCompanion.insert(
              name: 'Step test product',
              buyPrice: const Value(12.0),
              createdAt: _secs(ts),
              updatedAt: _secs(ts),
            ),
          );
      await oldDb.into(oldDb.movements).insert(
            v1.MovementsCompanion.insert(
              productId: 1,
              qtyDelta: 7,
              reason: 'opening_stock',
              createdAt: _secs(ts),
            ),
          );
      await oldDb.close();

      // Pinning schemaVersion to 2 stops stepByStep after from1To2.
      final db = _AppDatabaseAtVersion(schema.newConnection(), 2);
      await verifier.migrateAndValidate(db, 2);

      expect(await _userVersion(db), 2, reason: 'step must land exactly on v2');

      // Tables introduced by this step exist.
      for (final table in ['stock_audit_session', 'stock_audit_item', 'batch']) {
        expect(await _tableExists(db, table), isTrue,
            reason: '$table should be created by step 1->2');
      }
      // Columns introduced by this step exist.
      expect(await _columnExists(db, 'product', 'category'), isTrue);
      expect(await _columnExists(db, 'movement', 'audit_session_id'), isTrue);
      expect(await _columnExists(db, 'movement', 'batch_id'), isTrue);
      // The v3 column must NOT be here yet.
      expect(await _columnExists(db, 'product', 'supplier_id'), isFalse,
          reason: 'step 1->2 must not apply step 2->3');

      // v1 data untouched by the step.
      final rows = await db.customSelect('SELECT name, buy_price FROM product').get();
      expect(rows, hasLength(1));
      expect(rows.single.read<String>('name'), 'Step test product');
      expect(rows.single.read<double>('buy_price'), 12.0);
      expect(
        await db.customSelect('SELECT COUNT(*) AS c FROM movement').getSingle(),
        isA<QueryRow>().having((r) => r.read<int>('c'), 'movement count', 1),
      );

      await db.close();
    });

    test('step 2 to 3 adds the supplier schema and keeps v2 data', () async {
      final schema = await verifier.schemaAt(2);
      final ts = DateTime.utc(2026, 6, 2, 9, 0);

      final oldDb = v2.DatabaseAtV2(schema.newConnection());
      await oldDb.into(oldDb.product).insert(
            v2.ProductCompanion.insert(
              name: 'Step test product v2',
              category: const Value('Spices'),
              createdAt: _secs(ts),
              updatedAt: _secs(ts),
            ),
          );
      await oldDb.close();

      final db = _AppDatabaseAtVersion(schema.newConnection(), 3);
      await verifier.migrateAndValidate(db, 3);

      expect(await _userVersion(db), 3, reason: 'step must land exactly on v3');
      expect(await _tableExists(db, 'supplier'), isTrue);
      expect(await _columnExists(db, 'product', 'supplier_id'), isTrue);
      expect(await _columnExists(db, 'movement', 'supplier_id'), isTrue);

      // v2 data, including the column added by the previous step, survives.
      final rows =
          await db.customSelect('SELECT name, category, supplier_id FROM product').get();
      expect(rows, hasLength(1));
      expect(rows.single.read<String>('name'), 'Step test product v2');
      expect(rows.single.read<String>('category'), 'Spices');
      expect(rows.single.read<int?>('supplier_id'), isNull);
      expect(await _columnExists(db, 'batch', 'deleted_at'), isFalse,
          reason: 'step 2->3 must not apply step 3->4');

      await db.close();
    });

    test('step 3 to 4 soft-deletes batches and de-duplicates barcodes',
        () async {
      final schema = await verifier.schemaAt(3);
      final ts = DateTime.utc(2026, 7, 1, 10, 0);

      final oldDb = v3.DatabaseAtV3(schema.newConnection());

      // Two live products sharing a barcode — what importing the same supplier
      // CSV twice produced before the importer skipped duplicates.
      for (final name in ['Original Rice 5kg', 'Duplicate Rice 5kg']) {
        await oldDb.into(oldDb.product).insert(
              v3.ProductCompanion.insert(
                name: name,
                barcode: const Value('8901234567890'),
                createdAt: _secs(ts),
                updatedAt: _secs(ts),
              ),
            );
      }
      // A product whose barcode is unique must keep it.
      await oldDb.into(oldDb.product).insert(
            v3.ProductCompanion.insert(
              name: 'Dal 1kg',
              barcode: const Value('8909999999999'),
              createdAt: _secs(ts),
              updatedAt: _secs(ts),
            ),
          );
      // Two products with no barcode at all must be unaffected: SQLite treats
      // NULLs as distinct, so they do not collide.
      for (final name in ['Loose item A', 'Loose item B']) {
        await oldDb.into(oldDb.product).insert(
              v3.ProductCompanion.insert(
                name: name,
                createdAt: _secs(ts),
                updatedAt: _secs(ts),
              ),
            );
      }
      await oldDb.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 4);

      expect(await _userVersion(db), 4);
      expect(await _columnExists(db, 'batch', 'deleted_at'), isTrue);

      // Nothing was deleted — all five products are still present.
      final all = await db.customSelect(
        'SELECT id, name, barcode FROM product ORDER BY id',
      ).get();
      expect(all, hasLength(5),
          reason: 'de-duplication must clear barcodes, never drop rows');

      // The oldest claimant keeps the barcode; the newer one is cleared.
      expect(all[0].read<String?>('barcode'), '8901234567890');
      expect(all[1].read<String?>('barcode'), isNull,
          reason: 'the duplicate keeps its stock and ledger, loses the code');
      expect(all[2].read<String?>('barcode'), '8909999999999',
          reason: 'a unique barcode must be left alone');

      // The index is real: a second live product cannot claim the code again.
      await expectLater(
        db.customStatement(
          "UPDATE product SET barcode = '8901234567890' WHERE id = 2",
        ),
        throwsA(anything),
        reason: 'the unique index must be enforced after the migration',
      );

      await db.close();
    });

    test('step 5 to 6 backfills every movement to one default location',
        () async {
      // The riskiest part of adding locations: existing stock has no location,
      // and if the backfill misses a row that row's quantity disappears from
      // every per-location view while still counting towards the product
      // total. Totals must be identical before and after.
      final schema = await verifier.schemaAt(5);
      final ts = DateTime.utc(2026, 8, 1, 9, 0);

      final oldDb = v5.DatabaseAtV5(schema.newConnection());
      await oldDb.into(oldDb.product).insert(
            v5.ProductCompanion.insert(
              name: 'Rice 5kg',
              createdAt: _secs(ts),
              updatedAt: _secs(ts),
            ),
          );
      for (final delta in [100, -30, -5]) {
        await oldDb.into(oldDb.movement).insert(
              v5.MovementCompanion.insert(
                productId: 1,
                qtyDelta: delta,
                reason: delta > 0 ? 'purchase' : 'sale',
                createdAt: _secs(ts),
              ),
            );
      }
      await oldDb.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, DatabaseMigrations.currentVersion);

      expect(await _tableExists(db, 'location'), isTrue);
      expect(await _columnExists(db, 'movement', 'location_id'), isTrue);
      expect(await _columnExists(db, 'movement', 'transfer_ref'), isTrue);

      // Exactly one location, and it is the default.
      final locations = await db.locationDao.getAll();
      expect(locations, hasLength(1));
      expect(locations.single.name, DatabaseMigrations.defaultLocationName);
      expect(locations.single.isDefault, isTrue);

      // No movement left without a home.
      final orphans = await db
          .customSelect('SELECT COUNT(*) AS c FROM movement WHERE location_id IS NULL')
          .getSingle();
      expect(orphans.read<int>('c'), 0,
          reason: 'an unbackfilled row would vanish from per-location views');

      // And the numbers are unchanged: 100 - 30 - 5 = 65, all at Main.
      expect((await db.productDao.getById(1))!.stockQty, 65);
      expect(await db.locationDao.stockOf(1, locations.single.id), 65);
      expect(await db.movementDao.getAllForExport(), hasLength(3));

      await db.close();
    });

    test('a v1 database passes through v2 rather than jumping to v3', () async {
      // Guards the stepByStep contract: every intermediate step must run, so a
      // future step that backfills data is never skipped.
      final schema = await verifier.schemaAt(1);

      final atV2 = _AppDatabaseAtVersion(schema.newConnection(), 2);
      await verifier.migrateAndValidate(atV2, 2);
      expect(await _userVersion(atV2), 2);
      await atV2.close();

      // Resuming from the now-v2 database runs every remaining step in order.
      final atLatest = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(atLatest, DatabaseMigrations.currentVersion);
      expect(await _userVersion(atLatest), DatabaseMigrations.currentVersion);
      expect(await _tableExists(atLatest, 'supplier'), isTrue);
      expect(await _columnExists(atLatest, 'batch', 'deleted_at'), isTrue);
      await atLatest.close();
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

/// Reads `PRAGMA user_version`, which is where SQLite records the schema
/// version — drift's equivalent of Flyway's schema history table.
Future<int> _userVersion(GeneratedDatabase db) async {
  final row = await db.customSelect('PRAGMA user_version').getSingle();
  return row.data.values.first! as int;
}

Future<bool> _tableExists(GeneratedDatabase db, String name) async {
  final rows = await db.customSelect(
    "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?1",
    variables: [Variable<String>(name)],
  ).get();
  return rows.isNotEmpty;
}

Future<bool> _columnExists(
  GeneratedDatabase db,
  String table,
  String column,
) async {
  final rows = await db.customSelect('PRAGMA table_info("$table")').get();
  return rows.any((r) => r.read<String>('name') == column);
}

/// Runs the real [AppDatabase] migration logic but stops at [_version],
/// so a single step can be validated without the later ones running.
class _AppDatabaseAtVersion extends AppDatabase {
  _AppDatabaseAtVersion(super.executor, this._version);

  final int _version;

  @override
  int get schemaVersion => _version;
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
