import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/main.dart';
import 'package:stocksafe/src/app_scope.dart';
import 'package:stocksafe/src/data/database.dart';
import 'package:stocksafe/src/theme/app_palette.dart';
import 'package:stocksafe/src/ui/widgets/dashboard_inventory_overview.dart';
import 'package:stocksafe/src/ui/widgets/dashboard_stock_health.dart';
import 'package:stocksafe/src/ui/widgets/dashboard_top_products.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark().copyWith(
      extensions: const [AppPalette.dark],
    ),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('DashboardStockHealthCard', () {
    testWidgets('renders empty inventory banner when totalProducts is 0',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          DashboardStockHealthCard(
            lowStock: const [],
            totalProducts: 0,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('No inventory yet'), findsOneWidget);
      expect(
        find.text('Add your first product to get started'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
    });

    testWidgets('renders optimal status when low stock list is empty and totalProducts > 0',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          DashboardStockHealthCard(
            lowStock: const [],
            totalProducts: 15,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('All stock levels optimal'), findsOneWidget);
      expect(
        find.text('15 products · No critical shortages'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('renders warning status when low stock exists', (tester) async {
      final now = DateTime.now();
      final p = Product(
        id: 1,
        name: 'Turmeric Powder',
        stockQty: 3,
        lowStockLevel: 5,
        unit: 'pcs',
        buyPrice: 10,
        sellPrice: 15,
        isFavourite: false,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        _wrap(
          DashboardStockHealthCard(
            lowStock: [p],
            totalProducts: 10,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('1 product needs reordering'), findsOneWidget);
      expect(
        find.text('Below reorder threshold · Tap to review'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  });

  group('DashboardInventoryOverview', () {
    testWidgets('displays all 4 metrics accurately', (tester) async {
      const summary = InventoryValuationSummary(
        totalProducts: 24,
        totalUnits: 1250,
        totalCostValue: 15000,
        totalRetailValue: 24500,
        potentialProfit: 9500,
        marginPercent: 63.3,
      );

      await tester.pumpWidget(
        _wrap(
          DashboardInventoryOverview(
            valuation: summary,
            lowStockCount: 4,
            onTapProducts: () {},
            onTapLowStock: () {},
          ),
        ),
      );

      expect(find.text('Inventory Overview'), findsOneWidget);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
      expect(find.text('Total Units'), findsOneWidget);
      expect(find.text('1,250'), findsOneWidget);
      expect(find.text('Inventory Value'), findsOneWidget);
      expect(find.text('₹24,500'), findsOneWidget);
      expect(find.text('Low Stock'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });
  });

  group('DashboardTopProducts', () {
    testWidgets('renders empty banner when product list is empty',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          DashboardTopProducts(
            products: const [],
            onViewAll: () {},
            onAddProduct: () {},
          ),
        ),
      );

      expect(find.text('Top Products'), findsOneWidget);
      expect(find.text('No products added yet'), findsOneWidget);
      expect(find.text('Add First Product'), findsOneWidget);
    });

    testWidgets('renders product cards in horizontal carousel', (tester) async {
      final now = DateTime.now();
      final products = [
        Product(
          id: 1,
          name: 'Aachi Chilli Powder',
          stockQty: 15,
          lowStockLevel: 5,
          unit: 'pcs',
          buyPrice: 20,
          sellPrice: 30,
          isFavourite: false,
          createdAt: now,
          updatedAt: now,
        ),
        Product(
          id: 2,
          name: 'Turmeric Powder',
          stockQty: 5,
          lowStockLevel: 10,
          unit: 'pcs',
          buyPrice: 15,
          sellPrice: 25,
          isFavourite: false,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          DashboardTopProducts(
            products: products,
            onViewAll: () {},
            onAddProduct: () {},
          ),
        ),
      );

      expect(find.text('Top Products'), findsOneWidget);
      expect(find.text('Aachi Chilli Powder'), findsOneWidget);
      expect(find.text('15 pcs'), findsOneWidget);
      expect(find.text('Turmeric Powder'), findsOneWidget);
      expect(find.text('5 pcs'), findsOneWidget);
    });
  });

  group('E2E Dashboard Rendering', () {
    testWidgets('StockSafeApp renders complete redesigned dashboard hierarchy',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        StockSafeApp(
          createDatabase: () => AppDatabase(NativeDatabase.memory()),
        ),
      );
      await tester.pumpAndSettle();

      final host =
          AppScope.of(tester.element(find.text('StockSafe'))).host;

      // Section 1: Header (includes dedicated AI icon, Notifications, Settings)
      expect(find.text('StockSafe'), findsOneWidget);
      expect(find.text('Offline Inventory & Audit'), findsOneWidget);
      expect(find.byTooltip('Ask StockSafe AI'), findsOneWidget);

      // Section 2: Stock Health Empty Banner
      expect(find.text('No inventory yet'), findsOneWidget);
      expect(find.text('Add your first product to get started'), findsOneWidget);

      // Section 3: Inventory Overview & Bottom Bar
      expect(find.text('Inventory Overview'), findsOneWidget);
      expect(find.text('Products'), findsNWidgets(2)); // Metric card & bottom nav
      expect(find.text('Total Units'), findsOneWidget);
      expect(find.text('Inventory Value'), findsOneWidget);
      expect(find.text('Low Stock'), findsOneWidget);

      // Section 4: Quick Actions
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Scan & Adjust'), findsOneWidget);
      expect(find.text('Physical Audit'), findsOneWidget);
      expect(find.text('Add Product'), findsNWidgets(2)); // Quick action tile & empty CTA
      expect(find.text('Sync Data'), findsOneWidget);

      // Empty State Illustration & CTAs
      expect(find.text('No products yet'), findsOneWidget);
      expect(find.text('Scan Barcode Instead'), findsOneWidget);

      // Populated-only sections should be hidden
      expect(find.text('SPONSORED'), findsNothing);
      expect(find.text('Top Products'), findsNothing);
      expect(find.text('Recent Stock Activity'), findsNothing);

      // Section 8: Bottom Navigation
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      expect(find.text('Stock Count'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);

      // Now insert a product and verify dynamic switch to populated dashboard
      final now = DateTime.now();
      await host.db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: 'Coriander Powder',
          unit: const Value('pcs'),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await tester.pumpAndSettle();

      // Populated stock health
      expect(find.text('All stock levels optimal'), findsOneWidget);

      // Populated Ad Section
      expect(find.text('Earn Free Product Slots'), findsOneWidget);
      expect(find.text('SPONSORED'), findsOneWidget);

      // Populated Top Products & Activity
      expect(find.text('Top Products'), findsOneWidget);
      expect(find.text('Recent Stock Activity'), findsOneWidget);

      // Empty-only section must now be hidden
      expect(find.text('No products yet'), findsNothing);
      expect(find.text('Scan Barcode Instead'), findsNothing);

      await host.db.close();
      await tester.pump();
    });
  });
}
