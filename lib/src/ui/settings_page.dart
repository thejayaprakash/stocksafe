import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/database.dart';
import '../services/app_localization.dart';
import '../services/diagnostic_service.dart';
import '../services/license_service.dart';
import '../services/theme_service.dart';
import 'backup_page.dart';
import 'barcode_label_print_page.dart';
import 'suppliers_page.dart';
import 'widgets/paywall_sheet.dart';
import '../app_scope.dart';

/// App settings: language, appearance/theming, Pro licensing, operations, diagnostics, cache rebuild, backup, about.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  /// The live database, read through the scope rather than passed in.
  /// Uses [AppScope.read] so it is safe to call from initState; widgets that
  /// must rebuild when the connection is replaced should call AppScope.of in
  /// build instead.
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
    final currentLang = AppLocale.instance.current;
    final currentTheme = ThemeService.instance.mode;

    final themeLabel = switch (currentTheme) {
      ThemeMode.system => AppLocale.tr('system_theme'),
      ThemeMode.light => AppLocale.tr('light_theme'),
      ThemeMode.dark => AppLocale.tr('dark_theme'),
    };

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // ── StockSafe Pro & License ───────────────────────────
        _SectionHeader(title: 'StockSafe Pro & License', icon: Icons.workspace_premium),
        // One reactive source rather than two nested FutureBuilders that
        // never refreshed, and no hardcoded 50: the limit is configurable,
        // so printing it literally meant changing it had no visible effect.
        StreamBuilder<LicenseStatus>(
          stream: _licenseService.watchLicenseStatus(),
          builder: (context, snapshot) {
            final status = snapshot.data;
            final isPro = status?.isPro ?? false;
            final active = status?.activeProductCount ?? 0;
            final limit = status?.freeLimit ?? LicenseService.defaultFreeLimit;
            return Builder(
              builder: (context) {
                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isPro
                          ? [Colors.amber.shade800.withValues(alpha: 0.15), Colors.amber.shade600.withValues(alpha: 0.05)]
                          : [Colors.green.shade800.withValues(alpha: 0.1), Colors.teal.shade700.withValues(alpha: 0.05)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isPro ? Colors.amber.shade600 : Colors.green.shade600.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isPro ? Icons.verified : Icons.stars,
                            color: isPro ? Colors.amber.shade700 : Colors.green.shade700,
                            size: 26,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isPro
                                      ? 'Lifetime Pro Active ⭐'
                                      : 'Free Tier (Max $limit Products)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  isPro
                                      ? 'Unlimited products & premium operations unlocked'
                                      : '$active / $limit products used',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          if (!isPro)
                            FilledButton(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              onPressed: () async {
                                final unlocked = await PaywallSheet.show(context);
                                if (unlocked == true && mounted) setState(() {});
                              },
                              child: const Text('Upgrade'),
                            ),
                        ],
                      ),
                      if (!isPro) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (active / limit).clamp(0.0, 1.0),
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              active >= limit
                                  ? Colors.red
                                  : (active >= limit * 0.8
                                      ? Colors.orange
                                      : Colors.green),
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),

        const Divider(height: 24),

        // ── Appearance & Language ─────────────────────────────
        _SectionHeader(title: AppLocale.tr('appearance'), icon: Icons.palette_outlined),
        ListTile(
          leading: const Icon(Icons.brightness_medium_outlined),
          title: Text(AppLocale.tr('theme_mode')),
          subtitle: Text(themeLabel),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showThemeSelector(context),
        ),
        ListTile(
          leading: const Icon(Icons.translate),
          title: const Text('App Language (மொழி)'),
          subtitle: Text(currentLang.label),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showLanguageSelector(context),
        ),

        const Divider(height: 24),

        // ── Operations & Printing ─────────────────────────────
        _SectionHeader(title: 'Operations & Printing', icon: Icons.precision_manufacturing_outlined),
        ListTile(
          leading: const Icon(Icons.contact_phone_outlined),
          title: Text(AppLocale.tr('suppliers')),
          subtitle: const Text('Vendor contact directory with tap-to-call for restocks'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SuppliersPage()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.qr_code_2),
          title: Text(AppLocale.tr('barcode_label_printing')),
          subtitle: const Text('Generate PDF sticker sheets (Code 128 / QR) for loose goods'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BarcodeLabelPrintPage()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.storefront_outlined),
          title: const Text('Store Name (Receipts & Labels)'),
          subtitle: FutureBuilder<String?>(
            future: _db.settingDao.get('shop_name'),
            builder: (_, s) => Text(s.data ?? 'STOCKSAFE KIRANA'),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _editStoreName(context),
        ),

        const Divider(height: 24),

        // ── Data & Ledger ─────────────────────────────────────
        _SectionHeader(title: 'Data & Sovereignty', icon: Icons.storage_outlined),
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: Text(AppLocale.tr('backup_export')),
          subtitle: const Text('Verified snapshots, CSV export & import'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BackupPage()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.refresh),
          title: Text(AppLocale.tr('rebuild_cache')),
          subtitle: const Text(
            'Recalculates all stock quantities from the movement ledger. Safe and fast.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _rebuildCache(context),
        ),

        const Divider(height: 24),

        // ── System Health & Diagnostics ───────────────────────
        _SectionHeader(title: AppLocale.tr('system_health'), icon: Icons.health_and_safety_outlined),
        ListTile(
          leading: const Icon(Icons.speed, color: Colors.green),
          title: Text(AppLocale.tr('crash_free_rate')),
          subtitle: Text('${DiagnosticService.instance.crashFreeRate.toStringAsFixed(1)}% healthy sessions'),
        ),
        ListTile(
          leading: const Icon(Icons.rule_outlined),
          title: Text(AppLocale.tr('audit_ledger_integrity')),
          subtitle: const Text('Audits cached product stock against SELECT SUM(qty_delta)'),
          trailing: const Icon(Icons.play_arrow_outlined),
          onTap: () => _runLedgerIntegrityAudit(context),
        ),
        ListTile(
          leading: const Icon(Icons.check_circle_outline, color: Colors.teal),
          title: const Text('Database PRAGMA Integrity'),
          subtitle: const Text('Verify SQLite binary page consistency'),
          trailing: const Icon(Icons.play_arrow_outlined),
          onTap: () => _runDatabaseIntegrityCheck(context),
        ),
        ListTile(
          leading: const Icon(Icons.bug_report_outlined),
          title: const Text('Export Diagnostic Report'),
          subtitle: const Text('Copy JSON diagnostics log to clipboard'),
          trailing: const Icon(Icons.copy),
          onTap: () {
            final report = DiagnosticService.instance.exportDiagnosticReport();
            Clipboard.setData(ClipboardData(text: report));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('📋 Diagnostic report copied to clipboard.')),
            );
          },
        ),

        const Divider(height: 24),

        // ── About ────────────────────────────────────────────
        _SectionHeader(title: 'About', icon: Icons.info_outline),
        FutureBuilder<int>(
          future: _db.productDao.countActive(),
          builder: (_, snap) {
            final count = snap.data ?? 0;
            return ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text('$count ${AppLocale.tr('active_products')}'),
              subtitle: const Text('Deleted products are soft-deleted, never dropped'),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.shield_outlined),
          title: const Text('StockSafe Enterprise v0.3.0'),
          subtitle: Text(
            'Offline stock manager for small shops.\n'
            '${AppLocale.tr("offline_tag")}',
          ),
        ),
      ],
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

  Future<void> _runLedgerIntegrityAudit(BuildContext context) async {
    unawaited(
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      ),
    );

    final mismatches = await DiagnosticService.instance.auditLedgerIntegrity(_db);
    if (!context.mounted) return;
    Navigator.pop(context); // close loader

    if (mismatches.isEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.verified, color: Colors.green),
              SizedBox(width: 8),
              Text('Ledger 100% Intact'),
            ],
          ),
          content: const Text(
            'All products perfectly match their underlying movement ledger history (SUM(qty_delta)). Zero discrepancies detected.',
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
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Discrepancies Found'),
            ],
          ),
          content: Text(
            'Found ${mismatches.length} cache mismatches. Tap "Rebuild Cache" to fix them immediately from the immutable ledger.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _db.rebuildAllStockCaches();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Cache rebuilt from ledger.')),
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
          ok ? '✅ PRAGMA integrity_check: OK (Database healthy)' : '⚠️ PRAGMA integrity_check failed',
        ),
        backgroundColor: ok ? Colors.teal.shade700 : Colors.red,
      ),
    );
  }

  Future<void> _rebuildCache(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rebuild stock cache?'),
        content: const Text(
          'This recalculates every product\'s stock quantity from the '
          'movement ledger. It\'s safe and fast — the ledger is the source '
          'of truth.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rebuild'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _db.rebuildAllStockCaches();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock cache rebuilt from ledger.')),
      );
    }
  }

  Future<void> _editStoreName(BuildContext context) async {
    final current = await _db.settingDao.get('shop_name') ?? 'STOCKSAFE KIRANA';
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
      await _db.settingDao.set('shop_name', updated);
      if (mounted) setState(() {});
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
