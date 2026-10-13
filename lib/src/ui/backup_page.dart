import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../data/backup_service.dart';
import '../data/database.dart';
import '../services/csv_import_service.dart';
import '../services/diagnostic_service.dart';
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
                  // Three states, not two: not yet checked, checked and sound,
                  // checked and damaged. Hashing every snapshot on open read
                  // hundreds of megabytes on the UI isolate, so it is deferred
                  // to restore time — but "not checked" must not be dressed up
                  // as either answer.
                  leading: Icon(
                    switch (snap.isIntegrityVerified) {
                      true => Icons.verified,
                      false => Icons.error_outline,
                      null => Icons.inventory_2_outlined,
                    },
                    color: switch (snap.isIntegrityVerified) {
                      true => Colors.green,
                      false => Colors.red,
                      null => Theme.of(context).colorScheme.onSurfaceVariant,
                    },
                  ),
                  title: Text(snap.fileName),
                  subtitle: Text(
                    '${dateFmt.format(snap.modified)}  ·  ${_formatSize(snap.sizeBytes)}'
                    '${switch (snap.isIntegrityVerified) {
                      true => '  ·  SHA-256 OK',
                      false => '  ·  Damaged',
                      null => '',
                    }}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.restore),
                    tooltip: 'Restore this snapshot',
                    onPressed: () => _confirmRestore(snap),
                  ),
                ),
            ],

          const Divider(height: 32),

          const Divider(height: 32),

          // ── Portable backup file ───────────────────────────────
          _SectionHeader(
            title: 'Backup File (survives losing this phone)',
            icon: Icons.save_alt_outlined,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Snapshots above live on this phone. If it is lost, broken or reset, '
              'they go with it. Export a backup file and keep it somewhere else — '
              'your Drive, an SD card, a computer. It is an ordinary zip you own '
              'and can open without StockSafe.\n\n'
              'The file is not password protected, so store it somewhere only you '
              'can reach.',
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
                    onPressed: _working ? null : _importArchive,
                    icon: const Icon(Icons.folder_open_outlined),
                    label: const Text('Import backup'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _working ? null : _exportArchive,
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Export backup'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<bool>(
            future: _backup.isAutoSnapshotEnabled(),
            builder: (context, snap) {
              final enabled = snap.data ?? true;
              return SwitchListTile(
                value: enabled,
                title: const Text('Automatic daily snapshot'),
                subtitle: const Text(
                  'Takes a snapshot when you open the app, if a day has passed.',
                ),
                onChanged: _working
                    ? null
                    : (value) async {
                        await _backup.setAutoSnapshotEnabled(value);
                        if (mounted) setState(() {});
                      },
              );
            },
          ),

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
                      // Never claim "verified" for something not checked.
                      Icon(
                        _snapshots.first.isIntegrityVerified == false
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle,
                        color: _snapshots.first.isIntegrityVerified == false
                            ? Colors.orange
                            : Colors.green,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _snapshots.first.isIntegrityVerified == false
                              ? 'Latest backup: '
                                  '${_relativeTime(_snapshots.first.modified)} '
                                  '— damaged, do not rely on it'
                              : 'Latest backup: '
                                  '${_relativeTime(_snapshots.first.modified)}',
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
        _showError('Could not create the snapshot', e);
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _confirmRestore(SnapshotInfo snap) async {
    // Verify here rather than when the list is built. Hashing every snapshot
    // on open read hundreds of megabytes on the UI isolate; this is the one
    // moment the answer actually changes what happens.
    setState(() => _working = true);
    final verified = await _backup.verifySnapshotIntegrity(snap.path);
    if (!mounted) return;
    setState(() => _working = false);

    if (!verified) {
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
      await _backup.restoreFromSnapshot(snap.path, force: !verified);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Restored. Your data is back.')),
        );
        await _loadSnapshots();
      }
    } catch (e) {
      if (mounted) {
        _showError('Restore failed', e);
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Builds the zip and hands it to the system share sheet, so the user picks
  /// where it goes — their Drive, WhatsApp, a file manager. The point is that
  /// the file leaves this phone; which app receives it is their call.
  Future<void> _exportArchive() async {
    // Shown before the file exists, not after it has been shared. The archive
    // is deliberately not password-protected — a forgotten password would lock
    // the user out of their own backup — so the honest trade is that they must
    // choose where it goes. Saying so afterwards would be too late.
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.lock_open_outlined),
        title: const Text('This backup is not password protected'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anyone who opens the file can read your stock list, your buying '
              'and selling prices, your margins, and your suppliers\' contact '
              'details.',
            ),
            SizedBox(height: 12),
            Text(
              'There is no password because a forgotten one would lock you out '
              'of your own backup for good.',
            ),
            SizedBox(height: 12),
            Text(
              'Send it somewhere only you can reach — your own cloud drive, '
              'your computer, a USB stick. Not a group chat or a shared folder.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('I understand, export'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    setState(() => _working = true);
    try {
      final file = await _backup.exportArchive();
      final sizeMb = (await file.length()) / (1024 * 1024);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'StockSafe backup',
        text: 'StockSafe backup — keep this somewhere other than your phone.',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Backup file created (${sizeMb.toStringAsFixed(1)} MB). '
              'Save it somewhere off this phone.',
            ),
          ),
        );
        await _loadSnapshots();
      }
    } catch (e) {
      _showError('Could not create the backup file', e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _importArchive() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null || !mounted) return;

    setState(() => _working = true);
    try {
      // Tell the user what they are about to replace, before replacing it.
      final inspection = await _backup.inspectArchive(File(path));
      if (!mounted) return;

      if (!inspection.isValid) {
        _showError('That file cannot be used', inspection.error);
        return;
      }

      final currentProducts = await _db.productDao.countActive();
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Replace your data with this backup?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This backup holds:\n${inspection.describe()}'),
              const SizedBox(height: 12),
              Text(
                'Your current data ($currentProducts products) will be replaced. '
                'A copy of it is saved first, so this can be undone.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      await _backup.importArchive(File(path));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Backup imported. Your data is restored.')),
        );
        await _loadSnapshots();
      }
    } catch (e) {
      _showError('Import failed', e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Error messages a shopkeeper can act on, with the detail kept for the log
  /// rather than interpolated raw into the UI.
  void _showError(String what, Object? detail) {
    if (!mounted) return;
    final message = switch (detail) {
      FormatException(:final message) => message,
      StateError(:final message) => message,
      final String s => s,
      _ => 'Please try again.',
    };
    DiagnosticService.instance.log('$what: $detail', level: 'ERROR');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what. $message')),
    );
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
        _showError('Could not export the CSV files', e);
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
        _showError('Import failed', e);
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
