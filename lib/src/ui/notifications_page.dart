import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/in_app_notification.dart';
import '../services/notification_service.dart';
import '../theme/app_palette.dart';
import 'backup_page.dart';
import 'low_stock_page.dart';
import 'widgets/paywall_sheet.dart';

/// Notification Center for StockSafe.
/// Displays categorized, actionable in-app notifications for stock shortages,
/// audit reminders, backup warnings, and license alerts.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

enum _FilterCategory { all, stock, reminders, system }

class _NotificationsPageState extends State<NotificationsPage> {
  _FilterCategory _selectedFilter = _FilterCategory.all;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notificationService = NotificationService.instance;

    return ListenableBuilder(
      listenable: notificationService,
      builder: (context, _) {
        final allItems = notificationService.notifications;
        final unreadCount = notificationService.unreadCount;

        final stockItems = allItems.where((n) =>
            n.category == NotificationCategory.outOfStock ||
            n.category == NotificationCategory.lowStock).toList();
        final reminderItems = allItems.where((n) =>
            n.category == NotificationCategory.auditReminder ||
            n.category == NotificationCategory.backupReminder).toList();
        final systemItems = allItems.where((n) =>
            n.category == NotificationCategory.capacityAlert ||
            n.category == NotificationCategory.system).toList();

        final filteredItems = switch (_selectedFilter) {
          _FilterCategory.all => allItems,
          _FilterCategory.stock => stockItems,
          _FilterCategory.reminders => reminderItems,
          _FilterCategory.system => systemItems,
        };

        return Scaffold(
          backgroundColor: palette.appBackground,
          appBar: AppBar(
            backgroundColor: palette.appBackground,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: palette.textPrimary),
              onPressed: () => Navigator.of(context).pop(),
            ),
            titleSpacing: 0,
            title: Row(
              children: [
                Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: palette.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      '$unreadCount new',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: palette.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (allItems.isNotEmpty) ...[
                if (unreadCount > 0)
                  IconButton(
                    icon: Icon(Icons.done_all_rounded, color: palette.textSecondary),
                    tooltip: 'Mark all as read',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      notificationService.markAllAsRead();
                    },
                  ),
                IconButton(
                  icon: Icon(Icons.delete_sweep_outlined, color: palette.textSecondary),
                  tooltip: 'Clear all',
                  onPressed: () => _confirmClearAll(context, notificationService),
                ),
              ],
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              // ── Filter Chips ───────────────────────────────────────
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildFilterChip(
                      label: 'All',
                      count: allItems.length,
                      filter: _FilterCategory.all,
                      palette: palette,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Stock Alerts',
                      count: stockItems.length,
                      filter: _FilterCategory.stock,
                      palette: palette,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Reminders',
                      count: reminderItems.length,
                      filter: _FilterCategory.reminders,
                      palette: palette,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'System',
                      count: systemItems.length,
                      filter: _FilterCategory.system,
                      palette: palette,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── Notification List or Empty State ────────────────────
              Expanded(
                child: filteredItems.isEmpty
                    ? _buildEmptyState(palette, isDark)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return _NotificationCard(
                            key: ValueKey(item.id),
                            item: item,
                            palette: palette,
                            isDark: isDark,
                            onTap: () {
                              notificationService.markAsRead(item.id);
                              _handleNotificationAction(context, item);
                            },
                            onDismiss: () {
                              HapticFeedback.lightImpact();
                              notificationService.dismiss(item.id);
                            },
                            onAction: () {
                              notificationService.markAsRead(item.id);
                              _handleNotificationAction(context, item);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required _FilterCategory filter,
    required AppPalette palette,
    required bool isDark,
  }) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = filter);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? palette.primary
              : isDark
                  ? palette.cardSurface
                  : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? palette.primary
                : isDark
                    ? palette.border
                    : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : palette.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.22)
                    : isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : palette.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppPalette palette, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: palette.brandSuccess.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: palette.brandSuccess.withValues(alpha: 0.28),
                ),
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                size: 40,
                color: palette.brandSuccess,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'All Caught Up!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have no active alerts in this category. All stock levels, audits, and backups are healthy.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNotificationAction(BuildContext context, InAppNotification item) {
    if (item.actionRoute == 'low_stock') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LowStockPage()),
      );
    } else if (item.actionRoute == 'backup') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BackupPage()),
      );
    } else if (item.actionRoute == 'paywall') {
      PaywallSheet.show(context);
    }
  }

  void _confirmClearAll(BuildContext context, NotificationService service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text(
          'This will dismiss all current alerts from your inbox. Fresh stock warnings will reappear if levels change.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              service.clearAll();
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

/// A single interactive notification card with swipe-to-dismiss.
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    super.key,
    required this.item,
    required this.palette,
    required this.isDark,
    required this.onTap,
    required this.onDismiss,
    required this.onAction,
  });

  final InAppNotification item;
  final AppPalette palette;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final style = _styleForCategory(item.category);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: palette.error.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: palette.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: !item.isRead
                ? style.accentColor.withValues(alpha: 0.45)
                : palette.border,
            width: !item.isRead ? 1.4 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top Header Row ─────────────────────────────────
                  Row(
                    children: [
                      // Icon container
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: style.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: style.accentColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Icon(style.icon, size: 18, color: style.accentColor),
                      ),
                      const SizedBox(width: 10),
                      // Category Tag
                      Text(
                        style.tag,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: style.accentColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      // Relative time
                      Text(
                        _formatRelativeTime(item.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.textTertiary,
                        ),
                      ),
                      if (!item.isRead) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: palette.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: palette.primary.withValues(alpha: 0.6),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ── Title & Body ────────────────────────────────────
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: palette.textSecondary,
                    ),
                  ),

                  // ── Action CTA Button Row ───────────────────────────
                  if (item.actionLabel != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FilledButton.tonal(
                          onPressed: onAction,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            minimumSize: const Size(0, 32),
                            backgroundColor: style.accentColor.withValues(alpha: 0.16),
                            foregroundColor: style.accentColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.actionLabel!,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_rounded, size: 14),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _CategoryStyle _styleForCategory(NotificationCategory cat) {
    switch (cat) {
      case NotificationCategory.outOfStock:
        return _CategoryStyle(
          icon: Icons.error_outline_rounded,
          tag: 'CRITICAL OUT OF STOCK',
          accentColor: palette.error,
        );
      case NotificationCategory.lowStock:
        return _CategoryStyle(
          icon: Icons.warning_amber_rounded,
          tag: 'LOW STOCK WARNING',
          accentColor: palette.warning,
        );
      case NotificationCategory.backupReminder:
        return _CategoryStyle(
          icon: Icons.shield_outlined,
          tag: 'DATA SAFETY',
          accentColor: const Color(0xFF06B6D4), // Cyan
        );
      case NotificationCategory.auditReminder:
        return _CategoryStyle(
          icon: Icons.fact_check_outlined,
          tag: 'PHYSICAL AUDIT',
          accentColor: palette.primary,
        );
      case NotificationCategory.capacityAlert:
        return _CategoryStyle(
          icon: Icons.workspace_premium_outlined,
          tag: 'CAPACITY ALERT',
          accentColor: const Color(0xFFF59E0B),
        );
      case NotificationCategory.system:
        return _CategoryStyle(
          icon: Icons.info_outline_rounded,
          tag: 'SYSTEM',
          accentColor: palette.textSecondary,
        );
    }
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}

class _CategoryStyle {
  const _CategoryStyle({
    required this.icon,
    required this.tag,
    required this.accentColor,
  });

  final IconData icon;
  final String tag;
  final Color accentColor;
}
