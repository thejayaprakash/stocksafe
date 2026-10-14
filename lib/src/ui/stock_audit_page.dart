import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';

import '../data/backup_service.dart';
import '../data/database.dart';
import 'print_identity.dart';
import '../services/diagnostic_service.dart';
import '../services/esc_pos_service.dart';
import 'widgets/app_tiles.dart';
import 'widgets/thermal_slip_preview_sheet.dart';
import '../app_scope.dart';

/// Enterprise Physical Stocktake & Audit Module.
///
/// Features:
/// 1. Persistent Sessions: Resilient against app restart, crash, or phone reboots.
/// 2. Transparent vs. Blind Audit Modes: Prevent staff confirmation bias during counts.
/// 3. Variance & Discrepancy Tracking: Real-time calculation of surplus, shortage, and shrinkage value.
/// 4. Atomic Reconciliation: Generates verified adjustment entries in the movement ledger.
/// 5. CSV Audit Report Sharing: Full auditable summary exported via Android Share sheet.
class StockAuditPage extends StatefulWidget {
  const StockAuditPage({super.key});

  @override
  State<StockAuditPage> createState() => _StockAuditPageState();
}

class _StockAuditPageState extends State<StockAuditPage> with SingleTickerProviderStateMixin {
  /// The live database, read through the scope rather than passed in.
  /// Uses [AppScope.read] so it is safe to call from initState; widgets that
  /// must rebuild when the connection is replaced should call AppScope.of in
  /// build instead.
  AppDatabase get _db => AppScope.read(context).db;

  late final TabController _tabController = TabController(length: 2, vsync: this);
  StockAuditSession? _activeSession;

  @override
  void initState() {
    super.initState();
    _checkActiveSession();
  }

  Future<void> _checkActiveSession() async {
    final active = await _db.auditDao.watchActiveSessions().first;

    if (mounted && active.isNotEmpty) {
      setState(() => _activeSession = active.first);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_activeSession != null) {
      return _ActiveAuditSessionView(
        db: _db,
        session: _activeSession!,
        onClose: () {
          setState(() => _activeSession = null);
          _checkActiveSession();
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Stocktake & Audits',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 21),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Active Audits'),
            Tab(text: 'Completed History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ActiveSessionsList(
            db: _db,
            onSelectSession: (s) => setState(() => _activeSession = s),
            onCreateNew: _showCreateSessionDialog,
          ),
          _CompletedSessionsList(
            db: _db,
          ),
        ],
      ),
      // Only once a session exists. While the list is empty the screen's own
      // centred button is the call to action, and a FAB beside it is the
      // same offer made twice.
      floatingActionButton: StreamBuilder<List<StockAuditSession>>(
        stream: _db.auditDao.watchActiveSessions(),
        builder: (context, snapshot) {
          final sessions = snapshot.data ?? const <StockAuditSession>[];
          if (sessions.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('New Audit Session'),
            onPressed: _showCreateSessionDialog,
          );
        },
      ),
    );
  }

  void _showCreateSessionDialog() {
    final nameController = TextEditingController(
      text: 'Shelf Audit - ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
    );
    String mode = 'transparent';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.inventory_outlined, color: Colors.green),
              SizedBox(width: 8),
              Text('Start Stocktake Session'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Session Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  mode == 'transparent' ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: mode == 'transparent' ? Theme.of(context).colorScheme.primary : null,
                ),
                title: const Text('Transparent Count'),
                subtitle: const Text('Shows system expected stock on screen during count.'),
                onTap: () => setDialogState(() => mode = 'transparent'),
              ),
              ListTile(
                leading: Icon(
                  mode == 'blind' ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: mode == 'blind' ? Theme.of(context).colorScheme.primary : null,
                ),
                title: const Text('Blind Count (Anti-Bias)'),
                subtitle: const Text('Hides system stock from staff to force exact physical count.'),
                onTap: () => setDialogState(() => mode = 'blind'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);

                final id = await _db.auditDao.createSession(
                  name: name,
                  auditMode: mode,
                );
                final session = await _db.auditDao.getSession(id);
                if (mounted && session != null) {
                  setState(() => _activeSession = session);
                }
              },
              child: const Text('Start Audit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveSessionsList extends StatelessWidget {
  const _ActiveSessionsList({
    required this.db,
    required this.onSelectSession,
    required this.onCreateNew,
  });

  final AppDatabase db;
  final ValueChanged<StockAuditSession> onSelectSession;
  final VoidCallback onCreateNew;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StockAuditSession>>(
      stream: db.auditDao.watchActiveSessions(),
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? [];
        if (sessions.isEmpty) {
          return EmptyState(
            icon: Icons.fact_check_outlined,
            title: 'No in-progress stocktake sessions',
            message: 'Tap "New Audit Session" to begin counting shelf stock.',
            actionLabel: 'New Audit Session',
            onAction: onCreateNew,
          );
        }

        final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: sessions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final s = sessions[index];
            return Card.outlined(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withValues(alpha: 0.15),
                  child: const Icon(Icons.fact_check_outlined, color: Colors.blue),
                ),
                title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Started: ${dateFmt.format(s.startedAt)}\nMode: ${s.auditMode.toUpperCase()} • Items: ${s.totalItemsCounted}'),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onSelectSession(s),
              ),
            );
          },
        );
      },
    );
  }
}

