import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../data/backup_service.dart';
import '../data/database.dart';

/// Backup and export screen — **this is the product**.
///
/// Three sections:
/// 1. Manual snapshot (create now / view list / restore)
/// 2. CSV export (products + movements, every column)
/// 3. Last backup status in plain words
class BackupPage extends StatefulWidget {
  const BackupPage({super.key, required this.db});

  final AppDatabase db;

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  late final BackupService _backup = BackupService(widget.db);
  List<SnapshotInfo> _snapshots = [];
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _loadSnapshots();
  }

  Future<void> _loadSnapshots() async {
    setState(() => _loading = true);
    final snaps = await _backup.listSnapshots();
    if (mounted) {
      setState(() {
        _snapshots = snaps;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat.yMMMd().add_jm();

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Export')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Create backup ──────────────────────────────────────
          _SectionHeader(title: 'Local Backup', icon: Icons.backup_outlined),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Create a snapshot of your database. The last 7 are kept automatically.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: _working ? null : _createSnapshot,
              icon: const Icon(Icons.save),
              label: Text(_working ? 'Working…' : 'Create snapshot now'),
            ),
          ),
          const SizedBox(height: 16),

          // ── Snapshot list ──────────────────────────────────────
          if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ))
          else if (_snapshots.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'No snapshots yet. Tap above to create your first.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...[ 
              for (final snap in _snapshots)
                ListTile(
                  leading: const Icon(Icons.storage_outlined),
                  title: Text(snap.fileName),
                  subtitle: Text(
                    '${dateFmt.format(snap.modified)}  ·  ${_formatSize(snap.sizeBytes)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.restore),
                    tooltip: 'Restore this snapshot',
                    onPressed: () => _confirmRestore(snap),
                  ),
                ),
            ],

          const Divider(height: 32),

          // ── CSV export ─────────────────────────────────────────
          _SectionHeader(title: 'CSV Export', icon: Icons.table_chart_outlined),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Export products and movement history as CSV files with every column.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: _working ? null : _exportCsv,
              icon: const Icon(Icons.share),
              label: const Text('Export & share CSV'),
            ),
          ),
          const SizedBox(height: 24),

          // ── Last backup info ───────────────────────────────────
          if (_snapshots.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card.outlined(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Last backup: ${_relativeTime(_snapshots.first.modified)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── Actions ────────────────────────────────────────────────────

  Future<void> _createSnapshot() async {
    setState(() => _working = true);
    try {
      final path = await _backup.createSnapshot();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(path != null
                ? 'Snapshot saved'
                : 'Could not locate database file'),
          ),
        );
        await _loadSnapshots();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _confirmRestore(SnapshotInfo snap) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore snapshot?'),
        content: Text(
          'This will replace your current data with the backup from '
          '${DateFormat.yMMMd().add_jm().format(snap.modified)}.\n\n'
          'The app will restart to apply changes.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _working = true);
    try {
      await _backup.restoreFromSnapshot(snap.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restored. Please restart the app.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _working = true);
    try {
      final files = await _backup.exportCsvFiles();
      final xFiles = files.map((f) => XFile(f.path)).toList();
      await Share.shareXFiles(
        xFiles,
        subject: 'StockSafe Export',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'yesterday';
    return '${diff.inDays} days ago';
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
