// Performance baseline against the dev plan's own acceptance scale.
//
// Opt in, because seeding 50,000 ledger rows takes far longer than the rest of
// the suite combined and has no place in the per-push CI loop:
//
//   flutter test test/performance_test.dart --dart-define=PERF=true
//
// The budgets below are the Phase D acceptance criteria.
//
// Measured baseline, 13 Oct 2026, pre-index, in-memory SQLite on a desktop
// (seeding took 8s):
//
//   barcode lookup .......... within budget
//   single movement write ... within budget
//   first list page ......... within budget
//   paging to 5,000 ......... reaches every row
//   ledger integrity audit .. 7.4s against a 3s budget   <-- FAILS
//
// So the unindexed full scans are survivable for one-off operations on fast
// hardware, and only the audit — 5,000 sequential SUM queries — actually blows
// its budget today. These numbers are a lower bound: an in-memory database on
// a desktop has no disk I/O, which is the dominant cost on a phone. Re-measure
// on a physical mid-range device with a file-backed database before treating
// the passing rows as settled.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/data/database.dart';
import 'package:stocksafe/src/services/diagnostic_service.dart';

import 'support/large_dataset.dart';

const bool _runPerf = bool.fromEnvironment('PERF');
const String _skipReason =
    'opt-in: flutter test test/performance_test.dart --dart-define=PERF=true';

/// Phase D budgets, from the roadmap's acceptance table.
const _barcodeLookupBudget = Duration(milliseconds: 200);
const _movementWriteBudget = Duration(milliseconds: 100);
const _listPageBudget = Duration(milliseconds: 300);
const _integrityAuditBudget = Duration(seconds: 3);

void main() {
  group('Performance at plan scale', () {
    late AppDatabase db;
    late LargeDatasetStats stats;

    setUpAll(() async {
      if (!_runPerf) return;
      db = AppDatabase(NativeDatabase.memory());
      final sw = Stopwatch()..start();
      stats = await seedLargeDataset(db);
      sw.stop();
      // ignore: avoid_print
      print('seeded $stats in ${sw.elapsed.inSeconds}s');
    });

    tearDownAll(() async {
      if (!_runPerf) return;
      await db.close();
    });

    test('fixture matches the plan scale', () async {
      expect(stats.productCount, kPlanProductCount);
      expect(stats.movementCount, kPlanMovementCount);
      expect(await db.productDao.countActive(), kPlanProductCount);
      expect(await db.movementDao.getAllForExport(), hasLength(kPlanMovementCount));
    }, skip: _runPerf ? null : _skipReason);

    test('barcode lookup stays within budget', () async {
      // Worst case for a full scan: the last product in the table.
      final barcode = '890${(1000000000 + kPlanProductCount).toString().padLeft(10, '0')}';

      final sw = Stopwatch()..start();
      final found = await db.productDao.getByBarcode(barcode);
      sw.stop();

      expect(found, isNotNull, reason: 'fixture barcode should resolve');
      expect(sw.elapsed, lessThan(_barcodeLookupBudget),
          reason: 'needs an index on product.barcode — see roadmap D.1');
    }, skip: _runPerf ? null : _skipReason);

    test('a single stock movement stays within budget', () async {
      // recordMovement recomputes SUM(qty_delta) for the product; without an
      // index on movement.product_id that is a scan of all 50,000 rows.
      final sw = Stopwatch()..start();
      await db.movementDao.recordMovement(
        productId: 1,
        qtyDelta: -1,
        reason: 'sale',
      );
      sw.stop();

      expect(sw.elapsed, lessThan(_movementWriteBudget),
          reason: 'needs an index on movement.product_id — see roadmap D.1');
    }, skip: _runPerf ? null : _skipReason);

    test('the first page of the product list stays within budget', () async {
      final sw = Stopwatch()..start();
      final page = await db.productDao.watchAll(limit: 50).first;
      sw.stop();

      expect(page, hasLength(50));
      expect(sw.elapsed, lessThan(_listPageBudget),
          reason: 'needs an index on product.name — see roadmap D.1');
    }, skip: _runPerf ? null : _skipReason);

    test('every product is reachable through paging', () async {
      // Guards H-03: today the list silently stops at 100 because the UI never
      // advances the offset. Paging must reach all 5,000.
      final seen = <int>{};
      for (var offset = 0; offset < kPlanProductCount; offset += 500) {
        final page =
            await db.productDao.watchAll(limit: 500, offset: offset).first;
        seen.addAll(page.map((p) => p.id));
      }
      expect(seen, hasLength(kPlanProductCount),
          reason: 'paging must reach every product, not just the first page');
    }, skip: _runPerf ? null : _skipReason);

    test('ledger integrity audit stays within budget', () async {
      // Currently one SUM query per product: 5,000 scans of 50,000 rows.
      final sw = Stopwatch()..start();
      final mismatches = await DiagnosticService.instance.auditLedgerIntegrity(db);
      sw.stop();

      expect(mismatches, isEmpty,
          reason: 'cache was rebuilt during seeding, so it must agree with the ledger');
      expect(sw.elapsed, lessThan(_integrityAuditBudget),
          reason: 'needs an index plus a GROUP BY rewrite — see roadmap D.1 and D.6');
    }, skip: _runPerf ? null : _skipReason);
  });
}
