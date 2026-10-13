import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'supplier_dao.g.dart';

/// Supplier / Vendor Contacts Directory Data Access Object.
/// Manages vendor profiles, telephone contact details for tap-to-call,
/// and product-supplier linkage.
/// Adheres to StockSafe's core rule: Soft delete only.
@DriftAccessor(tables: [Suppliers, Products, Movements])
class SupplierDao extends DatabaseAccessor<AppDatabase> with _$SupplierDaoMixin {
  SupplierDao(super.db);

  /// Watch active suppliers, optionally filtered by query (matches name, phone, GSTIN).
  Stream<List<Supplier>> watchAll({String query = ''}) {
    final q = select(suppliers)
      ..where((s) {
        var predicate = s.deletedAt.isNull();
        if (query.isNotEmpty) {
          final like = '%${_escapeLike(query)}%';
          predicate = predicate &
              (s.name.lower().like(like, escapeChar: r'\') |
                  s.phone.lower().like(like, escapeChar: r'\') |
                  s.gstin.lower().like(like, escapeChar: r'\'));
        }
        return predicate;
      })
      ..orderBy([(s) => OrderingTerm.asc(s.name)]);

    return q.watch();
  }

  /// Get all active suppliers.
  Future<List<Supplier>> getAll() =>
      (select(suppliers)
            ..where((s) => s.deletedAt.isNull())
            ..orderBy([(s) => OrderingTerm.asc(s.name)]))
          .get();

  /// Retrieve supplier by ID.
  Future<Supplier?> getById(int id) =>
      (select(suppliers)..where((s) => s.id.equals(id) & s.deletedAt.isNull()))
          .getSingleOrNull();

  /// Watch supplier by ID reactively.
  Stream<Supplier?> watchById(int id) =>
      (select(suppliers)..where((s) => s.id.equals(id) & s.deletedAt.isNull()))
          .watchSingleOrNull();

  /// Insert a new supplier contact.
  Future<int> insertSupplier(SuppliersCompanion entry) =>
      into(suppliers).insert(entry);

  /// Update an existing supplier.
  Future<bool> updateSupplier(int id, SuppliersCompanion entry) async {
    final count = await (update(suppliers)..where((s) => s.id.equals(id)))
        .write(entry.copyWith(updatedAt: Value(DateTime.now())));
    return count > 0;
  }

  /// Soft-delete supplier contact. Preserves historical data integrity.
  Future<void> softDelete(int id) async {
    final now = DateTime.now();
    await (update(suppliers)..where((s) => s.id.equals(id)))
        .write(SuppliersCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  }

  /// Restore soft-deleted supplier.
  Future<void> restore(int id) =>
      (update(suppliers)..where((s) => s.id.equals(id)))
          .write(const SuppliersCompanion(deletedAt: Value(null)));

  /// Count of active suppliers.
  Future<int> countActive() async {
    final c = countAll(filter: suppliers.deletedAt.isNull());
    final q = selectOnly(suppliers)..addColumns([c]);
    final row = await q.getSingle();
    return row.read(c) ?? 0;
  }

  /// Active products assigned to this supplier.
  Future<List<Product>> getProductsForSupplier(int supplierId) =>
      (select(products)
            ..where((p) => p.supplierId.equals(supplierId) & p.deletedAt.isNull())
            ..orderBy([(p) => OrderingTerm.asc(p.name)]))
          .get();

  /// Watch active products assigned to this supplier.
  Stream<List<Product>> watchProductsForSupplier(int supplierId) =>
      (select(products)
            ..where((p) => p.supplierId.equals(supplierId) & p.deletedAt.isNull())
            ..orderBy([(p) => OrderingTerm.asc(p.name)]))
          .watch();

  /// Watch number of products mapped to this supplier.
  Stream<int> watchProductCountForSupplier(int supplierId) {
    final c = countAll(
      filter: products.supplierId.equals(supplierId) & products.deletedAt.isNull(),
    );
    final q = selectOnly(products)
      ..addColumns([c])
      ..where(products.supplierId.equals(supplierId) & products.deletedAt.isNull());
    return q.watchSingle().map((row) => row.read(c) ?? 0);
  }

  static String _escapeLike(String input) =>
      input.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
}
