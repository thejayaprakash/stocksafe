import 'package:flutter/material.dart';

import '../data/database.dart';
import '../services/app_localization.dart';
import 'backup_page.dart';
import 'barcode_label_print_page.dart';
import 'suppliers_page.dart';

/// App settings: language selection, operations, cache rebuild, backup, about.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.db});

  final AppDatabase db;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    AppLocale.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    AppLocale.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = AppLocale.instance.current;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // ── Language / Localization ──────────────────────────
        _SectionHeader(title: 'Language / மொழி', icon: Icons.translate),
        ListTile(
          leading: const Icon(Icons.language),
          title: const Text('App Language (மொழி)'),
          subtitle: Text(currentLang.label),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showLanguageSelector(context),
        ),

        const Divider(height: 32),

        // ── Operations & Hardware ─────────────────────────────
        _SectionHeader(title: 'Operations & Printing', icon: Icons.precision_manufacturing_outlined),
        ListTile(
          leading: const Icon(Icons.contact_phone_outlined),
          title: Text(AppLocale.tr('suppliers')),
          subtitle: const Text('Vendor contact directory with tap-to-call for restocks'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SuppliersPage(db: widget.db)),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.qr_code_2),
          title: Text(AppLocale.tr('barcode_label_printing')),
          subtitle: const Text('Generate PDF sticker sheets (Code 128 / QR) for loose goods'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BarcodeLabelPrintPage(db: widget.db)),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.storefront_outlined),
          title: const Text('Store Name (Receipts & Labels)'),
          subtitle: FutureBuilder<String?>(
            future: widget.db.settingDao.get('shop_name'),
            builder: (_, s) => Text(s.data ?? 'STOCKSAFE KIRANA'),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _editStoreName(context),
        ),

        const Divider(height: 32),

        // ── Data ─────────────────────────────────────────────
        _SectionHeader(title: 'Data & Sovereignty', icon: Icons.storage_outlined),
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: Text(AppLocale.tr('backup_export')),
          subtitle: const Text('Verified snapshots, CSV export & import'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BackupPage(db: widget.db)),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.refresh),
          title: Text(AppLocale.tr('rebuild_cache')),
          subtitle: const Text(
            'Recalculates all stock quantities from the movement ledger. '
            'Use if numbers look wrong.',
          ),
          onTap: () => _rebuildCache(context),
        ),

        const Divider(height: 32),

        // ── About ────────────────────────────────────────────
        _SectionHeader(title: 'About', icon: Icons.info_outline),
        FutureBuilder<int>(
          future: widget.db.productDao.countActive(),
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
          title: const Text('StockSafe Enterprise v0.2.0'),
          subtitle: Text(
            'Offline stock manager for small shops.\n'
            '${AppLocale.tr("offline_tag")}',
          ),
        ),
      ],
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

    await widget.db.rebuildAllStockCaches();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock cache rebuilt from ledger.')),
      );
    }
  }

  Future<void> _editStoreName(BuildContext context) async {
    final current = await widget.db.settingDao.get('shop_name') ?? 'STOCKSAFE KIRANA';
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
      await widget.db.settingDao.set('shop_name', updated);
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
