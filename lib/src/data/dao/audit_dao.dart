import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'audit_dao.g.dart';

/// Data Access Object for persistent Stocktake Audit sessions and item counts.
@DriftAccessor(tables: [StockAuditSessions, StockAuditItems, Products, Movements])
class AuditDao extends DatabaseAccessor<AppDatabase> with _$AuditDaoMixin {
  AuditDao(super.db);

  /// Create a new audit session. Returns the created session ID.
  Future<int> createSession({
    required String name,
    String auditMode = 'transparent',
    String? notes,
  }) async {
    final now = DateTime.now();
    return into(stockAuditSessions).insert(
      StockAuditSessionsCompanion.insert(
        name: name,
        status: const Value('in_progress'),
        auditMode: Value(auditMode),
        startedAt: now,
        notes: Value(notes),
      ),
    );
  }

  /// Get session by ID.
  Future<StockAuditSession?> getSession(int id) {
    return (select(stockAuditSessions)..where((s) => s.id.equals(id))).getSingleOrNull();
  }

  /// Watch active (in_progress) audit sessions, newest first.
  Stream<List<StockAuditSession>> watchActiveSessions() {
    return (select(stockAuditSessions)
          ..where((s) => s.status.equals('in_progress'))
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
        .watch();
  }

  /// Watch all sessions, newest first.
  Stream<List<StockAuditSession>> watchAllSessions() {
    return (select(stockAuditSessions)
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
        .watch();
  }

  /// Get or watch all audit items in a session.
  Stream<List<StockAuditItem>> watchSessionItems(int sessionId) {
    return (select(stockAuditItems)
          ..where((i) => i.sessionId.equals(sessionId))
          ..orderBy([(i) => OrderingTerm.desc(i.updatedAt)]))
        .watch();
  }

  /// Fetch all audit items in a session directly.
  Future<List<StockAuditItem>> getSessionItems(int sessionId) {
    return (select(stockAuditItems)
          ..where((i) => i.sessionId.equals(sessionId))
          ..orderBy([(i) => OrderingTerm.desc(i.updatedAt)]))
        .get();
  }

  /// Record or update an item count within a session.
  /// If item already exists in session, updates countedQty and difference.
  Future<int> recordCount({
    required int sessionId,
    required int productId,
    required int countedQty,
    required int expectedQty,
    String? notes,
  }) async {
    final now = DateTime.now();
    final difference = countedQty - expectedQty;

    final existing = await (select(stockAuditItems)
          ..where((i) => i.sessionId.equals(sessionId) & i.productId.equals(productId)))
        .getSingleOrNull();

    if (existing != null) {
      await (update(stockAuditItems)..where((i) => i.id.equals(existing.id))).write(
        StockAuditItemsCompanion(
          countedQty: Value(countedQty),
          expectedQty: Value(expectedQty),
          difference: Value(difference),
          notes: Value(notes),
          updatedAt: Value(now),
        ),
      );
      await _updateSessionMetrics(sessionId);
      return existing.id;
    } else {
      final id = await into(stockAuditItems).insert(
        StockAuditItemsCompanion.insert(
          sessionId: sessionId,
          productId: productId,
          expectedQty: expectedQty,
          countedQty: countedQty,
          difference: difference,
          notes: Value(notes),
          updatedAt: now,
        ),
      );
      await _updateSessionMetrics(sessionId);
      return id;
    }
  }

  /// Recalculate summary metrics for an active session.
  Future<void> _updateSessionMetrics(int sessionId) async {
    final items = await (select(stockAuditItems)..where((i) => i.sessionId.equals(sessionId))).get();
    final count = items.length;
    int discrepancies = 0;

    for (final item in items) {
      if (item.difference != 0) discrepancies++;
    }

    await (update(stockAuditSessions)..where((s) => s.id.equals(sessionId))).write(
      StockAuditSessionsCompanion(
        totalItemsCounted: Value(count),
        totalDiscrepancies: Value(discrepancies),
      ),
    );
  }

  /// Atomically reconcile all discrepancies in the audit session into the immutable movement ledger.
  Future<void> reconcileSession(
    int sessionId, {
    String reason = 'stocktake_adjustment',
  }) async {
    await transaction(() async {
      final session = await getSession(sessionId);
      if (session == null || session.status == 'completed') {
        throw StateError('Session $sessionId is already completed or does not exist.');
      }

      final items = await (select(stockAuditItems)
            ..where((i) => i.sessionId.equals(sessionId) & i.isReconciled.equals(false)))
          .get();

      final now = DateTime.now();
      double netValueChange = 0.0;

      for (final item in items) {
        if (item.difference != 0) {
          // 1. Insert immutable adjustment movement
          await into(movements).insert(
            MovementsCompanion.insert(
              productId: item.productId,
              qtyDelta: item.difference,
              reason: reason,
              note: Value('Stocktake "${session.name}" (difference: ${item.difference > 0 ? "+${item.difference}" : "${item.difference}"})'),
              auditSessionId: Value(sessionId),
              createdAt: now,
            ),
          );

          // 2. Fetch product cost to calculate valuation impact
          final prod = await (select(products)..where((p) => p.id.equals(item.productId))).getSingleOrNull();
          if (prod != null) {
            netValueChange += item.difference * prod.buyPrice;
          }

          // 3. Atomically update product stockQty cache
          await (update(products)..where((p) => p.id.equals(item.productId))).write(
            ProductsCompanion(
              stockQty: Value((prod?.stockQty ?? 0) + item.difference),
              updatedAt: Value(now),
            ),
          );
        }

        // 4. Mark item as reconciled
        await (update(stockAuditItems)..where((i) => i.id.equals(item.id))).write(
          StockAuditItemsCompanion(
            isReconciled: const Value(true),
            reconciledAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }

      // 5. Mark session as completed
      await (update(stockAuditSessions)..where((s) => s.id.equals(sessionId))).write(
        StockAuditSessionsCompanion(
          status: const Value('completed'),
          completedAt: Value(now),
          netDiscrepancyValue: Value(netValueChange),
        ),
      );
    });
  }

  /// Cancel/abandon an in-progress session.
  Future<void> cancelSession(int sessionId) async {
    await (update(stockAuditSessions)..where((s) => s.id.equals(sessionId))).write(
      StockAuditSessionsCompanion(
        status: const Value('cancelled'),
        completedAt: Value(DateTime.now()),
      ),
    );
  }
}
