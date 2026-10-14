// The status filters decide what a shopkeeper is shown when they ask "what
// is running out". Getting the boundaries wrong either hides a product that
// needs reordering or buries it among every product in the shop.
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> add(
    String name, {
    required int qty,
    int lowAt = 0,
    String? category,
    int? supplierId,
  }) async {
    final now = DateTime(2026, 4, 1);
    await db.productDao.insertProduct(
      ProductsCompanion.insert(
        name: name,
        category: Value(category),
        stockQty: Value(qty),
        lowStockLevel: Value(lowAt),
        supplierId: Value(supplierId),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<List<String>> namesFor(ProductStockStatus status) async =>
      (await db.productDao.watchAll(status: status).first)
          .map((p) => p.name)
          .toList();

  group('stock status', () {
    setUp(() async {
      await add('Plenty', qty: 90, lowAt: 10);
      await add('Exactly at threshold', qty: 10, lowAt: 10);
      await add('Below threshold', qty: 3, lowAt: 10);
      await add('Empty', qty: 0, lowAt: 10);
      await add('Negative', qty: -2, lowAt: 10);
      await add('No threshold set', qty: 1);
    });

    test('in stock means more than zero', () async {
      expect(
        await namesFor(ProductStockStatus.inStock),
        containsAll(['Plenty', 'Exactly at threshold', 'Below threshold']),
      );
      expect(await namesFor(ProductStockStatus.inStock),
          isNot(contains('Empty')));
      expect(await namesFor(ProductStockStatus.inStock),
          isNot(contains('Negative')));
    });

    test('at the threshold counts as low, not as fine', () async {
      // "at or below" is what the alert itself means, and a product sitting
      // exactly on its reorder point is the one worth catching.
      expect(
        await namesFor(ProductStockStatus.low),
        containsAll(['Exactly at threshold', 'Below threshold']),
      );
    });

    test('low excludes what has already run out', () async {
      // Out of stock is a different problem: there is nothing left to sell
      // while the order arrives, and it belongs in its own filter.
      final low = await namesFor(ProductStockStatus.low);
      expect(low, isNot(contains('Empty')));
      expect(low, isNot(contains('Negative')));
    });

    test('a product with no threshold is never low', () async {
      // lowStockLevel is 0 when the shopkeeper never set one. Treating 0 as
      // a threshold made every product in the shop low.
      expect(
        await namesFor(ProductStockStatus.low),
        isNot(contains('No threshold set')),
      );
    });

    test('out of stock includes a negative balance', () async {
      // The ledger can go negative when stock is sold before the delivery is
      // recorded. It is still nothing on the shelf.
      expect(
        await namesFor(ProductStockStatus.outOfStock),
        containsAll(['Empty', 'Negative']),
      );
    });

    test('any returns everything', () async {
      expect(await namesFor(ProductStockStatus.any), hasLength(6));
    });
  });

  group('counts behind the chips', () {
    test('every product falls into exactly one of in-stock or out', () async {
      await add('A', qty: 5, lowAt: 2);
      await add('B', qty: 1, lowAt: 4);
      await add('C', qty: 0, lowAt: 4);

      final counts = await db.productDao.watchStatusCounts().first;
      expect(counts.all, 3);
      expect(counts.inStock + counts.outOfStock, counts.all);
      // Low is a subset of in-stock, not a fourth bucket.
      expect(counts.low, 1);
      expect(counts.inStock, 2);
      expect(counts.outOfStock, 1);
    });

    test('a soft-deleted product is counted nowhere', () async {
      await add('Kept', qty: 4);
      await add('Removed', qty: 4);
      await db.productDao.softDelete(2);

      final counts = await db.productDao.watchStatusCounts().first;
      expect(counts.all, 1);
      expect(counts.inStock, 1);
    });
  });

  test('status, category and search narrow together', () async {
    await add('Amul Ghee', qty: 2, lowAt: 5, category: 'Dairy');
    await add('Amul Butter', qty: 50, lowAt: 5, category: 'Dairy');
    await add('Aachi Masala', qty: 1, lowAt: 5, category: 'Spices');

    final lowDairy = await db.productDao
        .watchAll(category: 'Dairy', status: ProductStockStatus.low)
        .first;
    expect(lowDairy.map((p) => p.name), ['Amul Ghee']);

    final lowSearch = await db.productDao
        .watchAll(query: 'amul', status: ProductStockStatus.low)
        .first;
    expect(lowSearch.map((p) => p.name), ['Amul Ghee']);
  });

  test('the supplier filter narrows to one vendor', () async {
    final now = DateTime(2026, 4, 1);
    final supplier = await db.supplierDao.insertSupplier(
      SuppliersCompanion.insert(
        name: 'ABC Distributors',
        phone: '9000000000',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await add('From ABC', qty: 5, supplierId: supplier);
    await add('From nobody', qty: 5);

    final rows =
        await db.productDao.watchAll(supplierId: supplier).first;
    expect(rows.map((p) => p.name), ['From ABC']);
  });
}
