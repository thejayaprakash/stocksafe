// Phase B behaviour changes: batch quantities derived from the ledger,
// stocktake reconciliation re-derived rather than incremented, duplicate
// barcodes refused, and LIKE escaping that actually escapes.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/data/database.dart';
import 'package:stocksafe/src/services/csv_import_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> newProduct(String name, {String? barcode}) {
    final now = DateTime.now();
    return db.productDao.insertProduct(
      ProductsCompanion.insert(
        name: name,
        barcode: Value(barcode),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  group('Batch quantities are ledger-derived', () {
    test('a batch total is the sum of its movements', () async {
      final productId = await newProduct('Milk 500ml');
      final batchId = await db.batchDao.getOrCreateBatch(
        productId: productId,
        batchNumber: 'B-01',
      );

      for (final delta in [50, -12, -8]) {
        await db.movementDao.recordMovement(
          productId: productId,
          qtyDelta: delta,
          reason: delta > 0 ? 'purchase' : 'sale',
          batchId: batchId,
        );
      }

      final batch = await db.batchDao.getBatchById(batchId);
      expect(batch!.stockQty, 30, reason: '50 - 12 - 8');
      final product = await db.productDao.getById(productId);
      expect(product!.stockQty, 30, reason: 'and the product agrees');
    });

    test('over-deducting records the shortfall instead of erasing it',
        () async {
      // Previously the batch counter was clamped at zero, so deducting more
      // than the batch held silently dropped the difference while the product
      // ledger recorded it in full. The two then disagreed forever.
      final productId = await newProduct('Curd 200g');
      final batchId = await db.batchDao.getOrCreateBatch(
        productId: productId,
        batchNumber: 'B-02',
      );

      await db.movementDao.recordMovement(
        productId: productId,
        qtyDelta: 3,
        reason: 'purchase',
        batchId: batchId,
      );
      await db.movementDao.recordMovement(
        productId: productId,
        qtyDelta: -10,
        reason: 'sale',
        batchId: batchId,
      );

      final batch = await db.batchDao.getBatchById(batchId);
      expect(batch!.stockQty, -7,
          reason: 'a negative batch is information: counted and recorded disagree');

      final product = await db.productDao.getById(productId);
      expect(product!.stockQty, batch.stockQty,
          reason: 'batch and product must never disagree');
    });

    test('rebuildAllStockCaches repairs batch drift', () async {
      final productId = await newProduct('Ghee 1L');
      final batchId = await db.batchDao.getOrCreateBatch(
        productId: productId,
        batchNumber: 'B-03',
      );
      await db.movementDao.recordMovement(
        productId: productId,
        qtyDelta: 25,
        reason: 'purchase',
        batchId: batchId,
      );

      // Corrupt both caches behind the ledger's back.
      await db.customStatement('UPDATE batch SET stock_qty = 999');
      await db.customStatement('UPDATE product SET stock_qty = 999');

      await db.rebuildAllStockCaches();

      expect((await db.batchDao.getBatchById(batchId))!.stockQty, 25,
          reason: 'batches must be repairable, not just products');
      expect((await db.productDao.getById(productId))!.stockQty, 25);
    });

    test('a deleted batch is hidden but its row and ledger survive', () async {
      final productId = await newProduct('Paneer 200g');
      final batchId = await db.batchDao.getOrCreateBatch(
        productId: productId,
        batchNumber: 'B-04',
      );
      await db.movementDao.recordMovement(
        productId: productId,
        qtyDelta: 5,
        reason: 'purchase',
        batchId: batchId,
      );

      await db.batchDao.softDeleteBatch(batchId);

      expect(await db.batchDao.getBatchesForProduct(productId), isEmpty);
      expect(await db.batchDao.getBatchById(batchId), isNull);

      // The row is still physically there, so the ledger's batch_id is not
      // orphaned, and the movement itself is untouched.
      final rows = await db.customSelect('SELECT COUNT(*) AS c FROM batch').getSingle();
      expect(rows.read<int>('c'), 1);
      expect(await db.movementDao.getAllForExport(), hasLength(1));

      await db.batchDao.restoreBatch(batchId);
      expect(await db.batchDao.getBatchById(batchId), isNotNull);
    });
  });

  group('Stocktake reconciliation', () {
    test('re-derives the cache rather than inheriting existing drift',
        () async {
      final productId = await newProduct('Sugar 1kg');
      await db.movementDao.recordMovement(
        productId: productId,
        qtyDelta: 20,
        reason: 'opening_stock',
      );

      // Drift the cache, as a crash mid-write might.
      await db.customStatement('UPDATE product SET stock_qty = 500');

      final sessionId = await db.auditDao.createSession(name: 'Evening count');
      await db.auditDao.recordCount(
        sessionId: sessionId,
        productId: productId,
        countedQty: 18,
        expectedQty: 20,
      );
      await db.auditDao.reconcileSession(sessionId);

      // 20 opening - 2 adjustment = 18, derived from the ledger. The previous
      // implementation added the difference to the cached 500 and produced 498.
      final product = await db.productDao.getById(productId);
      expect(product!.stockQty, 18);

      final movements = await db.movementDao.getAllForExport();
      expect(movements, hasLength(2));
      expect(movements.first.qtyDelta, -2);
      expect(movements.first.auditSessionId, sessionId);
    });

    test('skips a product that no longer exists instead of inventing stock',
        () async {
      final productId = await newProduct('Vanishing item');
      final sessionId = await db.auditDao.createSession(name: 'Count');
      await db.auditDao.recordCount(
        sessionId: sessionId,
        productId: productId,
        countedQty: 5,
        expectedQty: 0,
      );

      // Hard-removed behind the app's back; the audit item cascades away too,
      // so reconciliation must simply find nothing to do.
      await db.customStatement('DELETE FROM product WHERE id = $productId');

      await db.auditDao.reconcileSession(sessionId);

      final session = await db.auditDao.getSession(sessionId);
      expect(session!.status, 'completed');
      expect(await db.movementDao.getAllForExport(), isEmpty);
    });
  });

  group('Barcodes identify one product', () {
    test('a second live product cannot take a barcode already in use',
        () async {
      await newProduct('Rice 5kg', barcode: '8901234567890');
      await expectLater(
        newProduct('Rice 5kg again', barcode: '8901234567890'),
        throwsA(anything),
      );
    });

    test('a soft-deleted product releases its barcode', () async {
      final id = await newProduct('Old stock', barcode: '8901111111111');
      await db.productDao.softDelete(id);

      // Re-adding the same item must work — the index is partial for exactly
      // this reason.
      final newId = await newProduct('New stock', barcode: '8901111111111');
      expect(newId, isNot(id));
    });

    test('products without a barcode do not collide', () async {
      await newProduct('Loose A');
      await newProduct('Loose B');
      expect(await db.productDao.countActive(), 2);
    });

    test('CSV import skips duplicates instead of inserting them', () async {
      const csv = 'Name,Barcode,Initial Stock\n'
          'Rice 5kg,8901234567890,10\n'
          'Rice 5kg (again),8901234567890,5\n'
          'Dal 1kg,8909999999999,7\n';

      final first = await CsvImportService(db).importFromCsvString(csv);
      expect(first.importedCount, 2, reason: 'the in-file duplicate is skipped');
      expect(first.skippedCount, 1);
      expect(first.errors.join(), contains('repeated'));

      // Re-importing the same file must add nothing and must not throw.
      final second = await CsvImportService(db).importFromCsvString(csv);
      expect(second.importedCount, 0);
      expect(await db.productDao.countActive(), 2,
          reason: 'importing twice must not duplicate the catalogue');
    });
  });

  group('Search escaping', () {
    test('a literal % in a product name is findable', () async {
      await newProduct('50% Cocoa Bar');
      await newProduct('Plain Bar');

      // Without an ESCAPE clause the escaped pattern matched nothing.
      final hits = await db.productDao.watchAll(query: '50%').first;
      expect(hits, hasLength(1));
      expect(hits.single.name, '50% Cocoa Bar');
    });

    test('a wildcard typed by the user does not match everything', () async {
      await newProduct('Alpha');
      await newProduct('Beta');

      final hits = await db.productDao.watchAll(query: '%').first;
      expect(hits, isEmpty,
          reason: 'a bare % is a literal character, not "match all"');
    });
  });
}
