// Stock held at more than one place.
//
// Modelled on what enterprise inventory systems actually do: Odoo moves
// quantities between locations so nothing is created or destroyed, NetSuite
// and Zoho Inventory hold a separate balance per warehouse. StockSafe keeps
// its signed-delta ledger and partitions it, so the product total is the same
// sum it always was — just no longer the only answer available.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> newProduct(String name) {
    final now = DateTime.now();
    return db.productDao.insertProduct(
      ProductsCompanion.insert(name: name, createdAt: now, updatedAt: now),
    );
  }

  group('A single-shop user never sees this', () {
    test('a fresh database has exactly one default location', () async {
      final def = await db.locationDao.getOrCreateDefault();
      expect(def.name, DatabaseMigrations.defaultLocationName);
      expect(def.isDefault, isTrue);
      expect(await db.locationDao.getAll(), hasLength(1));
    });

    test('movements land at the default without being told', () async {
      final id = await newProduct('Rice 5kg');
      await db.movementDao.recordMovement(
        productId: id, qtyDelta: 20, reason: 'purchase');

      final def = await db.locationDao.getOrCreateDefault();
      expect(await db.locationDao.stockOf(id, def.id), 20);
      expect((await db.productDao.getById(id))!.stockQty, 20);
    });
  });

  group('Balances per location', () {
    late int productId;
    late int shop;
    late int godown;

    setUp(() async {
      productId = await newProduct('Sugar 1kg');
      shop = (await db.locationDao.getOrCreateDefault()).id;
      godown = await db.locationDao.createLocation(name: 'Godown');
    });

    test('each location answers for itself, and the product for the whole',
        () async {
      await db.movementDao.recordMovement(
        productId: productId, qtyDelta: 30, reason: 'purchase', locationId: shop);
      await db.movementDao.recordMovement(
        productId: productId, qtyDelta: 100, reason: 'purchase', locationId: godown);
      await db.movementDao.recordMovement(
        productId: productId, qtyDelta: -12, reason: 'sale', locationId: shop);

      expect(await db.locationDao.stockOf(productId, shop), 18);
      expect(await db.locationDao.stockOf(productId, godown), 100);
      // The product total is the same sum it always was.
      expect((await db.productDao.getById(productId))!.stockQty, 118);
    });

    test('the breakdown omits places holding nothing', () async {
      final spare = await db.locationDao.createLocation(name: 'Spare room');
      await db.movementDao.recordMovement(
        productId: productId, qtyDelta: 5, reason: 'purchase', locationId: shop);

      final rows = await db.locationDao.watchBreakdownFor(productId).first;
      expect(rows, hasLength(1), reason: 'answers "where is it", not "list everywhere"');
      expect(rows.single.locationId, shop);
      expect(rows.single.quantity, 5);
      expect(rows.map((r) => r.locationId), isNot(contains(spare)));
      expect(rows.map((r) => r.locationId), isNot(contains(godown)));
    });
  });

  group('Transfers conserve quantity', () {
    late int productId;
    late int shop;
    late int godown;

    setUp(() async {
      productId = await newProduct('Dal 1kg');
      shop = (await db.locationDao.getOrCreateDefault()).id;
      godown = await db.locationDao.createLocation(name: 'Godown');
      await db.movementDao.recordMovement(
        productId: productId, qtyDelta: 50, reason: 'purchase', locationId: godown);
    });

    test('moves stock without changing the total', () async {
      final before = (await db.productDao.getById(productId))!.stockQty;

      await db.movementDao.transferStock(
        productId: productId,
        fromLocationId: godown,
        toLocationId: shop,
        quantity: 20,
      );

      expect(await db.locationDao.stockOf(productId, godown), 30);
      expect(await db.locationDao.stockOf(productId, shop), 20);
      expect((await db.productDao.getById(productId))!.stockQty, before,
          reason: 'nothing entered or left the business, it only moved');
    });

    test('writes a matched, linked pair', () async {
      final ref = await db.movementDao.transferStock(
        productId: productId,
        fromLocationId: godown,
        toLocationId: shop,
        quantity: 15,
      );

      final rows = await db.customSelect(
        'SELECT qty_delta, location_id, reason FROM movement '
        'WHERE transfer_ref = ?1 ORDER BY qty_delta',
        variables: [Variable<String>(ref)],
      ).get();

      expect(rows, hasLength(2));
      expect(rows[0].read<int>('qty_delta'), -15);
      expect(rows[1].read<int>('qty_delta'), 15);
      expect(rows[0].read<int>('location_id'), godown);
      expect(rows[1].read<int>('location_id'), shop);
      // The pair sums to zero, which is why the product total is untouched.
      expect(
        rows.fold<int>(0, (sum, r) => sum + r.read<int>('qty_delta')),
        0,
      );
    });

    test('refuses a transfer to the same place', () async {
      await expectLater(
        db.movementDao.transferStock(
          productId: productId,
          fromLocationId: godown,
          toLocationId: godown,
          quantity: 5,
        ),
        throwsArgumentError,
      );
    });

    test('refuses a zero or negative quantity', () async {
      for (final qty in [0, -5]) {
        await expectLater(
          db.movementDao.transferStock(
            productId: productId,
            fromLocationId: godown,
            toLocationId: shop,
            quantity: qty,
          ),
          throwsArgumentError,
        );
      }
      expect(await db.movementDao.getAllForExport(), hasLength(1),
          reason: 'a refused transfer writes nothing');
    });

    test('moving more than a location holds records the shortfall', () async {
      // Deliberately allowed: the stock physically moved, and refusing would
      // stop the user recording something that already happened. A negative
      // balance is the signal that counted and recorded stock disagree.
      await db.movementDao.transferStock(
        productId: productId,
        fromLocationId: shop, // holds nothing
        toLocationId: godown,
        quantity: 10,
      );

      expect(await db.locationDao.stockOf(productId, shop), -10);
      expect(await db.locationDao.stockOf(productId, godown), 60);
      expect((await db.productDao.getById(productId))!.stockQty, 50);
    });
  });

  group('Removing a location cannot strand stock', () {
    test('refuses while it still holds stock', () async {
      final productId = await newProduct('Ghee 1L');
      // A second location must exist, or the "last location" guard fires
      // first and this would pass for the wrong reason — both refusals throw
      // StateError, so the message is what distinguishes them.
      await db.locationDao.getOrCreateDefault();
      final godown = await db.locationDao.createLocation(name: 'Godown');
      await db.movementDao.recordMovement(
        productId: productId, qtyDelta: 9, reason: 'purchase', locationId: godown);

      await expectLater(
        db.locationDao.softDelete(godown),
        throwsA(isA<StateError>().having(
          (e) => e.message, 'message', contains('still holds stock'))),
      );
      expect(await db.locationDao.getAll(), hasLength(2));
    });

    test('allows it once empty, and keeps the history', () async {
      final productId = await newProduct('Ghee 1L');
      final shop = (await db.locationDao.getOrCreateDefault()).id;
      final godown = await db.locationDao.createLocation(name: 'Godown');
      await db.movementDao.recordMovement(
        productId: productId, qtyDelta: 9, reason: 'purchase', locationId: godown);
      await db.movementDao.transferStock(
        productId: productId,
        fromLocationId: godown,
        toLocationId: shop,
        quantity: 9,
      );

      await db.locationDao.softDelete(godown);

      expect(await db.locationDao.getAll(), hasLength(1));
      // Soft delete: the ledger still references it, so the row stays.
      final rows = await db.customSelect(
        'SELECT COUNT(*) AS c FROM location').getSingle();
      expect(rows.read<int>('c'), 2);
      expect(await db.movementDao.getAllForExport(), hasLength(3));
    });

    test('refuses to remove the last location', () async {
      final only = (await db.locationDao.getOrCreateDefault()).id;
      await expectLater(
        db.locationDao.softDelete(only),
        throwsA(isA<StateError>().having(
          (e) => e.message, 'message', contains('at least one location'))),
      );
    });

    test('removing the default promotes another', () async {
      final shop = (await db.locationDao.getOrCreateDefault()).id;
      final godown = await db.locationDao.createLocation(name: 'Godown');

      await db.locationDao.softDelete(shop);

      final def = await db.locationDao.getOrCreateDefault();
      expect(def.id, godown);
      expect(def.isDefault, isTrue);
    });
  });

  group('Exactly one default', () {
    test('setting a new default clears the old one', () async {
      final shop = (await db.locationDao.getOrCreateDefault()).id;
      final godown = await db.locationDao.createLocation(name: 'Godown');

      await db.locationDao.setDefault(godown);

      final all = await db.locationDao.getAll();
      expect(all.where((l) => l.isDefault).map((l) => l.id), [godown]);
      expect((await db.locationDao.getById(shop))!.isDefault, isFalse);
    });
  });
}
