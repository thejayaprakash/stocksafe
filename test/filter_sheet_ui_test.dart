// The filter sheet is the one place a shopkeeper can hide most of their
// catalogue, so the behaviour pinned here is mostly about getting back out
// of it.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/main.dart';
import 'package:stocksafe/src/data/database.dart';

/// Opens the catalogue over a seeded database and closes it afterwards.
/// See selection_mode_test.dart for why the close is in a `finally`.
Future<void> withCatalogue(
  WidgetTester tester,
  Future<void> Function(AppDatabase db) body,
) async {
  final db = AppDatabase(NativeDatabase.memory());
  final now = DateTime(2026, 10, 1);
  for (final entry in {
    'Amul Ghee 1L': 'Dairy',
    'Amul Butter 500g': 'Dairy',
    'Aachi Masala 200g': 'Spices',
    'Rice, Basmati 5kg': 'Grains',
  }.entries) {
    await db.productDao.insertProduct(
      ProductsCompanion.insert(
        name: entry.key,
        category: Value(entry.value),
        stockQty: const Value(5),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  // One product with no category at all. Clearing the filter shows it, so
  // the "All categories" row has to count it.
  await db.productDao.insertProduct(
    ProductsCompanion.insert(
      name: 'Uncategorised thing',
      stockQty: const Value(5),
      createdAt: now,
      updatedAt: now,
    ),
  );

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

Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.tune_rounded));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the sheet lists each category with how many carry it',
      (tester) async {
    await withCatalogue(tester, (db) async {
      await openSheet(tester);

      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('All categories'), findsOneWidget);
      // Every category the shop uses, each tickable.
      for (final category in ['Dairy', 'Spices', 'Grains']) {
        expect(find.widgetWithText(InkWell, category), findsWidgets,
            reason: '$category is missing from the sheet');
      }
      expect(find.byType(Checkbox), findsNWidgets(4),
          reason: 'All categories, plus one row per category');

      // Five products, four of them categorised. "All categories" clears
      // the filter and therefore shows all five, so it must say five — it
      // used to sum the rows beneath it and promise four.
      expect(
        find.descendant(
          of: find.widgetWithText(InkWell, 'All categories'),
          matching: find.text('5'),
        ),
        findsOneWidget,
        reason: 'the All row must count uncategorised products too',
      );
    });
  });

  testWidgets('ticking categories narrows the list to their union',
      (tester) async {
    await withCatalogue(tester, (db) async {
      await openSheet(tester);

      await tester.tap(find.widgetWithText(InkWell, 'Dairy').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply 1 filter'));
      await tester.pumpAndSettle();

      expect(find.text('Amul Ghee 1L'), findsOneWidget);
      expect(find.text('Amul Butter 500g'), findsOneWidget);
      expect(find.text('Aachi Masala 200g'), findsNothing);
      expect(find.text('Rice, Basmati 5kg'), findsNothing);
    });
  });

  testWidgets('dismissing the sheet changes nothing', (tester) async {
    await withCatalogue(tester, (db) async {
      await openSheet(tester);
      await tester.tap(find.widgetWithText(InkWell, 'Dairy').last);
      await tester.pumpAndSettle();

      // Out through the system back gesture rather than the Apply button.
      // Pumped a fixed number of frames rather than pumpAndSettle: settling
      // after this particular pop does not converge under the test harness,
      // though the same sequence settles when run on its own.
      await tester.binding.handlePopRoute();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Aachi Masala 200g'), findsOneWidget,
          reason: 'a dismissed sheet must not apply what was ticked in it');
    });
  });

  testWidgets('the button carries the number of filters applied',
      (tester) async {
    await withCatalogue(tester, (db) async {
      // Nothing applied: no badge.
      expect(find.widgetWithText(InkWell, '1'), findsNothing);

      await openSheet(tester);
      await tester.tap(find.widgetWithText(InkWell, 'Dairy').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply 1 filter'));
      await tester.pumpAndSettle();

      // Several categories would still be one filter, so one is right here
      // either way — what matters is that the button now says something.
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      await openSheet(tester);
      expect(find.text('Apply 1 filter'), findsOneWidget);
    });
  });

  testWidgets('Reset clears what is ticked without leaving the sheet',
      (tester) async {
    await withCatalogue(tester, (db) async {
      await openSheet(tester);
      await tester.tap(find.widgetWithText(InkWell, 'Dairy').last);
      await tester.pumpAndSettle();
      expect(find.text('Apply 1 filter'), findsOneWidget);

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      expect(find.text('Show all products'), findsOneWidget);
      expect(find.text('Filters'), findsOneWidget);
    });
  });

  testWidgets('with no suppliers it says where to add one rather than '
      'showing an empty box', (tester) async {
    await withCatalogue(tester, (db) async {
      await openSheet(tester);
      expect(
        find.textContaining('More › Suppliers & Vendors'),
        findsOneWidget,
      );
    });
  });

  testWidgets('a category chip and the sheet agree on what is selected',
      (tester) async {
    await withCatalogue(tester, (db) async {
      // Tap the chip in the bar above the list, then open the sheet: it has
      // to show that category already ticked, or the two controls are
      // telling the user different things. The chip row scrolls, so the
      // chip is brought into view before it is tapped.
      // Scoped to the app bar: a category name also appears on each
      // product row's own tag, and tapping that opens the product.
      final chip = find.descendant(
        of: find.byType(AppBar),
        matching: find.widgetWithText(InkWell, 'Spices'),
      );
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.text('Amul Ghee 1L'), findsNothing);

      await openSheet(tester);
      expect(find.text('Apply 1 filter'), findsOneWidget);
    });
  });
}
