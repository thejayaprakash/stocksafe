import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/database.dart';
import '../models/in_app_notification.dart';
import 'license_service.dart';

/// Central Notification Service managing both In-App Notification Center
/// and Android OS System Push / Local Notifications.
///
/// Fully offline-first: monitors SQLite inventory thresholds, generates
/// actionable alerts, handles system notification channels, and persists user preferences.
class NotificationService extends ChangeNotifier {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String channelStockAlertsId = 'stocksafe_stock_alerts';
  static const String channelStockAlertsName = 'Stock Alerts & Reordering';
  static const String channelRemindersId = 'stocksafe_reminders';
  static const String channelRemindersName = 'Inventory Reminders';

  static const String keyMobilePushEnabled = 'notifications_mobile_enabled';
  static const String keyLowStockPushEnabled = 'notifications_low_stock_enabled';
  static const String keyRemindersPushEnabled = 'notifications_reminders_enabled';
  static const String keyReadIds = 'notifications_read_ids';
  static const String keyDismissedIds = 'notifications_dismissed_ids';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  AppDatabase? _db;

  bool _initialized = false;
  bool _mobilePushEnabled = true;
  bool _lowStockPushEnabled = true;
  bool _remindersPushEnabled = true;

  Set<String> _readIds = {};
  Set<String> _dismissedIds = {};

  // Track product stock levels that were already alerted to avoid spamming
  final Map<int, int> _lastAlertedStock = {};

  List<InAppNotification> _notifications = [];

  /// Current list of active, non-dismissed in-app notifications.
  List<InAppNotification> get notifications => List.unmodifiable(_notifications);

  /// Number of unread notifications.
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Whether there are any unread notifications.
  bool get hasUnread => unreadCount > 0;

  bool get mobilePushEnabled => _mobilePushEnabled;
  bool get lowStockPushEnabled => _lowStockPushEnabled;
  bool get remindersPushEnabled => _remindersPushEnabled;

  /// Initialize the notification service with the database and configure
  /// native Android notification channels.
  Future<void> init(AppDatabase db) async {
    final isNewDb = _db != db;
    _db = db;
    if (_initialized && !isNewDb) {
      await refreshFromDatabase();
      return;
    }

    await _loadPreferences();

    if (!_initialized) {
      try {
        const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
        const initSettings = InitializationSettings(android: androidInit);

        await _localNotifications.initialize(
          initSettings,
          onDidReceiveNotificationResponse: (response) {
            debugPrint('Notification clicked with payload: ${response.payload}');
          },
        );

        final android = _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (android != null) {
          await android.createNotificationChannel(
            const AndroidNotificationChannel(
              channelStockAlertsId,
              channelStockAlertsName,
              description:
                  'High-priority alerts when products fall below minimum stock or run out',
              importance: Importance.high,
              enableVibration: true,
              playSound: true,
            ),
          );

          await android.createNotificationChannel(
            const AndroidNotificationChannel(
              channelRemindersId,
              channelRemindersName,
              description:
                  'Reminders for physical stock counts, backups, and inventory safety',
              importance: Importance.defaultImportance,
              enableVibration: true,
              playSound: true,
            ),
          );
        }
      } catch (e) {
        debugPrint('Local notifications native initialization skipped/failed: $e');
      }

      _initialized = true;
    }

    await refreshFromDatabase();
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    _initialized = false;
    _db = null;
    _notifications = [];
    _readIds.clear();
    _dismissedIds.clear();
    _lastAlertedStock.clear();
  }

  /// Request runtime notification permissions on Android 13+ (API 33+).
  Future<bool> requestPermissions() async {
    try {
      final android = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Permission request error: $e');
    }
    return false;
  }

