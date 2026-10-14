// The catalogue pages by re-querying a growing window rather than by offset,
// which only works while the order is total. These pin each sort order's
// result and the tiebreaker that makes paging safe.
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> add(
    String name, {
    int qty = 0,
    double buyPrice = 0,
    DateTime? updatedAt,
  }) {
    final at = updatedAt ?? DateTime(2026, 1, 1);
    return db.productDao.insertProduct(
      ProductsCompanion.insert(
        name: name,
        stockQty: Value(qty),
        buyPrice: Value(buyPrice),
        createdAt: at,
        updatedAt: at,
      ),
    );
  }

  Future<List<String>> names(ProductSort sort) async =>
      (await db.productDao.watchAll(sort: sort).first)
          .map((p) => p.name)
          .toList();

  test('name order is alphabetical', () async {
    await add('Zinc tablets');
    await add('Amul Ghee');
    await add('Maggi');

    expect(await names(ProductSort.nameAsc), ['Amul Ghee', 'Maggi', 'Zinc tablets']);
  });

  test('recently updated puts the freshest row first', () async {
    await add('Oldest', updatedAt: DateTime(2026, 1, 1));
    await add('Newest', updatedAt: DateTime(2026, 6, 1));
    await add('Middle', updatedAt: DateTime(2026, 3, 1));

    expect(
      await names(ProductSort.recentlyUpdated),
      ['Newest', 'Middle', 'Oldest'],
    );
  });

  test('lowest stock first puts the empty shelf at the top', () async {
    await add('Plenty', qty: 90);
    await add('Empty', qty: 0);
    await add('Few', qty: 3);

    expect(await names(ProductSort.stockLowFirst), ['Empty', 'Few', 'Plenty']);
  });

  test('highest value is quantity times cost, not quantity alone', () async {
    // 2 × ₹600 beats 50 × ₹10: the order has to multiply, or the expensive
    // stock a shopkeeper most wants to see sinks below the cheap bulk.
    await add('Ghee tins', qty: 2, buyPrice: 600);
    await add('Biscuits', qty: 50, buyPrice: 10);
    await add('Salt', qty: 5, buyPrice: 12);

    expect(await names(ProductSort.valueHigh), ['Ghee tins', 'Biscuits', 'Salt']);
  });

  test('rows that tie are still ordered, so paging cannot repeat or skip',
      () async {
    // Every product identical on the sort key.
    final at = DateTime(2026, 2, 2);
    for (var i = 0; i < 12; i++) {
      await add('Same $i', qty: 5, updatedAt: at);
    }

    for (final sort in ProductSort.values) {
      final firstPage = await db.productDao.watchAll(sort: sort, limit: 6).first;
      final wholeList = await db.productDao.watchAll(sort: sort, limit: 12).first;

      expect(
        firstPage.map((p) => p.id).toList(),
        wholeList.take(6).map((p) => p.id).toList(),
        reason: '$sort reshuffles tied rows between pages',
      );
      expect(wholeList.map((p) => p.id).toSet().length, 12);
    }
  });

  test('a sort order still respects the search and category filters',
      () async {
    final now = DateTime(2026, 5, 5);
    await db.productDao.insertProduct(
      ProductsCompanion.insert(
        name: 'Amul Ghee',
        category: const Value('Dairy'),
        stockQty: const Value(2),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.productDao.insertProduct(
      ProductsCompanion.insert(
        name: 'Aachi Masala',
        category: const Value('Spices'),
        stockQty: const Value(1),
        createdAt: now,
        updatedAt: now,
      ),
    );

    final dairy = await db.productDao
        .watchAll(category: 'Dairy', sort: ProductSort.stockLowFirst)
        .first;
    expect(dairy.map((p) => p.name), ['Amul Ghee']);

    final search = await db.productDao
        .watchAll(query: 'aachi', sort: ProductSort.valueHigh)
        .first;
    expect(search.map((p) => p.name), ['Aachi Masala']);
  });
}
