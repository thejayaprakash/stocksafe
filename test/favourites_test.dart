// Favourites are a local preference with no network behind them, so the
// only things that can go wrong are the ones pinned here: the filter, the
// count, and the promise that pinning a product does not disturb anything
// else about it.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> add(String name, {DateTime? updatedAt, int qty = 5}) {
    final at = updatedAt ?? DateTime(2026, 9, 1);
    return db.productDao.insertProduct(
      ProductsCompanion.insert(
        name: name,
        stockQty: Value(qty),
        createdAt: at,
        updatedAt: at,
      ),
    );
  }

  test('a new product is not a favourite', () async {
    final id = await add('Amul Ghee');
    expect((await db.productDao.getById(id))!.isFavourite, isFalse);
  });

  test('pinning and unpinning round-trips', () async {
    final id = await add('Amul Ghee');

    await db.productDao.setFavourite(id, true);
    expect((await db.productDao.getById(id))!.isFavourite, isTrue);

    await db.productDao.setFavourite(id, false);
    expect((await db.productDao.getById(id))!.isFavourite, isFalse);
  });

  test('the filter returns only what is pinned', () async {
    final a = await add('Pinned');
    await add('Not pinned');
    await db.productDao.setFavourite(a, true);

    final favourites =
        await db.productDao.watchAll(favouritesOnly: true).first;
    expect(favourites.map((p) => p.name), ['Pinned']);

    // And without the filter, everything is still there.
    expect(await db.productDao.watchAll().first, hasLength(2));
  });

  test('favourites combine with the other filters rather than replacing them',
      () async {
    final empty = await add('Pinned but empty', qty: 0);
    final stocked = await add('Pinned and stocked', qty: 7);
    await add('Stocked, not pinned', qty: 7);
    await db.productDao.setFavourite(empty, true);
    await db.productDao.setFavourite(stocked, true);

    final inStockFavourites = await db.productDao
        .watchAll(
          favouritesOnly: true,
          status: ProductStockStatus.inStock,
        )
        .first;
    expect(inStockFavourites.map((p) => p.name), ['Pinned and stocked']);
  });

  test('select all under the favourites filter picks only favourites',
      () async {
    final a = await add('Pinned');
    await add('Not pinned');
    await db.productDao.setFavourite(a, true);

    expect(await db.productDao.idsMatching(favouritesOnly: true), [a]);
    expect(await db.productDao.idsMatching(), hasLength(2));
  });

  test('the count follows the pins and ignores deleted rows', () async {
    final a = await add('A');
    final b = await add('B');
    await db.productDao.setFavourite(a, true);
    await db.productDao.setFavourite(b, true);
    expect(await db.productDao.watchFavouriteCount().first, 2);

    await db.productDao.softDelete(b);
    expect(await db.productDao.watchFavouriteCount().first, 1,
        reason: 'a deleted product is not a favourite anyone can see');
  });

  test('pinning does not reorder "Recently Updated"', () async {
    // A view preference should not masquerade as a change to the product.
    // If it bumped updatedAt, favouriting something would shove it to the
    // top of a list that is supposed to mean "recently changed".
    final older = await add('Older', updatedAt: DateTime(2026, 1, 1));
    await add('Newer', updatedAt: DateTime(2026, 6, 1));

    await db.productDao.setFavourite(older, true);

    final order = await db.productDao
        .watchAll(sort: ProductSort.recentlyUpdated)
        .first;
    expect(order.map((p) => p.name), ['Newer', 'Older']);
    expect((await db.productDao.getById(older))!.updatedAt,
        DateTime(2026, 1, 1));
  });

  test('a bulk action leaves the pins alone', () async {
    final a = await add('A');
    await db.productDao.setFavourite(a, true);

    await db.productDao.setCategoryMany([a], 'Dairy');
    await db.productDao.setSellPriceMany([a], 42);

    final product = (await db.productDao.getById(a))!;
    expect(product.isFavourite, isTrue);
    expect(product.category, 'Dairy');
    expect(product.sellPrice, 42);
  });
}
