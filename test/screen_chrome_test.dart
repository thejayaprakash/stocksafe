// Chrome-level behaviour on the redesigned screens: the things that would
// confuse a shopkeeper rather than crash the app, and so would otherwise go
// unnoticed until someone looked at a device.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/main.dart';
import 'package:stocksafe/src/data/database.dart';
import 'package:stocksafe/src/services/license_service.dart';

Future<void> openTab(
  WidgetTester tester,
  AppDatabase db,
  String label,
) async {
  await tester.pumpWidget(StockSafeApp(createDatabase: () => db));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the empty stocktake screen offers one way to start a count, '
      'not two', (tester) async {
    // It used to show a centred "Start New Count" button and a "New Audit
    // Session" FAB over the top of it — the same action, two labels, on an
    // otherwise empty screen.
    final db = AppDatabase(NativeDatabase.memory());

    await openTab(tester, db, 'Stock Count');

    expect(find.text('No in-progress stocktake sessions'), findsOneWidget);
    expect(find.text('New Audit Session'), findsOneWidget,
        reason: 'the empty state has exactly one call to action');
    expect(find.text('Start New Count'), findsNothing);

    await db.close();
    await tester.pump();
  });

  testWidgets('More does not offer an upgrade to someone who already paid',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await LicenseService(db).unlockLifetime(method: 'test');

    await openTab(tester, db, 'More');

    expect(find.textContaining('Upgrade to Pro'), findsNothing);
    expect(find.text('StockSafe Pro Active'), findsOneWidget);

    await db.close();
    await tester.pump();
  });

  testWidgets('More offers the upgrade to someone who has not', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());

    await openTab(tester, db, 'More');

    expect(find.textContaining('Upgrade to Pro'), findsOneWidget);
    expect(find.text('StockSafe Pro Active'), findsNothing);

    await db.close();
    await tester.pump();
  });

  testWidgets('the licence check never flashes the wrong card', (tester) async {
    // isProUnlocked is a database read, so there is a frame before the answer
    // arrives. Defaulting that frame to "not Pro" showed a paying user an
    // upgrade offer every time they opened More.
    final db = AppDatabase(NativeDatabase.memory());
    await LicenseService(db).unlockLifetime(method: 'test');

    await tester.pumpWidget(StockSafeApp(createDatabase: () => db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More').last);

    // Every frame between the tap and the answer, not just the settled one.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.textContaining('Upgrade to Pro'), findsNothing,
          reason: 'frame $i offered an upgrade to a Pro user');
    }

    await tester.pumpAndSettle();
    await db.close();
    await tester.pump();
  });
}
