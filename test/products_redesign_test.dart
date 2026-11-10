import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/app_scope.dart';
import 'package:stocksafe/src/data/database.dart';
import 'package:stocksafe/src/theme/app_palette.dart';
import 'package:stocksafe/src/ui/widgets/product_grid_card.dart';

Widget _wrap(Widget child, DatabaseHost host) {
  return AppScope(
    host: host,
    child: MaterialApp(
      theme: ThemeData.dark().copyWith(
        extensions: const [AppPalette.dark],
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 180,
            height: 260,
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProductGridCard Widget', () {
    late DatabaseHost host;
    final now = DateTime(2026, 11, 10);

    setUp(() {
      host = DatabaseHost(() => AppDatabase(NativeDatabase.memory()));
    });

    tearDown(() async {
      await host.dispose();
    });

    final inStockProduct = Product(
      id: 1,
      name: 'Aachi Chilli Powder',
      sku: 'ACP-001',
      unit: 'pcs',
      stockQty: 15,
      lowStockLevel: 5,
      buyPrice: 380,
      sellPrice: 450,
      category: 'Spices',
      isFavourite: false,
      createdAt: now,
      updatedAt: now,
    );

    final lowStockProduct = Product(
      id: 2,
      name: 'Aachi Turmeric Powder',
      sku: 'ATP-002',
      unit: 'pcs',
      stockQty: 5,
      lowStockLevel: 5,
      buyPrice: 120,
      sellPrice: 150,
      category: 'Spices',
      isFavourite: true,
      createdAt: now,
      updatedAt: now,
    );

    final outOfStockProduct = Product(
      id: 3,
      name: 'Cinnamon Sticks',
      sku: 'CIN-007',
      unit: 'kg',
      stockQty: 0,
      lowStockLevel: 2,
      buyPrice: 600,
      sellPrice: 720,
      category: 'Spices',
      isFavourite: false,
      createdAt: now,
      updatedAt: now,
    );

    testWidgets('renders in-stock product details, SKU, quantity and price correctly', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProductGridCard(
            product: inStockProduct,
            onTap: () {},
          ),
          host,
        ),
      );

      expect(find.text('Aachi Chilli Powder'), findsOneWidget);
      expect(find.text('SKU: ACP-001'), findsOneWidget);
      expect(find.text('In Stock'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('15 pcs'), findsOneWidget);
      expect(find.text('₹450'), findsOneWidget);
    });

    testWidgets('renders low stock warning state accurately', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProductGridCard(
            product: lowStockProduct,
            onTap: () {},
          ),
          host,
        ),
      );

      expect(find.text('Aachi Turmeric Powder'), findsOneWidget);
      expect(find.text('SKU: ATP-002'), findsOneWidget);
      expect(find.text('Low Stock'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('₹150'), findsOneWidget);
    });

    testWidgets('renders out of stock danger state accurately', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProductGridCard(
            product: outOfStockProduct,
            onTap: () {},
          ),
          host,
        ),
      );

      expect(find.text('Cinnamon Sticks'), findsOneWidget);
      expect(find.text('SKU: CIN-007'), findsOneWidget);
      expect(find.text('Out of Stock'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('0 kg'), findsOneWidget);
      expect(find.text('₹720'), findsOneWidget);
    });

    testWidgets('triggers onTap callback when card is pressed', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          ProductGridCard(
            product: inStockProduct,
            onTap: () => tapped = true,
          ),
          host,
        ),
      );

      await tester.tap(find.text('Aachi Chilli Powder'));
      expect(tapped, isTrue);
    });

    testWidgets('supports selection mode and checkbox toggle', (tester) async {
      var selectedId = 0;
      await tester.pumpWidget(
        _wrap(
          ProductGridCard(
            product: inStockProduct,
            selectionMode: true,
            selected: true,
            onTap: () {},
            onToggleSelected: (id) => selectedId = id,
          ),
          host,
        ),
      );

      expect(find.byType(Checkbox), findsOneWidget);
      await tester.tap(find.text('Aachi Chilli Powder'));
      expect(selectedId, equals(1));
    });
  });
}
