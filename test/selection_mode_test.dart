// Selection mode changes what a tap means, which is the kind of thing that
// goes wrong quietly: a tap that opens a product mid-selection throws away
// everything the user had picked.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/main.dart';
import 'package:stocksafe/src/data/database.dart';
import 'package:stocksafe/src/ui/widgets/floating_wave_nav_bar.dart';

/// Opens the catalogue over a seeded in-memory database, runs [body], and
/// closes the connection whatever happens.
///
/// The close has to be inside the test body and followed by a pump: drift
/// schedules a zero-duration cleanup timer when a query stream is cancelled,
/// and if that lands while the framework is tearing the tree down the test
/// fails with "A Timer is still pending". The `finally` matters just as
/// much — a failed expectation skips the rest of the body, and a connection
/// left open takes the *next* test down with it, for reasons that have
/// nothing to do with that test.
Future<void> withCatalogue(
  WidgetTester tester,
  Future<void> Function(AppDatabase db) body,
) async {
  final db = AppDatabase(NativeDatabase.memory());
  final now = DateTime(2026, 8, 1);
  for (final entry in {
    'Amul Ghee 1L': 'Dairy',
    'Amul Butter 500g': 'Dairy',
    'Aachi Masala 200g': 'Spices',
    'Loose Jaggery': 'Grains',
  }.entries) {
    await db.productDao.insertProduct(
      ProductsCompanion.insert(
        name: entry.key,
        category: Value(entry.value),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  try {
    await tester.pumpWidget(StockSafeApp(createDatabase: () => db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Products').last);
    await tester.pumpAndSettle();
    await body(db);
  } finally {
    await db.close();
    await tester.pump();
  }
}

void main() {
  testWidgets('a long press starts a selection with that product in it',
      (tester) async {
    await withCatalogue(tester, (db) async {
      expect(find.text('1 selected'), findsNothing);

      await tester.longPress(find.text('Amul Ghee 1L'));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
      expect(find.text('Select all (4)'), findsOneWidget);
    });
  });

  testWidgets('while selecting, a tap picks the row instead of opening it',
      (tester) async {
    await withCatalogue(tester, (db) async {
      await tester.longPress(find.text('Amul Ghee 1L'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Loose Jaggery'));
      await tester.pumpAndSettle();

      expect(find.text('2 selected'), findsOneWidget);
      // Still on the catalogue: the product page never opened.
      expect(find.text('Stock Information'), findsNothing);
    });
  });

  testWidgets('the bulk bar replaces the navigation while selecting',
      (tester) async {
    await withCatalogue(tester, (db) async {
      expect(find.byType(FloatingWaveNavBar), findsOneWidget);

      await tester.longPress(find.text('Amul Ghee 1L'));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingWaveNavBar), findsNothing);
      expect(find.text('Delete'), findsOneWidget);
    });
  });

  testWidgets('select all picks every product the filters match',
      (tester) async {
    await withCatalogue(tester, (db) async {
      await tester.longPress(find.text('Amul Ghee 1L'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select all (4)'));
      await tester.pumpAndSettle();

      expect(find.text('4 selected'), findsOneWidget);
    });
  });

  testWidgets('select all respects a filter rather than taking the whole shop',
      (tester) async {
    await withCatalogue(tester, (db) async {
      // Narrowed by search rather than by a category chip: "Dairy" also
      // appears on each row's own tag, so tapping it by text is ambiguous.
      // Narrowed by search rather than by a category chip: a category name
      // appears on each row's own tag too, so tapping it by text is
      // ambiguous. "Amul" matches two of the four products.
      await tester.enterText(find.byType(TextField).first, 'Amul');
      await tester.pumpAndSettle();
      expect(find.text('Aachi Masala 200g'), findsNothing);

      await tester.longPress(find.text('Amul Ghee 1L'));
      await tester.pumpAndSettle();
      expect(find.text('Select all (2)'), findsOneWidget);

      await tester.tap(find.text('Select all (2)'));
      await tester.pumpAndSettle();

      // Two, not four: "all" has to mean all of what the filter shows, and
      // that count is what a bulk delete would act on.
      expect(find.text('2 selected'), findsOneWidget);
    });
  });

  testWidgets('unticking the last product leaves selection mode',
      (tester) async {
    // Otherwise the user is left looking at a bar of actions that would all
    // do nothing, with no indication why.
    await withCatalogue(tester, (db) async {
      await tester.longPress(find.text('Amul Ghee 1L'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amul Ghee 1L'));
      await tester.pumpAndSettle();

      expect(find.textContaining('selected'), findsNothing);
      expect(find.byType(FloatingWaveNavBar), findsOneWidget);
    });
  });

  testWidgets('cancel drops the selection', (tester) async {
    await withCatalogue(tester, (db) async {
      await tester.longPress(find.text('Amul Ghee 1L'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.textContaining('selected'), findsNothing);
      expect(find.byType(FloatingWaveNavBar), findsOneWidget);
    });
  });

  testWidgets('deleting a selection asks first, and says what survives',
      (tester) async {
    await withCatalogue(tester, (db) async {
      await tester.longPress(find.text('Amul Ghee 1L'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete 1 product?'), findsOneWidget);
      expect(find.textContaining('stock history is kept'), findsOneWidget);

      // Backing out changes nothing.
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      // A one-shot query, not `watchAll().first`: a drift stream never
      // resolves inside testWidgets, where time is faked, and awaiting one
      // hangs the test rather than failing it.
      expect(await db.productDao.idsMatching(), hasLength(4));
    });
  });

  testWidgets('confirming a delete removes exactly the selection',
      (tester) async {
    await withCatalogue(tester, (db) async {
      await tester.longPress(find.text('Amul Ghee 1L'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      final left = await db.productDao.idsMatching();
      expect(left, hasLength(3));
      expect(find.text('Amul Ghee 1L'), findsNothing);
      // And the selection is over.
      expect(find.byType(FloatingWaveNavBar), findsOneWidget);
    });
  });
}
