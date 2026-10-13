import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/main.dart';
import 'package:stocksafe/src/data/database.dart';

void main() {
  testWidgets('StockSafeApp renders', (WidgetTester tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(StockSafeApp(db: db));
    await tester.pumpAndSettle();
    expect(find.text('StockSafe'), findsOneWidget);
    await db.close();
  });
}
