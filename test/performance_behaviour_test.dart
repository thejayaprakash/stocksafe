// Phase D changed *how* things are computed, not what they mean. These tests
// pin the meaning, so an optimisation cannot quietly change an answer.
//
// The speed itself is measured in performance_test.dart, which is opt-in.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/data/database.dart';
import 'package:stocksafe/src/services/diagnostic_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> newProduct(String name, {double buy = 0, double sell = 0}) {
    final now = DateTime.now();
    return db.productDao.insertProduct(
      ProductsCompanion.insert(
        name: name,
        buyPrice: Value(buy),
        sellPrice: Value(sell),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  group('Ledger integrity audit', () {
    // Rewritten from one SUM query per product into a single grouped join.
    test('reports nothing when every cache matches the ledger', () async {
      for (var i = 0; i < 5; i++) {
        final id = await newProduct('Product $i');
        await db.movementDao.recordMovement(
          productId: id,
          qtyDelta: 10 + i,
          reason: 'purchase',
        );
      }

      final mismatches =
          await DiagnosticService.instance.auditLedgerIntegrity(db);
      expect(mismatches, isEmpty);
    });

    test('finds exactly the drifted products, with both values', () async {
      final good = await newProduct('Correct');
      final bad = await newProduct('Drifted');
      for (final id in [good, bad]) {
        await db.movementDao.recordMovement(
          productId: id,
          qtyDelta: 20,
          reason: 'purchase',
        );
      }
      await db.customStatement('UPDATE product SET stock_qty = 77 WHERE id = $bad');

      final mismatches =
          await DiagnosticService.instance.auditLedgerIntegrity(db);

      expect(mismatches, hasLength(1));
      expect(mismatches.single.productId, bad);
      expect(mismatches.single.productName, 'Drifted');
      expect(mismatches.single.cachedStock, 77);
      expect(mismatches.single.ledgerStock, 20);
      expect(mismatches.single.discrepancy, 57);
    });

    test('a product with no movements is sound only when cached at zero',
        () async {
      // The LEFT JOIN must treat "no rows" as 0, not drop the product.
      final id = await newProduct('Never stocked');
      expect(await DiagnosticService.instance.auditLedgerIntegrity(db), isEmpty);

      await db.customStatement('UPDATE product SET stock_qty = 5 WHERE id = $id');
      final mismatches =
          await DiagnosticService.instance.auditLedgerIntegrity(db);
      expect(mismatches, hasLength(1));
      expect(mismatches.single.ledgerStock, 0);
    });

    test('ignores soft-deleted products', () async {
      final id = await newProduct('Deleted');
      await db.movementDao.recordMovement(
        productId: id,
        qtyDelta: 9,
        reason: 'purchase',
      );
      await db.customStatement('UPDATE product SET stock_qty = 999 WHERE id = $id');
      await db.productDao.softDelete(id);

      expect(await DiagnosticService.instance.auditLedgerIntegrity(db), isEmpty,
          reason: 'a removed product is not a live inconsistency');
    });
  });

  group('Inventory valuation', () {
    // Moved from a Dart loop over every product into one SQL aggregate.
    test('sums cost, retail, margin and units over positive stock only',
        () async {
      final a = await newProduct('A', buy: 10, sell: 15);
      final b = await newProduct('B', buy: 20, sell: 25);
      await newProduct('Never stocked', buy: 99, sell: 199);

      await db.movementDao.recordMovement(
        productId: a, qtyDelta: 3, reason: 'purchase');
      await db.movementDao.recordMovement(
        productId: b, qtyDelta: 2, reason: 'purchase');

      final v = await db.productDao.getInventoryValuation();

      expect(v.totalProducts, 3, reason: 'counts the catalogue, not just stock');
      expect(v.totalUnits, 5);
      expect(v.totalCostValue, closeTo(3 * 10 + 2 * 20, 0.001));
      expect(v.totalRetailValue, closeTo(3 * 15 + 2 * 25, 0.001));
      expect(v.potentialProfit, closeTo(25, 0.001));
      expect(v.marginPercent, closeTo(25 / 70 * 100, 0.001));
    });

    test('negative stock is excluded rather than subtracted', () async {
      // A negative quantity means counted and recorded disagree. Letting it
      // reduce the valuation would report a number that is wrong in a new way.
      final a = await newProduct('Positive', buy: 10, sell: 12);
      final b = await newProduct('Oversold', buy: 10, sell: 12);
      await db.movementDao.recordMovement(
        productId: a, qtyDelta: 4, reason: 'purchase');
      await db.movementDao.recordMovement(
        productId: b, qtyDelta: -3, reason: 'sale');

      final v = await db.productDao.getInventoryValuation();
      expect(v.totalUnits, 4);
      expect(v.totalCostValue, closeTo(40, 0.001));
    });

    test('an empty catalogue reports zeroes, not an error', () async {
      final v = await db.productDao.getInventoryValuation();
      expect(v.totalProducts, 0);
      expect(v.totalUnits, 0);
      expect(v.totalCostValue, 0);
      expect(v.marginPercent, 0);
    });
  });

  group('Product list paging', () {
    test('a growing window reaches every product', () async {
      // The list used to call watchAll() with its default limit of 100 and
      // never advance, so products beyond the first 100 were invisible.
      for (var i = 0; i < 250; i++) {
        await newProduct('Item ${i.toString().padLeft(4, '0')}');
      }

      final firstPage = await db.productDao.watchAll(limit: 60).first;
      expect(firstPage, hasLength(60));

      final seen = <int>{};
      for (var limit = 60; limit <= 300; limit += 60) {
        final window = await db.productDao.watchAll(limit: limit).first;
        seen.addAll(window.map((p) => p.id));
      }
      expect(seen, hasLength(250), reason: 'every product must be reachable');
    });

    test('a window larger than the catalogue returns everything once',
        () async {
      for (var i = 0; i < 10; i++) {
        await newProduct('Item $i');
      }
      final all = await db.productDao.watchAll(limit: 500).first;
      expect(all, hasLength(10));
      expect(all.map((p) => p.id).toSet(), hasLength(10));
    });

    test('the window stays ordered by name as it grows', () async {
      for (final name in ['Zebra', 'Apple', 'Mango', 'Banana']) {
        await newProduct(name);
      }
      final page = await db.productDao.watchAll(limit: 10).first;
      expect(page.map((p) => p.name).toList(),
          ['Apple', 'Banana', 'Mango', 'Zebra']);
    });
  });
}
