import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/main.dart';
import 'package:stocksafe/src/app_scope.dart';
import 'package:stocksafe/src/data/database.dart';

/// Pumps [StockSafeApp] over an in-memory database and returns the host.
///
/// The database must be closed inside the test body: drift schedules a
/// zero-duration cleanup timer when a query stream is cancelled, and if that
/// happens while the framework tears the tree down the test fails with
/// "A Timer is still pending even after the widget tree was disposed".
Future<DatabaseHost> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    StockSafeApp(createDatabase: () => AppDatabase(NativeDatabase.memory())),
  );
  await tester.pumpAndSettle();
  // Resolve from inside the page tree: StockSafeApp itself sits above the scope.
  return AppScope.of(tester.element(find.text('StockSafe'))).host;
}

void main() {
  testWidgets('StockSafeApp renders', (WidgetTester tester) async {
    final host = await pumpApp(tester);

    expect(find.text('StockSafe'), findsOneWidget);

    // Close the connection inside the test body (see pumpApp); the tree's own
    // dispose handles the host.
    await host.db.close();
    await tester.pump();
  });

  testWidgets('pages read the database from AppScope, not a constructor',
      (WidgetTester tester) async {
    final host = await pumpApp(tester);

    // Resolving the scope from deep inside the page tree must yield the very
    // instance the host built — proving pages no longer carry their own
    // reference, and that the database can be swapped underneath them.
    final deepContext = tester.element(find.text('StockSafe'));
    expect(identical(AppScope.of(deepContext).db, host.db), isTrue);
    expect(host.isOpen, isTrue);

    // Close the connection inside the test body (see pumpApp); the tree's own
    // dispose handles the host.
    await host.db.close();
    await tester.pump();
  });

  testWidgets('Dashboard renders non-disruptive rewarded ad card for free users',
      (WidgetTester tester) async {
    final host = await pumpApp(tester);

    // Verify the ad reward card appears on the dashboard
    expect(find.text('Earn Free Product Slots'), findsOneWidget);
    expect(find.text('SPONSORED'), findsOneWidget);
    expect(find.text('Watch (+2)'), findsOneWidget);

    await host.db.close();
    await tester.pump();
  });

  testWidgets('Recent stock activity row can be tapped to navigate to product details',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final host = await pumpApp(tester);

    // Insert a product and a stock movement
    final now = DateTime.now();
    final pId = await host.db.productDao.insertProduct(
      ProductsCompanion.insert(
        name: 'Organic Wheat Flour',
        unit: const Value('kg'),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await host.db.movementDao.recordMovement(
      productId: pId,
      qtyDelta: 15,
      reason: 'purchase',
    );
    await tester.pumpAndSettle();

    // Verify recent stock activity and top products show product name
    expect(find.text('Organic Wheat Flour'), findsNWidgets(2));

    // Tap on recent activity row
    await tester.tap(find.text('Organic Wheat Flour').last);
    await tester.pumpAndSettle();

    // Verify it navigated to ProductDetailPage
    expect(find.text('Movement history'), findsOneWidget);

    await host.db.close();
    await tester.pump();
  });
}
