import '../database.dart';

/// The single entry point for every stock mutation.
///
/// Today three different places write `product.stock_qty`:
///
///   1. [MovementDao.recordMovement] — recomputes `SUM(qty_delta)` inside the
///      insert transaction, so it is correct by construction.
///   2. [AppDatabase.rebuildAllStockCaches] — bulk repair from the ledger.
///   3. [AuditDao.reconcileSession] — *increments* the cached value rather
///      than re-deriving it, and bypasses batch adjustment entirely.
///
/// Only the first is correct by construction, which is how the cache can drift
/// at all. Funnelling every caller through this class means the fix for (3)
/// lands in one place instead of being chased across the UI — see roadmap B.7.
///
/// This class is deliberately a pass-through for now. Introducing the seam and
/// changing the behaviour behind it are separate steps, so that a regression in
/// either one is unambiguous.
class InventoryRepository {
  const InventoryRepository(this._db);

  final AppDatabase _db;

  // ── Ledger writes ───────────────────────────────────────────────

  /// Appends a movement and refreshes the derived caches.
  ///
  /// Prefer this over reaching for `db.movementDao` directly: it is the seam
  /// where batch reconciliation and negative-stock policy will attach.
  Future<void> recordMovement({
    required int productId,
    required int qtyDelta,
    required String reason,
    String? note,
    int? batchId,
    int? auditSessionId,
    int? supplierId,
    DateTime? createdAt,
  }) {
    return _db.movementDao.recordMovement(
      productId: productId,
      qtyDelta: qtyDelta,
      reason: reason,
      note: note,
      batchId: batchId,
      auditSessionId: auditSessionId,
      supplierId: supplierId,
      createdAt: createdAt,
    );
  }

  /// Writes the variance of a completed stocktake into the ledger.
  Future<void> reconcileAuditSession(
    int sessionId, {
    String reason = 'stocktake_adjustment',
  }) {
    return _db.auditDao.reconcileSession(sessionId, reason: reason);
  }

  // ── Derived state ───────────────────────────────────────────────

  /// Recomputes every product's cached quantity from the ledger.
  Future<void> rebuildAllCaches() => _db.rebuildAllStockCaches();

  /// Recomputes one product's cached quantity from the ledger.
  Future<void> rebuildCacheFor(int productId) =>
      _db.productDao.rebuildStockCache(productId);

  // ── Reads ───────────────────────────────────────────────────────

  Stream<List<Product>> watchProducts({
    String query = '',
    String? category,
    int limit = 100,
    int offset = 0,
  }) =>
      _db.productDao.watchAll(
        query: query,
        category: category,
        limit: limit,
        offset: offset,
      );

  Stream<List<Product>> watchLowStock({int limit = 200}) =>
      _db.productDao.watchLowStock(limit: limit);

  Stream<List<Movement>> watchMovementsFor(int productId, {int limit = 100}) =>
      _db.movementDao.watchForProduct(productId, limit: limit);

  Future<Product?> productByBarcode(String barcode) =>
      _db.productDao.getByBarcode(barcode);

  Future<Product?> productById(int id) => _db.productDao.getById(id);

  Future<int> activeProductCount() => _db.productDao.countActive();

  Stream<InventoryValuationSummary> watchValuation() =>
      _db.productDao.watchInventoryValuation();
}
