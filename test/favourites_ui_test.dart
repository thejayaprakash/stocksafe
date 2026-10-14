// The heart appears in more than one place at once — a grid tile and the
// page opened from it — so the thing worth pinning is that it reads from the
// row rather than from a local copy that can disagree with it.
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
  final now = DateTime(2026, 9, 1);
  for (final name in ['Amul Ghee 1L', 'Loose Jaggery']) {
    await db.productDao.insertProduct(
      ProductsCompanion.insert(
        name: name,
        stockQty: const Value(5),
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
  testWidgets('the heart on the product page pins it', (tester) async {
    await withCatalogue(tester, (db) async {
      await tester.tap(find.text('Amul Ghee 1L'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);

      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pumpAndSettle();

      // Filled now, and written through — not just a local flag.
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      final pinned = await db.productDao.idsMatching(favouritesOnly: true);
      expect(pinned, hasLength(1));
    });
  });

  testWidgets('tapping it again unpins', (tester) async {
    await withCatalogue(tester, (db) async {
      await tester.tap(find.text('Amul Ghee 1L'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.favorite_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(await db.productDao.idsMatching(favouritesOnly: true), isEmpty);
    });
  });

  testWidgets('the Favourites chip narrows the catalogue to what is pinned',
      (tester) async {
    await withCatalogue(tester, (db) async {
      // Pin one through the page, then come back to the list.
      await tester.tap(find.text('Amul Ghee 1L'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Loose Jaggery'), findsOneWidget);

      await tester.tap(find.text('Favourites'));
      await tester.pumpAndSettle();

      expect(find.text('Amul Ghee 1L'), findsOneWidget);
      expect(find.text('Loose Jaggery'), findsNothing);
    });
  });

  testWidgets('filtering to favourites with none pinned offers a way back',
      (tester) async {
    // Otherwise the screen is empty and the control that emptied it has
    // scrolled out of reach.
    await withCatalogue(tester, (db) async {
      await tester.tap(find.text('Favourites'));
      await tester.pumpAndSettle();

      expect(find.text('No products match this search'), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();

      expect(find.text('Amul Ghee 1L'), findsOneWidget);
      expect(find.text('Loose Jaggery'), findsOneWidget);
    });
  });
}
