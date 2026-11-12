import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/app_scope.dart';
import 'package:stocksafe/src/data/database.dart';
import 'package:stocksafe/src/theme/app_palette.dart';
import 'package:stocksafe/src/ui/more_page.dart';

Future<void> withMorePage(
  WidgetTester tester,
  Future<void> Function(DatabaseHost host, AppDatabase db) body, {
  Size physicalSize = const Size(1080, 2400),
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  final host = DatabaseHost(() => db);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 2.0;

  try {
    await tester.pumpWidget(
      AppScope(
        host: host,
        child: MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: const [AppPalette.dark],
          ),
          home: const MorePage(),
        ),
      ),
    );
    await tester.pump();

    await body(host, db);
  } finally {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await db.close();
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MorePage Redesign Widget Tests', () {
    testWidgets('renders header branding, title and subtitle', (tester) async {
      await withMorePage(tester, (host, db) async {
        expect(find.text('More Operations & Tools'), findsOneWidget);
        expect(
          find.text('Powerful tools to manage, reorder, and grow your inventory.'),
          findsOneWidget,
        );
      });
    });

    testWidgets('renders Pro upgrade banner with lifetime price and capacity info', (tester) async {
      await withMorePage(tester, (host, db) async {
        expect(find.text('Upgrade to Pro — ₹499 Lifetime'), findsOneWidget);
        expect(find.text('👑 Pro'), findsOneWidget);
        expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
      });
    });

    testWidgets('renders Operations & Reordering section with Low Stock and Suppliers cards', (tester) async {
      await withMorePage(tester, (host, db) async {
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
    });

    testWidgets('renders Printing & Labels section with Barcode Sticker Printing', (tester) async {
      await withMorePage(tester, (host, db) async {
        expect(find.text('Printing & Labels'), findsOneWidget);
        expect(find.text('Barcode Sticker Printing'), findsOneWidget);
        expect(find.byIcon(Icons.qr_code_2_rounded), findsOneWidget);
        expect(find.text('CODE 128'), findsOneWidget);
      });
    });

    testWidgets('renders AI Assistant section with Ask StockSafe AI and 3 question chips', (tester) async {
      await withMorePage(tester, (host, db) async {
        expect(find.text('AI Assistant'), findsOneWidget);
        expect(find.text('Ask StockSafe AI'), findsOneWidget);
        expect(find.text('Ask StockSafe AI →'), findsOneWidget);

        expect(find.text('Which products are running low?'), findsOneWidget);
        expect(find.text('What is my total inventory valuation?'), findsOneWidget);
        expect(find.text('Which products need restocking?'), findsOneWidget);
      });
    });

    testWidgets('renders Help and Data & System tools', (tester) async {
      await withMorePage(
        tester,
        (host, db) async {
          expect(find.text('Help'), findsOneWidget);
          expect(find.text('Report a problem'), findsOneWidget);

          expect(find.text('Data & System'), findsOneWidget);
          expect(find.text('Backup & Data Recovery'), findsOneWidget);
          expect(find.text('Settings'), findsOneWidget);
        },
        physicalSize: const Size(1080, 3600),
      );
    });
  });
}
