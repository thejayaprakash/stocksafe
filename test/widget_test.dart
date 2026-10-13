import 'package:drift/native.dart';
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
}
