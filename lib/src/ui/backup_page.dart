import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../data/backup_service.dart';
import '../data/database.dart';
import '../services/csv_import_service.dart';
import '../app_scope.dart';

/// Enterprise Backup & Data Sovereignty Screen.
///
/// Features:
/// 1. Local rolling snapshots with SHA-256 cryptographic verification.
/// 2. Safe restoration with automatic pre-restore safety archiving.
/// 3. CSV catalog import with flexible header mapping and error validation.
/// 4. CSV catalog and movement history export.
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  /// The live database, read through the scope rather than passed in.
  /// Uses [AppScope.read] so it is safe to call from initState; widgets that
  /// must rebuild when the connection is replaced should call AppScope.of in
  /// build instead.
  AppDatabase get _db => AppScope.read(context).db;

  /// Resolved per use rather than captured: a restore replaces the database
  /// instance, and a repository holding the old one would write to a closed
  /// connection.
  BackupRepository get _backup => AppScope.read(context).backup;
  CsvImportService get _csvImporter => CsvImportService(_db);

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
      appBar: AppBar(title: const Text('Backup & Data Sovereignty')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Local Backup ──────────────────────────────────────
          _SectionHeader(title: 'Local Database Snapshots', icon: Icons.backup_outlined),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Snapshots are cryptographically verified with SHA-256. '
              'The last 7 rolling copies are retained automatically.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: _working ? null : _createSnapshot,
              icon: const Icon(Icons.shield_outlined),
              label: Text(_working ? 'Processing…' : 'Create Verified Snapshot Now'),
            ),
          ),
          const SizedBox(height: 16),

          // ── Snapshot list ──────────────────────────────────────
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_snapshots.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'No snapshots yet. Tap above to create your first verified snapshot.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...[
              for (final snap in _snapshots)
                ListTile(
                  leading: Icon(
                    snap.isIntegrityVerified ? Icons.verified : Icons.warning_amber_rounded,
                    color: snap.isIntegrityVerified ? Colors.green : Colors.red,
                  ),
                  title: Text(snap.fileName),
                  subtitle: Text(
                    '${dateFmt.format(snap.modified)}  ·  ${_formatSize(snap.sizeBytes)}'
                    '${snap.isIntegrityVerified ? '  ·  SHA-256 OK' : '  ·  Unverified'}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.restore),
                    tooltip: 'Restore this snapshot',
                    onPressed: () => _confirmRestore(snap),
                  ),
                ),
            ],

          const Divider(height: 32),

          // ── CSV Import & Export ────────────────────────────────
          _SectionHeader(title: 'CSV Data Management', icon: Icons.table_chart_outlined),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Import product catalogs from supplier spreadsheets or export your full '
              'catalog and stock movements to CSV.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _working ? null : _showCsvImportDialog,
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Import CSV'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _working ? null : _exportCsv,
                    icon: const Icon(Icons.share),
                    label: const Text('Export CSV'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Last backup info card ─────────────────────────────
          if (_snapshots.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card.outlined(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Only claim "verified" when it actually verified.
                      Icon(
                        _snapshots.first.isIntegrityVerified
                            ? Icons.check_circle
                            : Icons.warning_amber_rounded,
                        color: _snapshots.first.isIntegrityVerified
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _snapshots.first.isIntegrityVerified
                              ? 'Latest verified backup: '
                                  '${_relativeTime(_snapshots.first.modified)}'
                              : 'Latest backup: '
                                  '${_relativeTime(_snapshots.first.modified)} '
                                  '— not verified, no checksum recorded',
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
                ? '✅ Verified snapshot created with SHA-256 checksum'
                : 'Could not locate active database file'),
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
    if (!snap.isIntegrityVerified) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Integrity Warning'),
            ],
          ),
          content: const Text(
            'This snapshot failed cryptographic checksum or magic-byte verification. '
            'Restoring a damaged file may corrupt the database. Are you sure you wish to proceed?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Force Restore'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore snapshot?'),
        content: Text(
          'This will replace your current data with the verified snapshot from '
          '${DateFormat.yMMMd().add_jm().format(snap.modified)}.\n\n'
          'A pre-restore safety copy (safety_pre_restore.db) will be created automatically.',
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
      // `force` only when the user has already acknowledged the integrity
      // warning above. The connection is closed, swapped and reopened inside
      // the repository, so there is nothing for the user to restart.
      await _backup.restoreFromSnapshot(
        snap.path,
        force: !snap.isIntegrityVerified,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Restored. Your data is back.')),
        );
        await _loadSnapshots();
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
        subject: 'StockSafe Full CSV Export',
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

  void _showCsvImportDialog() {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.upload_file, color: Colors.blue),
            SizedBox(width: 8),
            Text('Import Catalog CSV'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste CSV text from your supplier or spreadsheet. Headers supported: '
                'Name, Category, SKU, Barcode, Unit, Buy Price, Sell Price, Low Stock, Initial Stock.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: 'Name,Category,Barcode,Buy Price,Sell Price,Initial Stock\n'
                      'Milk 500ml,Dairy,8901234567890,25,30,50\n'
                      'Biscuits,Snacks,8909876543210,10,12,100',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(10),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final text = textController.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              await _executeCsvImport(text);
            },
            child: const Text('Start Import'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeCsvImport(String csvContent) async {
    setState(() => _working = true);
    try {
      final result = await _csvImporter.importFromCsvString(csvContent);
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(result.hasErrors ? 'Import Completed with Notes' : 'Import Successful!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total rows processed: ${result.totalRows}'),
              Text('✅ Successfully imported: ${result.importedCount} products'),
              if (result.skippedCount > 0)
                Text('⚠️ Skipped rows: ${result.skippedCount}'),
              if (result.errors.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Errors / Warnings:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    itemCount: result.errors.length,
                    itemBuilder: (_, i) => Text(
                      '• ${result.errors[i]}',
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
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
