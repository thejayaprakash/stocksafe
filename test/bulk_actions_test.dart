// Bulk actions touch many rows at once, which is exactly why they are the
// ones worth testing: a mistake here is a mistake repeated across the whole
// catalogue, and two of them write to an append-only ledger.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/data/database.dart';
import 'package:stocksafe/src/services/diagnostic_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> add(
    String name, {
    String? category,
    double sellPrice = 0,
    double buyPrice = 0,
  }) {
    final now = DateTime(2026, 7, 1);
    return db.productDao.insertProduct(
      ProductsCompanion.insert(
        name: name,
        category: Value(category),
        sellPrice: Value(sellPrice),
        buyPrice: Value(buyPrice),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  group('bulk delete', () {
    test('removes every selected product and leaves the rest', () async {
      final a = await add('A');
      final b = await add('B');
      await add('C');

      await db.productDao.softDeleteMany([a, b]);

      final live = await db.productDao.watchAll().first;
      expect(live.map((p) => p.name), ['C']);
    });

    test('is a soft delete: the ledger survives and the row can come back',
        () async {
      final id = await add('Amul Ghee');
      await db.movementDao
          .recordMovement(productId: id, qtyDelta: 9, reason: 'purchase');

      await db.productDao.softDeleteMany([id]);
      expect(await db.productDao.getById(id), isNull);

      // The movements are still there — that is the promise the confirmation
      // dialog makes.
      final history = await db.movementDao.watchForProduct(id).first;
      expect(history, hasLength(1));

      await db.productDao.restore(id);
      final restored = await db.productDao.getById(id);
      expect(restored, isNotNull);
      expect(restored!.name, 'Amul Ghee');
    });

    test('an empty selection does nothing at all', () async {
      await add('Untouched');
      await db.productDao.softDeleteMany(const []);
      expect(await db.productDao.watchAll().first, hasLength(1));
    });

    test('a repeated id is handled once', () async {
      final id = await add('A');
      await db.productDao.softDeleteMany([id, id, id]);
      expect(await db.productDao.watchAll().first, isEmpty);
    });
  });

  group('bulk category', () {
    test('moves every selected product', () async {
      final a = await add('A', category: 'Spices');
      final b = await add('B');
      final c = await add('C', category: 'Dairy');

      await db.productDao.setCategoryMany([a, b], 'Beverages');

      expect((await db.productDao.getById(a))!.category, 'Beverages');
      expect((await db.productDao.getById(b))!.category, 'Beverages');
      // Not in the selection, so untouched.
      expect((await db.productDao.getById(c))!.category, 'Dairy');
    });

    test('a blank category clears it rather than storing an empty string',
        () async {
      // A bad CSV import puts the wrong category on everything, and the way
      // out is to empty it. An empty string would show as a blank chip.
      final a = await add('A', category: 'Wrong');
      await db.productDao.setCategoryMany([a], '   ');
      expect((await db.productDao.getById(a))!.category, isNull);

      final b = await add('B', category: 'Wrong');
      await db.productDao.setCategoryMany([b], null);
      expect((await db.productDao.getById(b))!.category, isNull);
    });

    test('surrounding whitespace is trimmed', () async {
      final a = await add('A');
      await db.productDao.setCategoryMany([a], '  Grains  ');
      expect((await db.productDao.getById(a))!.category, 'Grains');
    });
  });

  group('bulk price', () {
    test('sets the sell price and never touches the cost', () async {
      final a = await add('A', sellPrice: 10, buyPrice: 7);
      final b = await add('B', sellPrice: 99, buyPrice: 60);

      await db.productDao.setSellPriceMany([a, b], 25);

      final first = (await db.productDao.getById(a))!;
      final second = (await db.productDao.getById(b))!;
      expect(first.sellPrice, 25);
      expect(second.sellPrice, 25);
      // The buy price is what each product actually cost — per-product
      // history that a bulk price change has no business rewriting.
      expect(first.buyPrice, 7);
      expect(second.buyPrice, 60);
    });

    test('a negative price is refused', () async {
      final a = await add('A', sellPrice: 10);
      expect(
        () => db.productDao.setSellPriceMany([a], -1),
        throwsArgumentError,
      );
      expect((await db.productDao.getById(a))!.sellPrice, 10);
    });
  });

  group('bulk stock adjustment', () {
    test('applies the delta to each product, not split between them',
        () async {
      final a = await add('A');
      final b = await add('B');

      await db.movementDao.recordMovementForAll(
        productIds: [a, b],
        qtyDelta: 5,
        reason: 'purchase',
      );

      expect((await db.productDao.getById(a))!.stockQty, 5);
      expect((await db.productDao.getById(b))!.stockQty, 5);
    });

    test('writes one ledger row per product, and the cache agrees with it',
        () async {
      final a = await add('A');
      await db.movementDao
          .recordMovement(productId: a, qtyDelta: 20, reason: 'purchase');

      await db.movementDao.recordMovementForAll(
        productIds: [a],
        qtyDelta: -3,
        reason: 'damage',
      );

      final history = await db.movementDao.watchForProduct(a).first;
      expect(history, hasLength(2));
      expect((await db.productDao.getById(a))!.stockQty, 17);

      // The cache is only ever a convenience; the ledger is the truth, and
      // the two must not have drifted.
      final mismatches =
          await DiagnosticService.instance.auditLedgerIntegrity(db);
      expect(mismatches, isEmpty);
    });

    test('a zero delta is refused rather than written as a no-op row',
        () async {
      final a = await add('A');
      expect(
        () => db.movementDao.recordMovementForAll(
          productIds: [a],
          qtyDelta: 0,
          reason: 'purchase',
        ),
        throwsArgumentError,
      );
      expect(await db.movementDao.watchForProduct(a).first, isEmpty);
    });

    test('an empty selection writes nothing', () async {
      await db.movementDao.recordMovementForAll(
        productIds: const [],
        qtyDelta: 5,
        reason: 'purchase',
      );
      expect(await db.movementDao.watchRecent().first, isEmpty);
    });

    test('a product named twice moves once', () async {
      // The selection is a Set in the UI, but the DAO is the thing that has
      // to hold: counting a product twice would double its stock.
      final a = await add('A');
      await db.movementDao.recordMovementForAll(
        productIds: [a, a],
        qtyDelta: 4,
        reason: 'purchase',
      );
      expect((await db.productDao.getById(a))!.stockQty, 4);
      expect(await db.movementDao.watchForProduct(a).first, hasLength(1));
    });
  });
}
