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

  Stream<List<Movement>> watchForProduct(int productId, {int limit = 100}) {
    final q = select(movements)
      ..where((m) => m.productId.equals(productId))
      ..orderBy([(m) => OrderingTerm.desc(m.createdAt), (m) => OrderingTerm.desc(m.id)])
      ..limit(limit);
    return q.watch();
  }

  /// All movements, newest first — for CSV export (every column).
  Future<List<Movement>> getAllForExport() =>
      (select(movements)
            ..orderBy([
              (m) => OrderingTerm.desc(m.createdAt),
              (m) => OrderingTerm.desc(m.id),
            ]))
          .get();

  /// Append-only guard: refuses deletion. If you ever genuinely need to
  /// void a row, add a `voided_at` column — do not delete.
  Future<void> deleteMovementNever(int movementId) async {
    throw UnsupportedError(
      'The movement ledger is append-only. Add a void marker instead of deleting.',
    );
  }
}