  /// Load persisted user settings and read/dismissed sets from SQLite settingDao.
  Future<void> _loadPreferences() async {
    if (_db == null) return;
    try {
      final mobileVal = await _db!.settingDao.get(keyMobilePushEnabled);
      if (mobileVal != null) _mobilePushEnabled = mobileVal == 'true';

      final lowStockVal = await _db!.settingDao.get(keyLowStockPushEnabled);
      if (lowStockVal != null) _lowStockPushEnabled = lowStockVal == 'true';

      final remindersVal = await _db!.settingDao.get(keyRemindersPushEnabled);
      if (remindersVal != null) _remindersPushEnabled = remindersVal == 'true';

      final readRaw = await _db!.settingDao.get(keyReadIds);
      if (readRaw != null && readRaw.isNotEmpty) {
        final list = (jsonDecode(readRaw) as List).cast<String>();
        _readIds = list.toSet();
      }

      final dismissedRaw = await _db!.settingDao.get(keyDismissedIds);
      if (dismissedRaw != null && dismissedRaw.isNotEmpty) {
        final list = (jsonDecode(dismissedRaw) as List).cast<String>();
        _dismissedIds = list.toSet();
      }
    } catch (e) {
      debugPrint('Error loading notification preferences: $e');
    }
  }

  Future<void> _saveReadIds() async {
    if (_db == null) return;
    try {
      await _db!.settingDao.set(keyReadIds, jsonEncode(_readIds.toList()));
    } catch (_) {}
  }

  Future<void> _saveDismissedIds() async {
    if (_db == null) return;
    try {
      await _db!.settingDao
          .set(keyDismissedIds, jsonEncode(_dismissedIds.toList()));
    } catch (_) {}
  }

  /// Update Mobile Push Master switch.
  Future<void> setMobilePushEnabled(bool enabled) async {
    _mobilePushEnabled = enabled;
    notifyListeners();
    if (_db != null) {
      await _db!.settingDao.set(keyMobilePushEnabled, enabled ? 'true' : 'false');
    }
    if (enabled) {
      await requestPermissions();
    }
  }

  /// Update Low Stock Push switch.
  Future<void> setLowStockPushEnabled(bool enabled) async {
    _lowStockPushEnabled = enabled;
    notifyListeners();
    if (_db != null) {
      await _db!.settingDao
          .set(keyLowStockPushEnabled, enabled ? 'true' : 'false');
    }
  }

  /// Update Reminders Push switch.
  Future<void> setRemindersPushEnabled(bool enabled) async {
    _remindersPushEnabled = enabled;
    notifyListeners();
    if (_db != null) {
      await _db!.settingDao
          .set(keyRemindersPushEnabled, enabled ? 'true' : 'false');
    }
  }

