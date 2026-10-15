// Multi-category and supplier filtering, and the ProductFilters value the
// screen keeps them in. The catalogue reopens its query whenever that value
// changes, so its equality is load-bearing, not decoration.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/data/database.dart';
import 'package:stocksafe/src/ui/widgets/product_filter_sheet.dart';

void main() {
  group('ProductFilters', () {
    test('counts ticked categories as one filter, not one each', () {
      // The badge answers "how much am I hiding"; six ticked categories is
      // still one decision the user made.
      const none = ProductFilters();
      expect(none.activeCount, 0);
      expect(none.isEmpty, isTrue);

      const several = ProductFilters(categories: {'Dairy', 'Spices', 'Grains'});
      expect(several.activeCount, 1);
      expect(several.isEmpty, isFalse);
    });

    test('each other filter adds one', () {
      const all = ProductFilters(
        categories: {'Dairy'},
        supplierId: 3,
        status: ProductStockStatus.low,
        favouritesOnly: true,
      );
      expect(all.activeCount, 4);
    });

    test('two filters with the same categories in a different order are equal',
        () {
      const a = ProductFilters(categories: {'Dairy', 'Spices'});
      const b = ProductFilters(categories: {'Spices', 'Dairy'});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differing filters are not equal', () {
      const base = ProductFilters(categories: {'Dairy'});
      expect(base, isNot(const ProductFilters(categories: {'Spices'})));
      expect(base, isNot(const ProductFilters(categories: {'Dairy'}, supplierId: 1)));
      expect(
        base,
        isNot(const ProductFilters(
          categories: {'Dairy'},
          status: ProductStockStatus.low,
        )),
      );
    });

    test('clearing the supplier is distinguishable from not passing one', () {
      // copyWith cannot tell null-the-value from null-the-omission, which is
      // why clearSupplier exists. Without it the filter could never be
      // undone.
      const withSupplier = ProductFilters(supplierId: 7);
      expect(withSupplier.copyWith(status: ProductStockStatus.low).supplierId, 7);
      expect(withSupplier.copyWith(clearSupplier: true).supplierId, isNull);
    });
  });

  group('the query behind them', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<int> add(String name, {String? category, int? supplierId}) {
      final now = DateTime(2026, 10, 1);
      return db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: name,
          category: Value(category),
          supplierId: Value(supplierId),
          stockQty: const Value(5),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    test('several categories are a union, not an impossible intersection',
        () async {
      await add('Ghee', category: 'Dairy');
      await add('Masala', category: 'Spices');
      await add('Rice', category: 'Grains');

      final rows = await db.productDao
          .watchAll(categories: {'Dairy', 'Spices'}).first;
      expect(rows.map((p) => p.name), ['Ghee', 'Masala']);
    });

    test('an empty set means every category', () async {
      await add('Ghee', category: 'Dairy');
      await add('Uncategorised');

      expect(await db.productDao.watchAll(categories: const {}).first,
          hasLength(2));
    });

    test('a single category still works through either spelling', () async {
      await add('Ghee', category: 'Dairy');
      await add('Masala', category: 'Spices');

      final viaChip = await db.productDao.watchAll(category: 'Dairy').first;
      final viaSheet =
          await db.productDao.watchAll(categories: const {'Dairy'}).first;
      expect(viaChip.map((p) => p.name), ['Ghee']);
      expect(viaSheet.map((p) => p.name), ['Ghee']);
    });

    test('blank entries in the set are ignored rather than matching nothing',
        () async {
      // A category cleared in bulk leaves rows with null, and an empty
      // string must not be treated as a category to match on.
      await add('Ghee', category: 'Dairy');
      await add('Masala', category: 'Spices');

      final rows =
          await db.productDao.watchAll(categories: const {'Dairy', '  '}).first;
      expect(rows.map((p) => p.name), ['Ghee']);
    });

    test('supplier and category narrow together', () async {
      final now = DateTime(2026, 10, 1);
      final abc = await db.supplierDao.insertSupplier(
        SuppliersCompanion.insert(
          name: 'ABC',
          phone: '900',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await add('Ghee from ABC', category: 'Dairy', supplierId: abc);
      await add('Ghee from nobody', category: 'Dairy');
      await add('Masala from ABC', category: 'Spices', supplierId: abc);

      final rows = await db.productDao
          .watchAll(categories: const {'Dairy'}, supplierId: abc)
          .first;
      expect(rows.map((p) => p.name), ['Ghee from ABC']);
    });

    test('select all sees the same rows the list does', () async {
      // These share a where clause precisely so they cannot disagree:
      // select-all quietly picking up a product the user cannot see is the
      // kind of bug that surfaces after a bulk delete.
      await add('Ghee', category: 'Dairy');
      await add('Butter', category: 'Dairy');
      await add('Masala', category: 'Spices');

      const categories = {'Dairy'};
      final listed = await db.productDao.watchAll(categories: categories).first;
      final selectable =
          await db.productDao.idsMatching(categories: categories);
      // Membership, not order: the list is sorted for reading and the ids
      // for cheapness, and a selection is a set either way.
      expect(selectable.toSet(), listed.map((p) => p.id).toSet());
      expect(selectable, hasLength(2));
    });

    test('category counts cover live rows only, and ignore blanks', () async {
      await add('Ghee', category: 'Dairy');
      await add('Butter', category: 'Dairy');
      await add('Masala', category: 'Spices');
      await add('Uncategorised');
      final doomed = await add('Removed', category: 'Dairy');
      await db.productDao.softDelete(doomed);

      final counts = await db.productDao.watchCategoryCounts().first;
      expect(counts, {'Dairy': 2, 'Spices': 1});
    });

    test('the counts come back alphabetically', () async {
      await add('A', category: 'Spices');
      await add('B', category: 'Biscuits');
      await add('C', category: 'Grains');

      final counts = await db.productDao.watchCategoryCounts().first;
      expect(counts.keys, ['Biscuits', 'Grains', 'Spices']);
    });
  });
}
