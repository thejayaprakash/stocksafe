import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'product_dao.g.dart';

/// Products are soft-deleted only. Every query here filters `deletedAt`,
/// so a user who taps the wrong button can be restored later.
@DriftAccessor(tables: [Products, Movements])
class ProductDao extends DatabaseAccessor<AppDatabase> with _$ProductDaoMixin {
  ProductDao(super.db);

  /// Paged, indexed product list with optional category and search query.
  Stream<List<Product>> watchAll({
    String query = '',
    String? category,
    int limit = 100,
    int offset = 0,
  }) {
    final q = select(products)
      ..where((p) {
        var predicate = p.deletedAt.isNull();
        if (category != null && category.isNotEmpty) {
          predicate = predicate & p.category.equals(category);
        }
        if (query.isNotEmpty) {
          final like = '%${_escapeLike(query)}%';
          predicate = predicate &
              (p.name.lower().like(like, escapeChar: r'\') |
                  p.sku.lower().like(like, escapeChar: r'\') |
                  p.barcode.lower().like(like, escapeChar: r'\'));
        }
        return predicate;
      })
      ..orderBy([(p) => OrderingTerm.asc(p.name)])
      ..limit(limit, offset: offset);

    return q.watch();
  }

  /// Get distinct non-empty categories from active products.
  Future<List<String>> getCategories() async {
    final catCol = products.category;
    final q = selectOnly(products, distinct: true)
      ..addColumns([catCol])
      ..where(products.deletedAt.isNull() & catCol.isNotNull());
    final rows = await q.get();
    return rows
        .map((r) => r.read(catCol))
        .whereType<String>()
        .where((c) => c.trim().isNotEmpty)
        .toList()
      ..sort();
  }

  /// Stream distinct categories.
  Stream<List<String>> watchCategories() {
    final catCol = products.category;
    final q = selectOnly(products, distinct: true)
      ..addColumns([catCol])
      ..where(products.deletedAt.isNull() & catCol.isNotNull());
    return q.watch().map((rows) => rows
        .map((r) => r.read(catCol))
        .whereType<String>()
        .where((c) => c.trim().isNotEmpty)
        .toList()
      ..sort());
  }

  /// Insert multiple products in a batch (used by CSV importer).
  Future<void> batchInsert(List<ProductsCompanion> entries) async {
    await batch((b) {
      b.insertAll(products, entries);
    });
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
      (update(products)..where((p) => p.id.equals(id))).write(
        ProductsCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );

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

  /// Calculate live total inventory valuation (cost price, retail price, margin, units).
  Future<InventoryValuationSummary> getInventoryValuation() =>
      _valuationQuery().getSingle().then(_readValuation);

  /// Watch live inventory valuation reactively.
  ///
  /// Aggregated in SQL rather than by loading the catalogue into Dart. The
  /// valuation card sits on the home screen, so the previous version
  /// materialised every active product on every change to the table — a full
  /// catalogue load after each stock movement.
  Stream<InventoryValuationSummary> watchInventoryValuation() =>
      _valuationQuery().watchSingle().map(_readValuation);

  Selectable<QueryRow> _valuationQuery() => customSelect(
        '''
        SELECT
          COUNT(*)                                            AS total_products,
          COALESCE(SUM(CASE WHEN stock_qty > 0 THEN stock_qty END), 0)
                                                              AS total_units,
          COALESCE(SUM(CASE WHEN stock_qty > 0
                            THEN stock_qty * buy_price END), 0.0)
                                                              AS total_cost,
          COALESCE(SUM(CASE WHEN stock_qty > 0
                            THEN stock_qty * sell_price END), 0.0)
                                                              AS total_retail
        FROM product
        WHERE deleted_at IS NULL
        ''',
        readsFrom: {products},
      );

  static InventoryValuationSummary _readValuation(QueryRow row) {
    final totalCost = row.read<double>('total_cost');
    final totalRetail = row.read<double>('total_retail');
    final potentialProfit = totalRetail - totalCost;

    return InventoryValuationSummary(
      totalProducts: row.read<int>('total_products'),
      totalUnits: row.read<int>('total_units'),
      totalCostValue: totalCost,
      totalRetailValue: totalRetail,
      potentialProfit: potentialProfit,
      marginPercent: totalCost > 0 ? (potentialProfit / totalCost) * 100 : 0.0,
    );
  }


  static String _escapeLike(String input) =>
      input.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
}

/// Snapshot of inventory valuation for small retailers.
class InventoryValuationSummary {
  final int totalProducts;
  final int totalUnits;
  final double totalCostValue;
  final double totalRetailValue;
  final double potentialProfit;
  final double marginPercent;

  const InventoryValuationSummary({
    required this.totalProducts,
    required this.totalUnits,
    required this.totalCostValue,
    required this.totalRetailValue,
    required this.potentialProfit,
    required this.marginPercent,
  });
}