  /// Trigger a mobile notification to the OS notification drawer/lockscreen.
  Future<void> showMobileNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = channelStockAlertsId,
  }) async {
    if (!_mobilePushEnabled) return;
    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelId == channelStockAlertsId
            ? channelStockAlertsName
            : channelRemindersName,
        channelDescription:
            'Alerts for stock levels, audits, and backups in StockSafe',
        importance: channelId == channelStockAlertsId
            ? Importance.high
            : Importance.defaultImportance,
        priority: channelId == channelStockAlertsId
            ? Priority.high
            : Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      );
      final details = NotificationDetails(android: androidDetails);
      await _localNotifications.show(id, title, body, details, payload: payload);
    } catch (e) {
      debugPrint('Failed to send mobile notification: $e');
    }
  }

  /// Fire a test mobile notification so users can verify it works on their device.
  Future<void> showTestNotification() async {
    await showMobileNotification(
      id: 77777,
      title: '🔔 StockSafe Notification Test',
      body:
          'Mobile notifications are active! You will receive timely alerts for low stock and audit reminders.',
      payload: 'test_notification',
      channelId: channelStockAlertsId,
    );
  }

  /// Evaluates the current state of products and database reminders.
  Future<void> refreshFromDatabase() async {
    if (_db == null) return;
    try {
      final lowStock = await _db!.productDao.getLowStock();
      await _processLowStockUpdate(lowStock);
    } catch (e) {
      debugPrint('Error refreshing notifications from database: $e');
    }
  }

  Future<void> _processLowStockUpdate(List<Product> lowStockProducts) async {
    final List<InAppNotification> items = [];
    final now = DateTime.now();

    // 1. Stock items: Out of Stock and Low Stock
    for (final p in lowStockProducts) {
      final isOutOfStock = p.stockQty <= 0;
      final id = isOutOfStock ? 'out_of_stock_${p.id}' : 'low_stock_${p.id}';

      if (_dismissedIds.contains(id)) continue;

      final title = isOutOfStock
          ? 'Out of Stock: ${p.name}'
          : 'Low Stock Alert: ${p.name}';
      final body = isOutOfStock
          ? 'Current stock is 0 ${p.unit}. Reorder immediately to avoid stockouts.'
          : 'Stock is down to ${p.stockQty} ${p.unit} (Alert threshold: ${p.lowStockLevel} ${p.unit}).';

      items.add(
        InAppNotification(
          id: id,
          title: title,
          body: body,
          category: isOutOfStock
              ? NotificationCategory.outOfStock
              : NotificationCategory.lowStock,
          timestamp: p.updatedAt,
          isRead: _readIds.contains(id),
          productId: p.id,
          actionLabel: 'Reorder Now',
          actionRoute: 'low_stock',
        ),
      );

      // Trigger OS Mobile Notification if stock level changed or not alerted yet
      if (_mobilePushEnabled && _lowStockPushEnabled) {
        final lastAlerted = _lastAlertedStock[p.id];
        if (lastAlerted == null || lastAlerted != p.stockQty) {
          _lastAlertedStock[p.id] = p.stockQty;
          unawaited(showMobileNotification(
            id: p.id,
            title: title,
            body: body,
            payload: 'product_${p.id}',
            channelId: channelStockAlertsId,
          ));
        }
      }
    }

    // 2. Data Safety / Backup Reminder
    if (_db != null) {
      try {
        final lastBackupStr = await _db!.settingDao.get('last_backup_at');
        DateTime? lastBackup;
        if (lastBackupStr != null) {
          lastBackup = DateTime.tryParse(lastBackupStr);
        }

        final backupDays = lastBackup == null
            ? 999
            : now.difference(lastBackup).inDays;

        if (backupDays >= 7) {
          const id = 'backup_reminder_weekly';
          if (!_dismissedIds.contains(id)) {
            items.add(
              InAppNotification(
                id: id,
                title: 'Data Backup Recommended',
                body: lastBackup == null
                    ? 'You have not created a database snapshot yet. Back up your catalogue to prevent data loss.'
                    : 'Your last backup was $backupDays days ago. Create a fresh snapshot to keep your data safe.',
                category: NotificationCategory.backupReminder,
                timestamp: lastBackup ?? now.subtract(const Duration(days: 7)),
                isRead: _readIds.contains(id),
                actionLabel: 'Backup Now',
                actionRoute: 'backup',
              ),
            );
          }
        }
      } catch (_) {}
    }

    // 3. Pro Capacity Alert for Free Tier
    if (_db != null) {
      try {
        final license = LicenseService(_db!);
        final isPro = await license.isProUnlocked();
        if (!isPro) {
          final canAdd = await license.canAddProduct();
          if (!canAdd) {
            final cap = await license.getEffectiveCapacity();
            const id = 'capacity_reached_alert';
            if (!_dismissedIds.contains(id)) {
              items.add(
                InAppNotification(
                  id: id,
                  title: 'Free Product Limit Reached',
                  body:
                      'You have reached your limit of $cap products. Upgrade to Pro or watch rewarded ads to expand capacity.',
                  category: NotificationCategory.capacityAlert,
                  timestamp: now,
                  isRead: _readIds.contains(id),
                  actionLabel: 'Upgrade to Pro',
                  actionRoute: 'paywall',
                ),
              );
            }
          }
        }
      } catch (_) {}
    }

    // Sort newest first
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    items.removeWhere((n) => _dismissedIds.contains(n.id));

    _notifications = items;
    notifyListeners();
  }

  /// Mark an individual notification as read.
  Future<void> markAsRead(String id) async {
    _readIds.add(id);
    _notifications = _notifications.map((n) {
      if (n.id == id) return n.copyWith(isRead: true);
      return n;
    }).toList();
    notifyListeners();
    await _saveReadIds();
  }

  /// Mark all active notifications as read.
  Future<void> markAllAsRead() async {
    for (final n in _notifications) {
      _readIds.add(n.id);
    }
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
    await _saveReadIds();
  }

  /// Dismiss / delete an individual notification.
  Future<void> dismiss(String id) async {
    _dismissedIds.add(id);
    _notifications = _notifications.where((n) => n.id != id).toList();
    notifyListeners();
    await _saveDismissedIds();
  }

  /// Clear all current notifications.
  Future<void> clearAll() async {
    for (final n in _notifications) {
      _dismissedIds.add(n.id);
    }
    _notifications = [];
    notifyListeners();
    await _saveDismissedIds();
  }
}
