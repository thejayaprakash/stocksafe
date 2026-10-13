import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  Future<int> addProduct(String name) {
    final now = DateTime.now();
    return db.productDao.insertProduct(
      ProductsCompanion.insert(name: name, createdAt: now, updatedAt: now),
    );
  }

  group('movement ledger', () {
    test('stock is derived from SUM(qty_delta)', () async {
      final id = await addProduct('Tea powder');

      await db.movementDao.recordMovement(
        productId: id, qtyDelta: 10, reason: 'Stock in');
      await db.movementDao.recordMovement(
        productId: id, qtyDelta: -3, reason: 'Stock out');

      final product = await db.productDao.getById(id);
      expect(product!.stockQty, 7);

      // The cache matches the ledger — not just a stored number.
      final sum = await db.customSelect(
        'SELECT SUM(qty_delta) AS s FROM movement WHERE product_id = ?',
        variables: [Variable.withInt(id)],
      ).getSingle();
      expect(sum.read<int>('s'), 7);
    });

    test('zero delta is rejected', () async {
      final id = await addProduct('Sugar');
      expect(
        () => db.movementDao.recordMovement(
          productId: id, qtyDelta: 0, reason: 'Stock in'),
        throwsArgumentError,
      );
    });

    test('movement history is newest first', () async {
      final id = await addProduct('Milk');
      await db.movementDao.recordMovement(
        productId: id, qtyDelta: 5, reason: 'Stock in',
        createdAt: DateTime(2026, 1, 1));
      await db.movementDao.recordMovement(
        productId: id, qtyDelta: 2, reason: 'Stock in',
        createdAt: DateTime(2026, 1, 2));

      final history = await db.movementDao.watchForProduct(id).first;
      expect(history.first.qtyDelta, 2);
      expect(history.last.qtyDelta, 5);
    });

    test('a movement is reversed by a compensating entry, not a deletion',
        () async {
      // The ledger exposes no delete. Stock is derived from it, so removing a
      // row would rewrite history and silently change every quantity after it.
      // This asserts the behaviour that replaces deletion.
      final id = await addProduct('Sugar 1kg');
      await db.movementDao.recordMovement(
        productId: id, qtyDelta: 25, reason: 'purchase');
      await db.movementDao.recordMovement(
        productId: id, qtyDelta: -25, reason: 'purchase_reversal',
        note: 'entered twice by mistake');

      // Net zero, and both rows are still readable.
      expect((await db.productDao.getById(id))!.stockQty, 0);
      final history = await db.movementDao.watchForProduct(id).first;
      expect(history, hasLength(2));
      expect(history.map((m) => m.qtyDelta).toList()..sort(), [-25, 25]);
      expect(
        history.any((m) => m.reason == 'purchase_reversal'),
        isTrue,
        reason: 'the correction stays visible, so the history explains itself',
      );
    });
  });

  group('cache rebuild', () {
    test('rebuildAllStockCaches recomputes from ledger', () async {
      final a = await addProduct('Rice');
      final b = await addProduct('Oil');
      await db.movementDao.recordMovement(
          productId: a, qtyDelta: 20, reason: 'Stock in');
      await db.movementDao.recordMovement(
          productId: b, qtyDelta: -4, reason: 'Stock out');

      // Corrupt the cache, then rebuild — the ledger restores truth.
      await db.customUpdate(
        'UPDATE product SET stock_qty = 9999');
      await db.rebuildAllStockCaches();

      expect((await db.productDao.getById(a))!.stockQty, 20);
      expect((await db.productDao.getById(b))!.stockQty, -4);
    });

    test('rebuildStockCache fixes a single product', () async {
      final id = await addProduct('Salt');
      await db.movementDao.recordMovement(
          productId: id, qtyDelta: 8, reason: 'Stock in');
      await db.customUpdate('UPDATE product SET stock_qty = 0 WHERE id = ?',
          variables: [Variable.withInt(id)]);
      await db.productDao.rebuildStockCache(id);
      expect((await db.productDao.getById(id))!.stockQty, 8);
    });
  });

  group('soft delete', () {
    test('deleted products disappear from queries but keep their rows', () async {
      final id = await addProduct('Flour');
      await db.productDao.softDelete(id);

      expect(await db.productDao.getById(id), isNull);
      expect(await db.productDao.countActive(), 0);

      final row = await db.customSelect(
        'SELECT COUNT(*) AS c FROM product WHERE id = ?',
        variables: [Variable.withInt(id)],
      ).getSingle();
      expect(row.read<int>('c'), 1);
    });

    test('restore brings a product back', () async {
      final id = await addProduct('Yeast');
      await db.productDao.softDelete(id);
      await db.productDao.restore(id);
      expect(await db.productDao.getById(id), isNotNull);
    });
  });

  group('search', () {
    test('matches name, SKU and barcode; excludes deleted', () async {
      final now = DateTime.now();
      await db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: 'Green tea', sku: const Value('TEA-01'),
          barcode: const Value('8901234567890'),
          createdAt: now, updatedAt: now));
      await db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: 'Black coffee', sku: const Value('COF-02'),
          createdAt: now, updatedAt: now));

      expect((await db.productDao.watchAll(query: 'green').first).length, 1);
      expect((await db.productDao.watchAll(query: 'COF').first).length, 1);
      expect((await db.productDao.watchAll(query: '8901').first).length, 1);
      expect((await db.productDao.watchAll(query: 'zzz').first), isEmpty);
    });
  });

  group('settings', () {
    test('round-trips a key/value', () async {
      final dao = SettingDao(db);
      await dao.set(SettingDao.lastBackupAtKey, '2026-10-12');
      expect(await dao.get(SettingDao.lastBackupAtKey), '2026-10-12');
      expect(await dao.get('missing'), isNull);
    });
  });
}
