// `product.imagePath` points at a file on one device. A restore onto a new
// phone, an OS cache sweep, or a user clearing their gallery all leave the
// column set and the file gone — and the catalogue still has to be readable.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/main.dart';
import 'package:stocksafe/src/data/database.dart';

Future<void> openCatalogue(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(StockSafeApp(createDatabase: () => db));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Products').last);
  await tester.pumpAndSettle();
}

Future<void> addProduct(
  AppDatabase db,
  String name, {
  String? imagePath,
}) async {
  final now = DateTime(2026, 10, 1);
  await db.productDao.insertProduct(
    ProductsCompanion.insert(
      name: name,
      category: const Value('Dairy'),
      imagePath: Value(imagePath),
      createdAt: now,
      updatedAt: now,
    ),
  );
}

void main() {
  testWidgets('a product with no photo is shown by its initial',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await addProduct(db, 'Amul Ghee 1L');

    await openCatalogue(tester, db);

    expect(find.text('Amul Ghee 1L'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);

    await db.close();
    await tester.pump();
  });

  testWidgets('a photo that is no longer on this device falls back, '
      'it does not leave a hole in the list', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await addProduct(
      db,
      'Britannia Good Day 100g',
      imagePath: '/no/such/directory/gone.jpg',
    );

    await openCatalogue(tester, db);
    // Image.file reports the missing file asynchronously, so the fallback
    // appears a frame or two after the row does.
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Britannia Good Day 100g'), findsOneWidget);
    expect(find.text('B'), findsOneWidget,
        reason: 'the initial has to come back when the file cannot be read');

    await db.close();
    await tester.pump();
  });

  testWidgets('an empty string is treated as no photo at all', (tester) async {
    // A CSV import or a cleared field can leave '' rather than NULL, and
    // Image.file('') throws rather than calling errorBuilder.
    final db = AppDatabase(NativeDatabase.memory());
    await addProduct(db, 'Loose Jaggery', imagePath: '   ');

    await openCatalogue(tester, db);

    expect(tester.takeException(), isNull);
    expect(find.text('L'), findsOneWidget);

    await db.close();
    await tester.pump();
  });
}
