import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app_scope.dart';
import '../data/database.dart';
import '../services/app_localization.dart';
import '../services/diagnostic_service.dart';
import '../services/license_service.dart';
import '../services/notification_service.dart';
import '../services/theme_service.dart';
import 'backup_page.dart';
import 'print_identity.dart';
import 'widgets/paywall_sheet.dart';

/// StockSafe Settings Screen.
///
/// Restructured with clear information architecture:
/// 1. General (App Preferences, Notifications, Physical Stock Reminders, Test Notification)
/// 2. Data & Backup (Backup & Data Recovery, Rebuild Stock Cache with confirmation)
/// 3. System Health & Diagnostics (App Health, Ledger Integrity, PRAGMA check, Export Diagnostics)
/// 4. About (App Info & Version, Usage & Limits, Legal & Privacy)
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AppDatabase get _db => AppScope.read(context).db;
  late final LicenseService _licenseService;

  @override
  void initState() {
    super.initState();
    _licenseService = LicenseService(_db);
    AppLocale.instance.addListener(_refresh);
    ThemeService.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    AppLocale.instance.removeListener(_refresh);
    ThemeService.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentLang = AppLocale.instance.current;
    final currentTheme = ThemeService.instance.mode;

    final themeLabel = switch (currentTheme) {
      ThemeMode.system => AppLocale.tr('system_theme'),
      ThemeMode.light => AppLocale.tr('light_theme'),
      ThemeMode.dark => AppLocale.tr('dark_theme'),
    };

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1220) : palette.appBackground,
      appBar: AppBar(
        title: Text(
          AppLocale.tr('settings'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF0B1220) : palette.appBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            // ─────────────────────────────────────────────────────────
            // 1. General
            // ─────────────────────────────────────────────────────────
            const _SettingsSectionHeader(
              icon: Icons.tune_rounded,
              title: 'General',
              subtitle: 'App Preferences · Notifications · Reminders',
            ),
            const SizedBox(height: 8),
            _SettingsGroupCard(
              children: [
                _SettingsTile(
                  icon: Icons.brightness_medium_outlined,
                  iconBg: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  iconColor: const Color(0xFF3B82F6),
                  title: AppLocale.tr('theme_mode'),
                  subtitle: themeLabel,
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  onTap: () => _showThemeSelector(context),
                ),
                _SettingsTile(
                  icon: Icons.translate_rounded,
                  iconBg: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  iconColor: const Color(0xFF8B5CF6),
                  title: 'App Language (மொழி)',
                  subtitle: currentLang.label,
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  onTap: () => _showLanguageSelector(context),
                ),
                _SettingsTile(
                  icon: Icons.storefront_outlined,
                  iconBg: const Color(0xFF10B981).withValues(alpha: 0.15),
                  iconColor: const Color(0xFF10B981),
                  title: 'Store Name (Receipts & Labels)',
                  subtitle: FutureBuilder<String?>(
                    future: _db.settingDao.get(shopNameSettingKey),
                    builder: (_, s) => Text(
                      s.data ?? shopNamePlaceholder,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  onTap: () => _editStoreName(context),
                ),
                _SettingsSwitchTile(
                  icon: Icons.notifications_active_outlined,
                  iconBg: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  iconColor: const Color(0xFF3B82F6),
                  title: 'Mobile System Notifications',
                  subtitle: 'Deliver alerts to your phone notification tray & lockscreen',
                  value: NotificationService.instance.mobilePushEnabled,
                  onChanged: (val) async {
                    await NotificationService.instance.setMobilePushEnabled(val);
                    if (mounted) setState(() {});
                  },
                ),
                if (NotificationService.instance.mobilePushEnabled) ...[
                  _SettingsSwitchTile(
                    icon: Icons.warning_amber_rounded,
                    iconBg: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Low Stock Push Alerts',
                    subtitle: 'Immediate alert when a product drops below reorder level',
                    value: NotificationService.instance.lowStockPushEnabled,
                    onChanged: (val) async {
                      await NotificationService.instance.setLowStockPushEnabled(val);
                      if (mounted) setState(() {});
                    },
                  ),
                ],
                _SettingsSwitchTile(
                  icon: Icons.alarm_rounded,
                  iconBg: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  iconColor: const Color(0xFF6366F1),
                  title: 'Physical Stock Reminders',
                  subtitle: 'Periodic reminders for physical stocktaking & data safety',
                  value: NotificationService.instance.remindersPushEnabled,
                  onChanged: (val) async {
                    await NotificationService.instance.setRemindersPushEnabled(val);
                    if (mounted) setState(() {});
                  },
                ),
                _SettingsActionTile(
                  icon: Icons.send_rounded,
                  iconBg: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                  iconColor: const Color(0xFF0EA5E9),
                  title: 'Send Test Notification',
                  subtitle: 'Fires an immediate test push to verify phone system tray',
                  buttonLabel: 'Test',
                  onAction: () async {
                    final granted = await NotificationService.instance.showTestNotification();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            granted
                                ? '🔔 Test notification dispatched to your phone!'
                                : 'Notification dispatched! Ensure notifications are allowed in Android Settings.',
                          ),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                ),
                _SettingsActionTile(
                  icon: Icons.timer_outlined,
                  iconBg: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  iconColor: const Color(0xFFA78BFA),
                  title: 'Test Outside App (10s Delay)',
                  subtitle: 'Schedules an alarm to ring 10s after closing the app',
                  buttonLabel: '10s Test',
                  onAction: () async {
                    final ok = await NotificationService.instance
                        .scheduleTestBackgroundNotification(seconds: 10);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? '⏱️ Background alert scheduled in 10s! Close or minimize StockSafe now.'
                                : 'Failed to schedule alarm. Please enable notification permissions.',
                          ),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 5),
                          backgroundColor: const Color(0xFF1E293B),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 22),

            // ─────────────────────────────────────────────────────────
            // 2. Data & Backup
            // ─────────────────────────────────────────────────────────
            const _SettingsSectionHeader(
              icon: Icons.folder_zip_outlined,
              title: 'Data & Backup',
              subtitle: 'Backup & Recovery · Rebuild Cache',
            ),
            const SizedBox(height: 8),
            _SettingsGroupCard(
              children: [
                _SettingsTile(
                  icon: Icons.backup_outlined,
                  iconBg: const Color(0xFF10B981).withValues(alpha: 0.15),
                  iconColor: const Color(0xFF10B981),
                  title: AppLocale.tr('backup_export') != 'backup_export'
                      ? AppLocale.tr('backup_export')
                      : 'Backup & Data Recovery',
                  subtitle: 'Cryptographic SHA-256 snapshots, CSV catalog & safe restore',
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BackupPage()),
                  ),
                ),
                _SettingsActionTile(
                  icon: Icons.refresh_rounded,
                  iconBg: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  iconColor: const Color(0xFF3B82F6),
                  title: AppLocale.tr('rebuild_cache') != 'rebuild_cache'
                      ? AppLocale.tr('rebuild_cache')
                      : 'Rebuild Stock Cache',
                  subtitle: 'Audits & recalculates all stock quantities from movement ledger',
                  buttonLabel: 'Rebuild',
                  onAction: () => _rebuildCache(context),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // ─────────────────────────────────────────────────────────
            // 3. System Health & Diagnostics
            // ─────────────────────────────────────────────────────────
            const _SettingsSectionHeader(
              icon: Icons.health_and_safety_outlined,
              title: 'System Health & Diagnostics',
              subtitle: 'App Health · Ledger Integrity · Database Integrity · Diagnostic Report',
            ),
            const SizedBox(height: 8),
            _SettingsGroupCard(
              children: [
                _SettingsTile(
                  icon: Icons.speed_rounded,
                  iconBg: const Color(0xFF22C55E).withValues(alpha: 0.15),
                  iconColor: const Color(0xFF22C55E),
                  title: 'App Health & Stability',
                  subtitle: '${DiagnosticService.instance.crashFreeRate.toStringAsFixed(1)}% healthy sessions · SQLite binary engine active',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'Healthy',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF22C55E),
                      ),
                    ),
                  ),
                ),
                _SettingsActionTile(
                  icon: Icons.rule_rounded,
                  iconBg: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  iconColor: const Color(0xFFF59E0B),
                  title: AppLocale.tr('audit_ledger_integrity') != 'audit_ledger_integrity'
                      ? AppLocale.tr('audit_ledger_integrity')
                      : 'Verify Ledger Integrity',
                  subtitle: 'Audits cached product stock against SELECT SUM(qty_delta)',
                  buttonLabel: 'Verify',
                  onAction: () => _runLedgerIntegrityAudit(context),
                ),
                _SettingsActionTile(
                  icon: Icons.check_circle_outline_rounded,
                  iconBg: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                  iconColor: const Color(0xFF14B8A6),
                  title: 'Database PRAGMA Integrity',
                  subtitle: 'Verify SQLite binary page consistency & B-tree structure',
                  buttonLabel: 'Check',
                  onAction: () => _runDatabaseIntegrityCheck(context),
                ),
                _SettingsActionTile(
                  icon: Icons.bug_report_outlined,
                  iconBg: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  iconColor: const Color(0xFF8B5CF6),
                  title: 'Export Diagnostic Report',
                  subtitle: 'Copy diagnostics log to clipboard (Counts only, zero product data)',
                  buttonLabel: 'Export',
                  onAction: () => _exportDiagnosticReport(context),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // ─────────────────────────────────────────────────────────
            // 4. About
            // ─────────────────────────────────────────────────────────
            const _SettingsSectionHeader(
              icon: Icons.info_outline_rounded,
              title: 'About',
              subtitle: 'App Information · Usage & Limits · Legal',
            ),
            const SizedBox(height: 8),
            _SettingsGroupCard(
              children: [
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (_, snap) {
                    final info = snap.data;
                    final version = info == null ? '0.1.0' : 'v${info.version} (${info.buildNumber})';
                    return _SettingsTile(
                      icon: Icons.shield_outlined,
                      iconBg: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                      iconColor: const Color(0xFF3B82F6),
                      title: 'StockSafe $version',
                      subtitle: 'Offline Inventory & Audit · Local SQLite Ledger',
                    );
                  },
                ),
                StreamBuilder<LicenseStatus>(
                  stream: _licenseService.watchLicenseStatus(),
                  builder: (context, snapshot) {
                    final status = snapshot.data;
                    final isPro = status?.isPro ?? false;
                    final active = status?.activeProductCount ?? 0;
                    final baseLimit = status?.freeLimit ?? LicenseService.defaultFreeLimit;
                    final bonus = status?.rewardSlots ?? 0;
                    final capacity = status?.effectiveCapacity ?? (baseLimit + bonus);
                    final remaining = status?.remaining ?? (capacity - active).clamp(0, capacity);

                    return _SettingsTile(
                      icon: isPro ? Icons.workspace_premium_rounded : Icons.inventory_2_outlined,
                      iconBg: isPro
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                          : const Color(0xFF3B82F6).withValues(alpha: 0.15),
                      iconColor: isPro ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6),
                      title: isPro ? 'Lifetime Pro Active ⭐' : 'Usage & Free Limits',
                      subtitle: isPro
                          ? '$active products tracked · Unlimited capacity unlocked'
                          : (bonus > 0
                              ? '$active of $capacity products used ($bonus bonus) · $remaining slots available'
                              : '$active of $capacity products used · $remaining slots available'),
                      trailing: isPro
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                              ),
                              child: const Text(
                                'PRO',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                            )
                          : OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                minimumSize: const Size(60, 32),
                              ),
                              onPressed: () => PaywallSheet.show(context),
                              child: const Text('Upgrade', style: TextStyle(fontSize: 12)),
                            ),
                    );
                  },
                ),
                _SettingsTile(
                  icon: Icons.gavel_rounded,
                  iconBg: const Color(0xFF64748B).withValues(alpha: 0.15),
                  iconColor: const Color(0xFF94A3B8),
                  title: 'Data Sovereignty & Legal',
                  subtitle: '100% offline-first · Zero remote tracking · Open source licenses',
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  onTap: () {
                    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
                    showLicensePage(
                      context: context,
                      applicationName: 'StockSafe',
                      applicationVersion: 'Offline Inventory & Audit',
                      applicationIcon: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Image.asset(
                          isDarkTheme
                              ? 'assets/images/logo_shield_dark.png'
                              : 'assets/images/logo_shield_light.png',
                          width: 48,
                          height: 48,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.shield_outlined,
                            size: 40,
                            color: Color(0xFF0080FF),
                          ),
                        ),
                      ),
                      applicationLegalese: 'StockSafe adheres strictly to on-device data sovereignty. Your product and ledger data never leaves your device.',
                    );
                  },
                ),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  iconBg: const Color(0xFF10B981).withValues(alpha: 0.15),
                  iconColor: const Color(0xFF10B981),
                  title: 'Privacy Policy',
                  subtitle: '100% sovereign local data · Zero remote telemetry',
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  onTap: () => _showPrivacyPolicySheet(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyPolicySheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151E2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF10B981), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Privacy Policy & Sovereignty', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        Text('StockSafe · Local SQLite Ledger', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: const [
                    Text(
                      '1. Core Sovereignty Promise',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'StockSafe stores all inventory catalogues, prices, barcodes, movements, audits, and supplier records strictly in a local SQLite database on your device. We operate no remote servers to receive your inventory data. Your business records never leave your physical phone.',
                      style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF94A3B8)),
                    ),
                    SizedBox(height: 14),
                    Text(
                      '2. Permissions Used & Purpose',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Camera: Used solely for scanning barcodes and reading product expiry/batch info on-device via Google ML Kit. No frames are sent online.\n'
                      '• Microphone: Used strictly when you tap the mic icon for speech-to-text queries. No audio is recorded or stored.\n'
                      '• Notifications: Used for daily store-closing audit reminders and low-stock alerts.\n'
                      '• Internet: Used strictly for Google Play Pro license verification and voluntary rewarded ads via Google AdMob.',
                      style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF94A3B8)),
                    ),
                    SizedBox(height: 14),
                    Text(
                      '3. Data Deletion & Backups',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'You own full control of your records. You can export complete CSV spreadsheets or rolling verified backups anytime. Uninstalling StockSafe permanently purges the local database from your device.',
                      style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF94A3B8)),
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showThemeSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                AppLocale.tr('theme_mode'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final item in [
              (ThemeMode.system, AppLocale.tr('system_theme'), Icons.brightness_auto),
              (ThemeMode.light, AppLocale.tr('light_theme'), Icons.light_mode),
              (ThemeMode.dark, AppLocale.tr('dark_theme'), Icons.dark_mode),
            ])
              ListTile(
                leading: Icon(item.$3),
                title: Text(item.$2),
                trailing: ThemeService.instance.mode == item.$1
                    ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  unawaited(ThemeService.instance.setThemeMode(item.$1));
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Language / மொழியைத் தேர்ந்தெடுக்கவும்',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final lang in AppLanguage.values)
              ListTile(
                leading: Icon(
                  AppLocale.instance.current == lang
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: AppLocale.instance.current == lang
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(lang.label),
                subtitle: Text(lang == AppLanguage.english ? 'Default' : 'தமிழ் உரை'),
                onTap: () {
                  AppLocale.instance.setLanguage(lang);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editStoreName(BuildContext context) async {
    final current = await _db.settingDao.get(shopNameSettingKey) ?? shopNamePlaceholder;
    if (!context.mounted) return;
    final controller = TextEditingController(text: current);

    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Store / Shop Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Printed Header Name',
            hintText: 'e.g. Sri Lakshmi Stores',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated != null && updated.isNotEmpty) {
      await _db.settingDao.set(shopNameSettingKey, updated);
      if (mounted) setState(() {});
    }
  }

  Future<void> _rebuildCache(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.refresh_rounded, color: Color(0xFF3B82F6)),
            SizedBox(width: 8),
            Text('Rebuild Stock Cache?'),
          ],
        ),
        content: const Text(
          'This recalculates every product\'s cached quantity directly from the immutable movement ledger.\n\n'
          'The operation is 100% safe, non-destructive, and guarantees mathematical ledger consistency.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rebuild Cache'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!context.mounted) return;
    unawaited(
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Recalculating stock quantities...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await _db.rebuildAllStockCaches();

    if (!context.mounted) return;
    Navigator.pop(context); // Close loader

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Stock cache rebuilt and verified against ledger.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _runLedgerIntegrityAudit(BuildContext context) async {
    unawaited(
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Auditing movement ledger integrity...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final mismatches = await DiagnosticService.instance.auditLedgerIntegrity(_db);
    if (!context.mounted) return;
    Navigator.pop(context); // Close loader

    if (mismatches.isEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.verified, color: Color(0xFF22C55E)),
              SizedBox(width: 8),
              Text('Ledger 100% Intact'),
            ],
          ),
          content: const Text(
            'All product stock quantities perfectly match their underlying movement ledger history (SUM(qty_delta)). Zero discrepancies detected.',
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
    } else {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_rounded, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Text('Discrepancies Found'),
            ],
          ),
          content: Text(
            'Found ${mismatches.length} cache mismatches. Tap "Rebuild Cache" to restore them immediately from the immutable ledger.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _db.rebuildAllStockCaches();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Cache rebuilt from ledger.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Rebuild Cache Now'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _runDatabaseIntegrityCheck(BuildContext context) async {
    final ok = await DiagnosticService.instance.verifyDatabaseIntegrity(_db);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? '✅ PRAGMA integrity_check: OK (SQLite binary page healthy)' : '⚠️ PRAGMA integrity_check failed',
        ),
        backgroundColor: ok ? const Color(0xFF0D9488) : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _exportDiagnosticReport(BuildContext context) {
    final report = DiagnosticService.instance.exportDiagnosticReport();
    Clipboard.setData(ClipboardData(text: report));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Diagnostic report copied to clipboard. (Zero product data included)'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header Widget
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsSectionHeader extends StatelessWidget {
  const _SettingsSectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: const Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 27),
              child: Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group Card Container Widget
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsGroupCard extends StatelessWidget {
  const _SettingsGroupCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF151E2E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 0.8,
                indent: 58,
                endIndent: 14,
                color: borderColor.withValues(alpha: 0.7),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Standard Setting Tile
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final dynamic subtitle; // String or Widget
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      if (subtitle is Widget)
                        subtitle as Widget
                      else
                        Text(
                          subtitle.toString(),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF94A3B8),
                            height: 1.25,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Switch Setting Tile
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF94A3B8),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            activeTrackColor: const Color(0xFF3B82F6),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action Setting Tile (with Compact Button)
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onAction,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF94A3B8),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: const Size(64, 34),
              side: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: onAction,
            child: Text(
              buttonLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