class _CompletedSessionsList extends StatelessWidget {
  const _CompletedSessionsList({required this.db});

  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StockAuditSession>>(
      stream: db.auditDao.watchAllSessions(),
      builder: (context, snapshot) {
        final all = snapshot.data ?? [];
        final completed = all.where((s) => s.status == 'completed').toList();

        if (completed.isEmpty) {
          return const Center(
            child: Text('No completed audit history yet.', style: TextStyle(color: Colors.grey)),
          );
        }

        final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: completed.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final s = completed[index];
            return Card.outlined(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.withValues(alpha: 0.15),
                  child: const Icon(Icons.done_all, color: Colors.green),
                ),
                title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  'Completed: ${s.completedAt != null ? dateFmt.format(s.completedAt!) : 'N/A'}\n'
                  'Counted: ${s.totalItemsCounted} • Discrepancies: ${s.totalDiscrepancies}',
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.print_outlined),
                      tooltip: 'Print Discrepancy Slip (ESC/POS)',
                      onPressed: () => _printAuditDiscrepancySlip(context, db, s),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_outlined),
                      tooltip: 'Share Audit CSV Report',
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final csv = await BackupService(db).exportAuditSessionCsv(s.id);
                          await SharePlus.instance.share(
                            ShareParams(
                              text: csv,
                              subject: 'Stocktake Audit Report - ${s.name}',
                            ),
                          );
                        } catch (e) {
                          DiagnosticService.instance
                              .log('Audit CSV export failed: $e', level: 'ERROR');
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not share the audit report. '
                                'Please try again.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

Future<void> _printAuditDiscrepancySlip(
  BuildContext context,
  AppDatabase db,
  StockAuditSession session,
) async {
  final items = await db.auditDao.getSessionItems(session.id);
  final itemsWithProd = <StockAuditItemWithProduct>[];
  for (final it in items) {
    final prod = await db.productDao.getById(it.productId);
    itemsWithProd.add(StockAuditItemWithProduct(item: it, product: prod));
  }

  if (!context.mounted) return;
  final identity = await resolvePrintIdentity(context, db);
  if (identity == null) return; // no shop name given, nothing to print


  final b58 = EscPosService.buildAuditDiscrepancySlipBytes(
    session: session,
    items: itemsWithProd,
    shopName: identity.shopName,
    proUnlocked: identity.proUnlocked,
    paperWidth: ThermalPaperWidth.mm58,
  );
  final b80 = EscPosService.buildAuditDiscrepancySlipBytes(
    session: session,
    items: itemsWithProd,
    shopName: identity.shopName,
    proUnlocked: identity.proUnlocked,
    paperWidth: ThermalPaperWidth.mm80,
  );
  final t58 = EscPosService.buildAuditDiscrepancyText(
    session: session,
    items: itemsWithProd,
    shopName: identity.shopName,
    proUnlocked: identity.proUnlocked,
    paperWidth: ThermalPaperWidth.mm58,
  );
  final t80 = EscPosService.buildAuditDiscrepancyText(
    session: session,
    items: itemsWithProd,
    shopName: identity.shopName,
    proUnlocked: identity.proUnlocked,
    paperWidth: ThermalPaperWidth.mm80,
  );

  if (context.mounted) {
    await ThermalSlipPreviewSheet.show(
      context,
      title: 'Physical Audit Discrepancy Slip',
      slipBytes58: b58,
      slipBytes80: b80,
      slipText58: t58,
      slipText80: t80,
      fileNamePrefix: 'audit_discrepancy',
    );
  }
}

/// The Active Counting and Reconciliation Workspace.
class _ActiveAuditSessionView extends StatefulWidget {
  const _ActiveAuditSessionView({
    required this.db,
    required this.session,
    required this.onClose,
  });

  final AppDatabase db;
  final StockAuditSession session;
  final VoidCallback onClose;

  @override
  State<_ActiveAuditSessionView> createState() => _ActiveAuditSessionViewState();
}

class _ActiveAuditSessionViewState extends State<_ActiveAuditSessionView> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );
  bool _cameraActive = true;
  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBlind = widget.session.auditMode == 'blind';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onClose,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.session.name, style: const TextStyle(fontSize: 16)),
            Text(
              'Mode: ${widget.session.auditMode.toUpperCase()} (Saved in SQLite)',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.green),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_cameraActive ? Icons.videocam : Icons.videocam_off),
            tooltip: _cameraActive ? 'Pause Camera' : 'Resume Camera',
            onPressed: () {
              setState(() => _cameraActive = !_cameraActive);
              if (_cameraActive) {
                _scannerController.start();
              } else {
                _scannerController.stop();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print Discrepancy Slip (ESC/POS)',
            onPressed: () => _printAuditDiscrepancySlip(context, widget.db, widget.session),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard),
            tooltip: 'Enter SKU / Code',
            onPressed: _showManualAuditDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Camera Scanner Viewfinder ──────────────────────────
          if (_cameraActive)
            SizedBox(
              height: 200,
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: (capture) {
                      if (_isProcessing) return;
                      final barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                        final code = barcodes.first.rawValue!.trim();
                        if (code.isNotEmpty) {
                          _handleScannedBarcode(code);
                        }
                      }
                    },
                    errorBuilder: (ctx, error) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.camera_alt_outlined, color: Colors.grey, size: 36),
                          const SizedBox(height: 6),
                          Text('Camera unavailable', style: theme.textTheme.bodySmall),
                          TextButton(
                            onPressed: _showManualAuditDialog,
                            child: const Text('Enter Code Manually'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 240,
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green, width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Real-Time Session Items & Discrepancies ─────────────
          Expanded(
            child: StreamBuilder<List<StockAuditItem>>(
              stream: widget.db.auditDao.watchSessionItems(widget.session.id),
              builder: (context, snapshot) {
                final items = snapshot.data ?? [];

                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.qr_code_scanner, size: 54, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          const Text('No items scanned in this session yet', style: TextStyle(fontSize: 16)),
                          const SizedBox(height: 6),
                          const Text('Scan shelf barcodes to verify counts.', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            icon: const Icon(Icons.search),
                            label: const Text('Lookup by Name / Barcode'),
                            onPressed: _showManualAuditDialog,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                int matched = 0;
                int discrepancies = 0;
                for (final it in items) {
                  if (it.difference == 0) {
                    matched++;
                  } else {
                    discrepancies++;
                  }
                }

                return Column(
                  children: [
                    // Stats Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statTile('Counted', '${items.length}', Colors.blue),
                          _statTile('Matched', '$matched', Colors.green),
                          _statTile('Discrepancies', '$discrepancies', discrepancies > 0 ? Colors.red : Colors.grey),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final isExact = item.difference == 0;

                          return FutureBuilder<Product?>(
                            future: widget.db.productDao.getById(item.productId),
                            builder: (context, prodSnap) {
                              final prod = prodSnap.data;
                              final name = prod?.name ?? 'Item #${item.productId}';
                              final unit = prod?.unit ?? 'pcs';

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isExact ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                                  child: Icon(
                                    isExact ? Icons.check : Icons.warning_amber_rounded,
                                    color: isExact ? Colors.green : Colors.orange,
                                  ),
                                ),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  isBlind
                                      ? 'Physical Count: ${item.countedQty} $unit'
                                      : 'System: ${item.expectedQty} • Counted: ${item.countedQty} $unit',
                                ),
                                trailing: isBlind
                                    ? Chip(label: Text('${item.countedQty} $unit'))
                                    : Text(
                                        isExact ? 'MATCHED' : (item.difference > 0 ? '+${item.difference}' : '${item.difference}'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: isExact ? Colors.green : (item.difference > 0 ? Colors.blue : Colors.red),
                                        ),
                                      ),
                                onTap: () => prod != null ? _promptCountForItem(prod, existingItem: item) : null,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // ── Bottom Reconciliation Action Bar ───────────────────
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('Exit & Save Draft'),
                      onPressed: widget.onClose,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.green[800]),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Reconcile & Close'),
                      onPressed: _confirmReconcileSession,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Future<void> _handleScannedBarcode(String code) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    await HapticFeedback.selectionClick();

    Product? product = await widget.db.productDao.getByBarcode(code);
    if (product == null) {
      final matches = await widget.db.productDao.watchAll(query: code, limit: 1).first;
      if (matches.isNotEmpty) {
        product = matches.first;
      }
    }

    if (!mounted) {
      _isProcessing = false;
      return;
    }

    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No product found for barcode "$code"')),
      );
      _isProcessing = false;
      return;
    }

    await _promptCountForItem(product);
    _isProcessing = false;
  }

  Future<void> _promptCountForItem(Product product, {StockAuditItem? existingItem}) async {
    final initialCount = existingItem?.countedQty ?? product.stockQty;
    final countController = TextEditingController(text: '$initialCount');
    final isBlind = widget.session.auditMode == 'blind';

    final enteredCount = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Audit: ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isBlind)
              Text('System Ledger Stock: ${product.stockQty} ${product.unit}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: countController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Physical Shelf Count (${product.unit})',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.inventory_2_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(countController.text.trim());
              Navigator.pop(ctx, val);
            },
            child: const Text('Save Count'),
          ),
        ],
      ),
    );

    if (enteredCount == null || !mounted) return;

    // Persist immediately to SQLite
    await widget.db.auditDao.recordCount(
      sessionId: widget.session.id,
      productId: product.id,
      countedQty: enteredCount,
      expectedQty: product.stockQty,
    );

    await HapticFeedback.mediumImpact();
  }

  Future<void> _confirmReconcileSession() async {
    final items = await widget.db.auditDao.getSessionItems(widget.session.id);
    if (!mounted) return;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot reconcile an empty session. Please count at least one item.')),
      );
      return;
    }

    final discrepancies = items.where((i) => i.difference != 0).length;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reconcile & Close Session?'),
        content: Text(
          'Total items audited: ${items.length}\n'
          'Items with discrepancies: $discrepancies\n\n'
          'Reconciling will write atomic adjustment movements into the immutable ledger and update current stock levels. This action is auditable and permanent.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.green[800]),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Reconciliation'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await widget.db.auditDao.reconcileSession(widget.session.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Audit reconciled successfully into immutable movement ledger!')),
      );
      widget.onClose();
    }
  }

  void _showManualAuditDialog() {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Audit by Name, Code or SKU'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter name or barcode',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (val) {
            Navigator.pop(ctx);
            if (val.trim().isNotEmpty) {
              _handleScannedBarcode(val.trim());
            }
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              final val = textController.text.trim();
              if (val.isNotEmpty) _handleScannedBarcode(val);
            },
            child: const Text('Lookup'),
          ),
        ],
      ),
    );
  }
}
