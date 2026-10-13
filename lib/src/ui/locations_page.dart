import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/database.dart';

/// Manage the places stock is held: the shop, the godown, a second branch.
///
/// Deliberately plain. A shopkeeper with one shop should be able to open
/// this, see one row, understand what it is for, and leave.
class LocationsPage extends StatefulWidget {
  const LocationsPage({super.key});

  @override
  State<LocationsPage> createState() => _LocationsPageState();
}

class _LocationsPageState extends State<LocationsPage> {
  AppDatabase get _db => AppScope.read(context).db;

  @override
  void initState() {
    super.initState();
    // A database that predates locations, or one restored from an old backup,
    // may have none. Make sure there is always somewhere to put stock.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _db.locationDao.getOrCreateDefault();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Locations')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addLocation,
        icon: const Icon(Icons.add),
        label: const Text('Add location'),
      ),
      body: StreamBuilder<List<LocationStock>>(
        stream: _db.locationDao.watchTotals(),
        builder: (context, snapshot) {
          final rows = snapshot.data ?? const <LocationStock>[];
          if (rows.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  rows.length == 1
                      ? 'All your stock is held here. Add a godown or a second '
                          'shop to track them separately.'
                      : 'Stock is counted separately at each place. Your '
                          'product totals are the sum across all of them.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final row in rows)
                ListTile(
                  leading: Icon(
                    row.isDefault ? Icons.store : Icons.warehouse_outlined,
                    color: row.isDefault ? theme.colorScheme.primary : null,
                  ),
                  title: Row(
                    children: [
                      Flexible(child: Text(row.locationName)),
                      if (row.isDefault) ...[
                        const SizedBox(width: 8),
                        Chip(
                          label: const Text('Default'),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          labelStyle: theme.textTheme.labelSmall,
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text('${row.quantity} units held'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) => _handleAction(action, row),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'rename', child: Text('Rename')),
                      if (!row.isDefault)
                        const PopupMenuItem(
                          value: 'default',
                          child: Text('Make default'),
                        ),
                      if (rows.length > 1)
                        const PopupMenuItem(value: 'delete', child: Text('Remove')),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleAction(String action, LocationStock row) async {
    switch (action) {
      case 'rename':
        await _addLocation(existing: row);
      case 'default':
        await _db.locationDao.setDefault(row.locationId);
      case 'delete':
        await _confirmDelete(row);
    }
  }

  Future<void> _addLocation({LocationStock? existing}) async {
    final controller = TextEditingController(text: existing?.locationName ?? '');

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add a location' : 'Rename location'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'e.g. Godown, Second shop',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(existing == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;
    if (existing == null) {
      await _db.locationDao.createLocation(name: name);
    } else {
      await _db.locationDao.rename(existing.locationId, name);
    }
  }

  Future<void> _confirmDelete(LocationStock row) async {
    // The DAO refuses to remove a place that still holds stock, because the
    // stock would vanish from every per-location view while still counting
    // towards product totals. Say so before the user tries.
    if (row.quantity != 0) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('This location still holds stock'),
          content: Text(
            '${row.locationName} holds ${row.quantity} units. Transfer them '
            'to another location first, so nothing is left behind.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${row.locationName}?'),
        content: const Text(
          'Its stock history is kept — past movements still show where they '
          'happened. You can add it again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _db.locationDao.softDelete(row.locationId);
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
