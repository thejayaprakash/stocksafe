import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/main.dart';
import 'package:stocksafe/src/app_scope.dart';
import 'package:stocksafe/src/data/database.dart';
import 'package:stocksafe/src/ui/initial_splash_screen.dart';

void main() {
  testWidgets('InitialSplashScreen renders brand elements',
      (WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      MaterialApp(
        home: AppScopeHost(
          createDatabase: () => db,
          builder: (_) => const InitialSplashScreen(
            animationDuration: Duration(milliseconds: 300),
          ),
        ),
      ),
    );
    await tester.pump();

    // Initial frame renders brand text
    expect(find.text('StockSafe'), findsOneWidget);
    expect(find.text('Offline Inventory & Audit'), findsOneWidget);

    // Advance clock through animation
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await db.close();
    await tester.pump();
  });

  testWidgets('InitialSplashScreen with skipAnimation renders HomePage',
      (WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      MaterialApp(
        home: AppScopeHost(
          createDatabase: () => db,
          builder: (_) => const InitialSplashScreen(
            skipAnimation: true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('StockSafe'), findsOneWidget);

    await db.close();
    await tester.pump();
  });

  testWidgets('StockSafeApp with showSplash: false opens directly into HomePage',
      (WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      StockSafeApp(
        createDatabase: () => db,
        showSplash: false,
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('StockSafe'), findsOneWidget);

    await db.close();
    await tester.pump();
  });
}
