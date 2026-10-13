import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'product_dao.g.dart';

/// Products are soft-deleted only. Every query here filters `deletedAt`,
/// so a user who taps the wrong button can be restored later.
@DriftAccessor(tables: [Products, Movements])
class ProductDao extends DatabaseAccessor<AppDatabase> with _$ProductDaoMixin {
  ProductDao(super.db);

  /// Paged, indexed product list. Never loads the full table.
  Stream<List<Product>> watchAll({String query = '', int limit = 50, int offset = 0}) {
    var q = select(products)
      ..where((p) => p.deletedAt.isNull())
      ..orderBy([(p) => OrderingTerm.asc(p.name)])
      ..limit(limit, offset: offset);

    if (query.isNotEmpty) {
      final like = '%${_escapeLike(query)}%';
      q = select(products)
        ..where(
          (p) =>
              p.deletedAt.isNull() &
              (p.name.lower().like(like) |
                  p.sku.lower().like(like) |
                  p.barcode.lower().like(like)),
        )
        ..orderBy([(p) => OrderingTerm.asc(p.name)])
        ..limit(limit, offset: offset);
    }
    return q.watch();
  }

  Future<Product?> getById(int id) =>
      (select(products)..where((p) => p.id.equals(id) & p.deletedAt.isNull()))
          .getSingleOrNull();

  Future<Product?> getByBarcode(String barcode) =>
      (select(products)
            ..where((p) => p.barcode.equals(barcode) & p.deletedAt.isNull())
            ..limit(1))
          .getSingleOrNull();

  Stream<Product?> watchById(int id) =>
      (select(products)..where((p) => p.id.equals(id) & p.deletedAt.isNull()))
          .watchSingleOrNull();

  Future<int> insertProduct(ProductsCompanion entry) =>
      into(products).insert(entry);

  Future<bool> updateProduct(int id, ProductsCompanion entry) async {
    final count = await (update(products)..where((p) => p.id.equals(id)))
        .write(entry.copyWith(updatedAt: Value(DateTime.now())));
    return count > 0;
  }

  Future<void> softDelete(int id) async {
    final now = DateTime.now();
    await (update(products)..where((p) => p.id.equals(id)))
        .write(ProductsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  }

  Future<void> restore(int id) =>
      (update(products)..where((p) => p.id.equals(id)))
          .write(const ProductsCompanion(deletedAt: Value(null)));

  Future<int> countActive() async {
    final c = countAll(filter: products.deletedAt.isNull());
    final q = selectOnly(products)..addColumns([c]);
    final row = await q.getSingle();
    return row.read(c) ?? 0;
  }

  /// Rebuild one product's cached stock from the ledger.
  Future<void> rebuildStockCache(int productId) async {
    final sum = movements.qtyDelta.sum();
    final q = selectOnly(movements)
      ..addColumns([sum])
      ..where(movements.productId.equals(productId));
    final row = await q.getSingle();
    final total = row.read(sum) ?? 0;
    await (update(products)..where((p) => p.id.equals(productId)))
        .write(ProductsCompanion(stockQty: Value(total)));
  }

  /// Low-stock products: stock at or below alert level, excluding products
  /// whose alert is disabled (level = 0).
  Stream<List<Product>> watchLowStock({int limit = 200}) {
    final q = select(products)
      ..where((p) =>
          p.deletedAt.isNull() &
          p.lowStockLevel.isBiggerThanValue(0) &
          p.stockQty.isSmallerOrEqual(p.lowStockLevel))
      ..orderBy([(p) => OrderingTerm.asc(p.stockQty)])
      ..limit(limit);
    return q.watch();
  }

  /// All active products, every column — for CSV/Excel export.
  /// The spec demands every column in exports.
  Future<List<Product>> getAllForExport() =>
      (select(products)
            ..where((p) => p.deletedAt.isNull())
            ..orderBy([(p) => OrderingTerm.asc(p.name)]))
          .get();

  static String _escapeLike(String input) =>
      input.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
}
