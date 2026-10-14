import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'movement_dao.g.dart';

/// The ledger. Rows are append-only: insert is the only write, except
/// correcting a typo in a note. Stock levels are derived, never stored
/// as an authoritative number.
@DriftAccessor(tables: [Movements, Products])
class MovementDao extends DatabaseAccessor<AppDatabase> with _$MovementDaoMixin {
  MovementDao(super.db);

  /// Applies the same movement to several products in one transaction.
  ///
  /// All or nothing. A bulk adjustment that failed partway would leave the
  /// shopkeeper with no way to know which half of their selection had moved,
  /// and the ledger is the record they are meant to be able to trust.
  ///
  /// [qtyDelta] is signed and applied per product, not split between them:
  /// "-1 on each of these six" is the operation a shelf sweep produces.
  Future<void> recordMovementForAll({
    required Iterable<int> productIds,
    required int qtyDelta,
    required String reason,
    String? note,
  }) async {
    final ids = productIds.toSet().toList();
    if (ids.isEmpty) return;
    if (qtyDelta == 0) {
      throw ArgumentError.value(qtyDelta, 'qtyDelta', 'must be non-zero');
    }

    await transaction(() async {
      for (final id in ids) {
        await recordMovement(
          productId: id,
          qtyDelta: qtyDelta,
          reason: reason,
          note: note,
        );
      }
    });
  }

  /// Records a stock movement and refreshes the product's cached qty
  /// in the same transaction. The cache update is derived from
  /// SUM(qty_delta) so it can never drift from the ledger.
  Future<void> recordMovement({
    required int productId,
    required int qtyDelta,
    required String reason,
    String? note,
    int? batchId,
    int? auditSessionId,
    int? supplierId,
    int? locationId,
    String? transferRef,
    DateTime? createdAt,
  }) async {
    if (qtyDelta == 0) {
      throw ArgumentError.value(qtyDelta, 'qtyDelta', 'must be non-zero');
    }
    await transaction(() async {
      await into(movements).insert(
        MovementsCompanion.insert(
          productId: productId,
          qtyDelta: qtyDelta,
          reason: reason,
          note: Value(note),
          batchId: Value(batchId),
          auditSessionId: Value(auditSessionId),
          supplierId: Value(supplierId),
          locationId: Value(
            locationId ?? (await db.locationDao.getOrCreateDefault()).id,
          ),
          transferRef: Value(transferRef),
          createdAt: createdAt ?? DateTime.now(),
        ),
      );

      final sum = movements.qtyDelta.sum();
      final q = selectOnly(movements)
        ..addColumns([sum])
        ..where(movements.productId.equals(productId));
      final row = await q.getSingle();
      final total = row.read(sum) ?? 0;

      await (update(products)..where((p) => p.id.equals(productId))).write(
        ProductsCompanion(stockQty: Value(total), updatedAt: Value(DateTime.now())),
      );

      // Derived from the ledger in the same transaction, exactly as the
      // product cache above — never incremented, so it cannot drift.
      if (batchId != null) {
        await db.batchDao.rebuildBatchStock(batchId);
      }
    });
  }

  /// Moves stock between two locations.
  ///
  /// Written as a matched pair in one transaction: `-qty` at the source and
  /// `+qty` at the destination, sharing a reference. Odoo models a transfer
  /// as a single move with a source and a destination, which makes quantity
  /// conservation structural; with a signed-delta ledger the equivalent is
  /// this pair, and the transaction is what guarantees you can never end up
  /// with the deduction but not the addition.
  ///
  /// The product's total is deliberately unchanged — nothing entered or left
  /// the business, it only moved — so the pair sums to zero and the cached
  /// `stock_qty` lands back where it started.
  Future<String> transferStock({
    required int productId,
    required int fromLocationId,
    required int toLocationId,
    required int quantity,
    String? note,
    DateTime? createdAt,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError.value(quantity, 'quantity', 'must be positive');
    }
    if (fromLocationId == toLocationId) {
      throw ArgumentError('Source and destination must be different.');
    }

    final ref = 'TRF-${DateTime.now().microsecondsSinceEpoch}';
    final at = createdAt ?? DateTime.now();

    await transaction(() async {
      await recordMovement(
        productId: productId,
        qtyDelta: -quantity,
        reason: 'transfer_out',
        note: note,
        locationId: fromLocationId,
        transferRef: ref,
        createdAt: at,
      );
      await recordMovement(
        productId: productId,
        qtyDelta: quantity,
        reason: 'transfer_in',
        note: note,
        locationId: toLocationId,
        transferRef: ref,
        createdAt: at,
      );
    });

    return ref;
  }

  Stream<List<Movement>> watchForProduct(int productId, {int limit = 100}) {
    final q = select(movements)
      ..where((m) => m.productId.equals(productId))
      ..orderBy([(m) => OrderingTerm.desc(m.createdAt), (m) => OrderingTerm.desc(m.id)])
      ..limit(limit);
    return q.watch();
  }

  /// Watch recent movements across all products for dashboard activity stream.
  Stream<List<Movement>> watchRecent({int limit = 10}) {
    final q = select(movements)
      ..orderBy([(m) => OrderingTerm.desc(m.createdAt), (m) => OrderingTerm.desc(m.id)])
      ..limit(limit);
    return q.watch();
  }

  /// How many rows the ledger holds.
  ///
  /// The ledger only grows, and its size is what drives migration time and the
  /// cost of a full integrity audit, so it is the most useful single number
  /// about a shop's scale — and it says nothing about what the shop sells.
  Future<int> count() async {
    final c = countAll();
    final q = selectOnly(movements)..addColumns([c]);
    final row = await q.getSingle();
    return row.read(c) ?? 0;
  }

  /// All movements, newest first — for CSV export (every column).
  Future<List<Movement>> getAllForExport() =>
      (select(movements)
            ..orderBy([
              (m) => OrderingTerm.desc(m.createdAt),
              (m) => OrderingTerm.desc(m.id),
            ]))
          .get();

  // There is deliberately no delete method here. The ledger is append-only:
  // stock levels are derived from it, so removing a row rewrites history and
  // silently changes every quantity after it. To reverse a movement, record a
  // compensating one. If voiding is ever genuinely needed, add a `voided_at`
  // column and filter on it — do not delete.
}
