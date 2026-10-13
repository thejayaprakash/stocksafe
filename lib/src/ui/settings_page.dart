import 'package:flutter/material.dart';

import '../data/database.dart';
import 'backup_page.dart';

/// App settings: cache rebuild, backup, about.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.db});

  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // ── Data ─────────────────────────────────────────────
        _SectionHeader(title: 'Data', icon: Icons.storage_outlined),
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: const Text('Backup & Export'),
          subtitle: const Text('Snapshots, CSV export'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BackupPage(db: db)),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.refresh),
          title: const Text('Rebuild stock cache'),
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
          future: db.productDao.countActive(),
          builder: (_, snap) {
            final count = snap.data ?? 0;
            return ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text('$count active products'),
              subtitle: const Text('Deleted products are soft-deleted, never dropped'),
            );
          },
        ),
        const ListTile(
          leading: Icon(Icons.shield_outlined),
          title: Text('StockSafe v0.1.0'),
          subtitle: Text(
            'Offline stock manager for small shops.\n'
            'One promise: it never loses your data.',
          ),
        ),
      ],
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

    await db.rebuildAllStockCaches();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock cache rebuilt from ledger.')),
      );
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
