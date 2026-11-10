import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/app_scope.dart';
import 'package:stocksafe/src/data/database.dart';
import 'package:stocksafe/src/theme/app_palette.dart';
import 'package:stocksafe/src/ui/more_page.dart';

Widget _wrap(Widget child, DatabaseHost host) {
  return AppScope(
    host: host,
    child: MaterialApp(
      theme: ThemeData.dark().copyWith(
        extensions: const [AppPalette.dark],
      ),
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MorePage Redesign Widget Tests', () {
    late DatabaseHost host;

    setUp(() {
      host = DatabaseHost(() => AppDatabase(NativeDatabase.memory()));
    });

    tearDown(() async {
      await host.dispose();
    });

    testWidgets('renders header branding, title and subtitle', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(const MorePage(), host));
      await tester.pumpAndSettle();

      expect(find.text('More Operations & Tools'), findsOneWidget);
      expect(
        find.text('Powerful tools to manage, reorder, and grow your inventory.'),
        findsOneWidget,
      );
    });

    testWidgets('renders Pro upgrade banner with lifetime price and capacity info', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(const MorePage(), host));
      await tester.pumpAndSettle();

      expect(find.text('Upgrade to Pro — ₹499 Lifetime'), findsOneWidget);
      expect(find.text('👑 Pro'), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
    });

    testWidgets('renders Operations & Reordering section with Low Stock and Suppliers cards', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(const MorePage(), host));
      await tester.pumpAndSettle();

      expect(find.text('Operations & Reordering'), findsOneWidget);
      expect(find.text('Low Stock'), findsOneWidget);
      expect(
        find.text('Get smart reorder recommendations & alerts before you run out.'),
        findsOneWidget,
      );

      expect(find.text('Suppliers & Vendors'), findsOneWidget);
      expect(
        find.text('Manage your supplier list, create purchase orders, and share PO on WhatsApp.'),
        findsOneWidget,
      );

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.byIcon(Icons.local_shipping_rounded), findsOneWidget);
    });

    testWidgets('renders Printing & Labels section with Barcode Sticker Printing', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(const MorePage(), host));
      await tester.pumpAndSettle();

      expect(find.text('Printing & Labels'), findsOneWidget);
      expect(find.text('Barcode Sticker Printing'), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_2_rounded), findsOneWidget);
      expect(find.text('CODE 128'), findsOneWidget);
    });

    testWidgets('renders AI Assistant section with Ask StockSafe AI and 3 question chips', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(const MorePage(), host));
      await tester.pumpAndSettle();

      expect(find.text('AI Assistant'), findsOneWidget);
      expect(find.text('Ask StockSafe AI'), findsOneWidget);
      expect(find.text('Ask StockSafe AI →'), findsOneWidget);

      expect(find.text('Which products are running low?'), findsOneWidget);
      expect(find.text('What is my total inventory valuation?'), findsOneWidget);
      expect(find.text('Which products need restocking?'), findsOneWidget);
    });

    testWidgets('renders Help and Data & System tools', (tester) async {
      tester.view.physicalSize = const Size(1080, 3600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(const MorePage(), host));
      await tester.pumpAndSettle();

      expect(find.text('Help'), findsOneWidget);
      expect(find.text('Report a problem'), findsOneWidget);

      expect(find.text('Data & System'), findsOneWidget);
      expect(find.text('Backup & Data Recovery'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });
  });
}
