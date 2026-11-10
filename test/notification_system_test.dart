import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/app_scope.dart';
import 'package:stocksafe/src/data/database.dart';
import 'package:stocksafe/src/models/in_app_notification.dart';
import 'package:stocksafe/src/services/notification_service.dart';
import 'package:stocksafe/src/theme/app_palette.dart';
import 'package:stocksafe/src/ui/notifications_page.dart';

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

  group('Notification System Tests', () {
    late AppDatabase db;
    late DatabaseHost host;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      host = DatabaseHost(() => db);
    });

    tearDown(() async {
      await NotificationService.instance.resetForTesting();
      await host.dispose();
    });

    test('InAppNotification serialization and copyWith', () {
      final now = DateTime.now();
      final item = InAppNotification(
        id: 'test_1',
        title: 'Low Stock Alert',
        body: 'Stock is low',
        category: NotificationCategory.lowStock,
        timestamp: now,
        isRead: false,
        productId: 42,
        actionLabel: 'Reorder Now',
        actionRoute: 'low_stock',
      );

      final json = item.toJson();
      final revived = InAppNotification.fromJson(json);

      expect(revived.id, 'test_1');
      expect(revived.title, 'Low Stock Alert');
      expect(revived.body, 'Stock is low');
      expect(revived.category, NotificationCategory.lowStock);
      expect(revived.isRead, false);
      expect(revived.productId, 42);

      final updated = revived.copyWith(isRead: true);
      expect(updated.isRead, true);
    });

    test('NotificationService detects low stock and out of stock products', () async {
      final service = NotificationService.instance;
      await service.init(db);

      final now = DateTime(2026, 4, 1);

      // Insert product with stock <= lowStockLevel (Low stock)
      final p1Id = await db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: 'Turmeric Powder',
          category: const Value('Spices'),
          unit: const Value('pcs'),
          stockQty: const Value(3),
          lowStockLevel: const Value(10),
          buyPrice: const Value(50),
          sellPrice: const Value(70),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Insert product with stock = 0 (Out of stock)
      final p2Id = await db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: 'Coriander Seeds',
          category: const Value('Spices'),
          unit: const Value('kg'),
          stockQty: const Value(0),
          lowStockLevel: const Value(5),
          buyPrice: const Value(120),
          sellPrice: const Value(160),
          createdAt: now,
          updatedAt: now,
        ),
      );

      await service.refreshFromDatabase();

      expect(service.notifications.any((n) => n.productId == p1Id), isTrue);
      expect(service.notifications.any((n) => n.productId == p2Id), isTrue);

      final lowStockItem = service.notifications.firstWhere((n) => n.productId == p1Id);
      expect(lowStockItem.category, NotificationCategory.lowStock);
      expect(lowStockItem.title, contains('Low Stock Alert'));

      final outOfStockItem = service.notifications.firstWhere((n) => n.productId == p2Id);
      expect(outOfStockItem.category, NotificationCategory.outOfStock);
      expect(outOfStockItem.title, contains('Out of Stock'));

      // Test mark as read
      expect(lowStockItem.isRead, isFalse);
      await service.markAsRead(lowStockItem.id);
      expect(service.notifications.firstWhere((n) => n.id == lowStockItem.id).isRead, isTrue);

      // Test dismiss
      final dismissedId = lowStockItem.id;
      await service.dismiss(dismissedId);
      expect(service.notifications.any((n) => n.id == dismissedId), isFalse,
          reason: 'Expected $dismissedId to be dismissed, current: ${service.notifications.map((n) => n.id).toList()}');
    });

    test('NotificationService preference toggles persist correctly', () async {
      final service = NotificationService.instance;
      await service.init(db);

      await service.setMobilePushEnabled(false);
      expect(service.mobilePushEnabled, isFalse);

      await service.setLowStockPushEnabled(false);
      expect(service.lowStockPushEnabled, isFalse);

      await service.setRemindersPushEnabled(false);
      expect(service.remindersPushEnabled, isFalse);

      // Re-enable
      await service.setMobilePushEnabled(true);
      expect(service.mobilePushEnabled, isTrue);
    });

    testWidgets('NotificationsPage renders app bar, filter chips, and empty state',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = NotificationService.instance;
      await service.init(db);
      await service.clearAll();

      await tester.pumpWidget(_wrap(const NotificationsPage(), host));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Stock Alerts'), findsOneWidget);
      expect(find.text('Reminders'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);

      final texts = tester.allWidgets.whereType<Text>().map((t) => t.data).toList();
      expect(find.text('All Caught Up!'), findsOneWidget, reason: 'Rendered texts: $texts');
    });

    testWidgets('NotificationsPage displays notification cards with actions',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = NotificationService.instance;
      await service.init(db);

      final now = DateTime(2026, 4, 1);

      // Insert an out of stock product
      await db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: 'Black Pepper',
          category: const Value('Spices'),
          unit: const Value('pcs'),
          stockQty: const Value(0),
          lowStockLevel: const Value(5),
          buyPrice: const Value(80),
          sellPrice: const Value(110),
          createdAt: now,
          updatedAt: now,
        ),
      );

      await service.refreshFromDatabase();

      await tester.pumpWidget(_wrap(const NotificationsPage(), host));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.textContaining('Black Pepper'), findsOneWidget);
      expect(find.text('CRITICAL OUT OF STOCK'), findsOneWidget);
      expect(find.text('Reorder Now'), findsOneWidget);
    });
  });
}
