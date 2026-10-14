import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import 'pro_gate.dart';
import 'print_identity.dart';
import '../services/app_localization.dart';
import '../services/esc_pos_service.dart';
import 'barcode_label_print_page.dart';
import 'widgets/thermal_slip_preview_sheet.dart';
import '../app_scope.dart';

enum StockDirection { inward, outward }

/// Stock in / stock out. Writes an append-only movement row — the
/// product's stock number is only ever a derived cache.
/// Supports batch assignment, FIFO expiry tracking, supplier linkage,
/// ESC/POS delivery slip printing, and barcode sticker generation.
class StockMovementPage extends StatefulWidget {
  const StockMovementPage({
    super.key,
    required this.productId,
    this.initialDirection = StockDirection.inward,
    this.initialQty,
    this.initialBatchId,
  });
  final int productId;
  final StockDirection initialDirection;
  final int? initialQty;
  final int? initialBatchId;

  @override
  State<StockMovementPage> createState() => _StockMovementPageState();
}

class _StockMovementPageState extends State<StockMovementPage> {
  /// The live database, read through the scope rather than passed in.
  /// Uses [AppScope.read] so it is safe to call from initState; widgets that
  /// must rebuild when the connection is replaced should call AppScope.of in
  /// build instead.
  AppDatabase get _db => AppScope.read(context).db;

  late StockDirection _direction = widget.initialDirection;
  late final _qtyController = TextEditingController(
    text: widget.initialQty != null ? '${widget.initialQty}' : '',
  );
  final _noteController = TextEditingController();
  final _batchNumberController = TextEditingController();
  DateTime? _expiryDate;
  int? _selectedBatchId;
  int? _selectedSupplierId;
  int? _selectedLocationId;
  List<ProductBatch> _availableBatches = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedBatchId = widget.initialBatchId;
    _loadBatches();
    _loadDefaultSupplier();
  }

  Future<void> _loadDefaultSupplier() async {
    final prod = await _db.productDao.getById(widget.productId);
    if (mounted && prod?.supplierId != null && _selectedSupplierId == null) {
      setState(() => _selectedSupplierId = prod!.supplierId);
    }
  }

  Future<void> _loadBatches() async {
    final batches = await _db.batchDao.getBatchesForProduct(widget.productId);
    if (mounted) {
      setState(() {
        _availableBatches = batches;
        if (_selectedBatchId == null && _availableBatches.isNotEmpty && _direction == StockDirection.outward) {
          // Default to FIFO: the batch with earliest expiry that has stock > 0
          final fifoBatch = _availableBatches.where((b) => b.stockQty > 0).firstOrNull;
          if (fifoBatch != null) {
            _selectedBatchId = fifoBatch.id;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _noteController.dispose();
    _batchNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now.add(const Duration(days: 90)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(title: Text(AppLocale.tr('stock_movement') == 'stock_movement' ? 'Stock Movement' : AppLocale.tr('stock_movement'))),
      body: FutureBuilder<Product?>(
        future: _db.productDao.getById(widget.productId),
        builder: (context, snapshot) {
          final product = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (product != null) ...[
                Text(product.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  'Current Stock: ${product.stockQty} ${product.unit}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: product.stockQty <= product.lowStockLevel ? theme.colorScheme.error : null,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SegmentedButton<StockDirection>(
                segments: const [
                  ButtonSegment(
                    value: StockDirection.inward,
                    label: Text('Stock in (+)'),
                    icon: Icon(Icons.arrow_downward),
                  ),
                  ButtonSegment(
                    value: StockDirection.outward,
                    label: Text('Stock out (-)'),
                    icon: Icon(Icons.arrow_upward),
                  ),
                ],
                selected: {_direction},
                onSelectionChanged: (s) {
                  setState(() {
                    _direction = s.first;
                    if (_direction == StockDirection.outward && _selectedBatchId == null) {
                      final fifoBatch = _availableBatches.where((b) => b.stockQty > 0).firstOrNull;
                      if (fifoBatch != null) _selectedBatchId = fifoBatch.id;
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _qtyController,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Quantity *',
                  hintText: 'Enter units',
                  prefixIcon: const Icon(Icons.pin_outlined),
                  border: const OutlineInputBorder(),
                  suffixText: product?.unit,
                ),
              ),
              const SizedBox(height: 16),

              // BATCH WORKFLOW: Stock-In vs Stock-Out
              if (_direction == StockDirection.inward) ...[
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.qr_code_2, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              AppLocale.tr('batches'),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _batchNumberController,
                          decoration: InputDecoration(
                            labelText: '${AppLocale.tr('batch_number')} (optional)',
                            hintText: 'e.g. LOT-2024-B1',
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickExpiryDate,
                                icon: const Icon(Icons.calendar_today, size: 18),
                                label: Text(
                                  _expiryDate == null
                                      ? AppLocale.tr('select_expiry')
                                      : 'Exp: ${fmt.format(_expiryDate!)}',
                                ),
                              ),
                            ),
                            if (_expiryDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                tooltip: 'Clear date',
                                onPressed: () => setState(() => _expiryDate = null),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Only shown once there is more than one place to choose
                // between. A shop with a single location should never be
                // asked a question with one possible answer.
                StreamBuilder<List<Location>>(
                  stream: _db.locationDao.watchAll(),
                  builder: (context, snapshot) {
                    final locations = snapshot.data ?? const <Location>[];
                    if (locations.length < 2) return const SizedBox.shrink();

                    final selected = _selectedLocationId ??
                        locations
                            .firstWhere(
                              (l) => l.isDefault,
                              orElse: () => locations.first,
                            )
                            .id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<int>(
                        initialValue: selected,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          prefixIcon: Icon(Icons.warehouse_outlined),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          for (final l in locations)
                            DropdownMenuItem<int>(
                              value: l.id,
                              child: Text(l.name),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _selectedLocationId = value),
                      ),
                    );
                  },
                ),
                StreamBuilder<List<Supplier>>(
                  stream: _db.supplierDao.watchAll(),
                  builder: (context, snapshot) {
                    final suppliers = snapshot.data ?? [];
                    if (suppliers.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<int?>(
                        initialValue: _selectedSupplierId,
                        decoration: const InputDecoration(
                          labelText: 'Delivered by Supplier / Vendor (Optional)',
                          prefixIcon: Icon(Icons.store_outlined),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('General / Unspecified Vendor'),
                          ),
                          for (final s in suppliers)
                            DropdownMenuItem<int?>(
                              value: s.id,
                              child: Text('${s.name} (${s.phone})'),
                            ),
                        ],
                        onChanged: (val) => setState(() => _selectedSupplierId = val),
                      ),
                    );
                  },
                ),
              ] else if (_direction == StockDirection.outward && _availableBatches.isNotEmpty) ...[
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.inventory, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Deduct from Batch (FIFO)',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        InputDecorator(
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              value: _selectedBatchId,
                              isExpanded: true,
                              isDense: true,
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('General Stock (No specific batch)'),
                                ),
                                for (var i = 0; i < _availableBatches.length; i++)
                                  DropdownMenuItem<int?>(
                                    value: _availableBatches[i].id,
                                    child: Text(
                                      '#${_availableBatches[i].batchNumber} '
                                      '(${_availableBatches[i].stockQty} left'
                                      '${_availableBatches[i].expiryDate != null ? " · Exp: ${fmt.format(_availableBatches[i].expiryDate!)}" : ""})'
                                      '${i == 0 && _availableBatches[i].stockQty > 0 ? " [FIFO]" : ""}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (val) => setState(() => _selectedBatchId = val),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              TextField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Note / Reason (optional)',
                  hintText: 'e.g. Supplier delivery, Customer sale, Damaged',
                  prefixIcon: Icon(Icons.notes_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(_direction == StockDirection.inward ? Icons.add_circle : Icons.remove_circle),
                label: Text(
                  _direction == StockDirection.inward ? 'Confirm Stock In' : 'Confirm Stock Out',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    final qty = int.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a quantity above zero')),
      );
      return;
    }

    setState(() => _saving = true);
    final signedQty = _direction == StockDirection.inward ? qty : -qty;
    final reason = _direction == StockDirection.inward ? 'Stock in' : 'Stock out';

    int? batchIdToRecord = _selectedBatchId;

    // If stock-in has a batch number provided, link or create it
    final batchNum = _batchNumberController.text.trim();
    if (_direction == StockDirection.inward && batchNum.isNotEmpty) {
      batchIdToRecord = await _db.batchDao.getOrCreateBatch(
        productId: widget.productId,
        batchNumber: batchNum,
        expiryDate: _expiryDate,
      );
    }

    await _db.movementDao.recordMovement(
      productId: widget.productId,
      qtyDelta: signedQty,
      reason: reason,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      batchId: batchIdToRecord,
      supplierId: _direction == StockDirection.inward ? _selectedSupplierId : null,
      // Null falls back to the default location, so a single-shop user never
      // has to pick one.
      locationId: _selectedLocationId,
    );

    if (!mounted) return;

    if (_direction == StockDirection.inward) {
      final product = await _db.productDao.getById(widget.productId);
      Supplier? supplier;
      if (_selectedSupplierId != null) {
        supplier = await _db.supplierDao.getById(_selectedSupplierId!);
      }

      setState(() => _saving = false);
      if (!mounted) return;

      final action = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Stock Inward Recorded (+ $qty ${product?.unit ?? "units"})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.print_outlined, color: Colors.blueGrey),
                title: const Text('Print Delivery Slip (ESC/POS)'),
                subtitle: const Text('Thermal receipt for vendor or shopkeeper record'),
                onTap: () => Navigator.pop(ctx, 'print_slip'),
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_2, color: Colors.deepPurple),
                title: const Text('Print Barcode Stickers'),
                subtitle: Text('Generate $qty sticker labels for packets'),
                onTap: () => Navigator.pop(ctx, 'print_labels'),
              ),
              ListTile(
                leading: const Icon(Icons.check),
                title: const Text('Done & Return'),
                onTap: () => Navigator.pop(ctx, 'done'),
              ),
            ],
          ),
        ),
      );

      if (!mounted) return;

      if (action == 'print_slip' && product != null) {
        if (!mounted) return;
        final identity = await resolvePrintIdentity(context, _db);
        if (identity == null) return;

        final b58 = EscPosService.buildDeliverySlipBytes(
          product: product,
          quantity: qty,
          reason: reason,
          supplier: supplier,
          batchNumber: batchNum.isEmpty ? null : batchNum,
          expiryDate: _expiryDate,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          shopName: identity.shopName,
          proUnlocked: identity.proUnlocked,
          paperWidth: ThermalPaperWidth.mm58,
        );
        final b80 = EscPosService.buildDeliverySlipBytes(
          product: product,
          quantity: qty,
          reason: reason,
          supplier: supplier,
          batchNumber: batchNum.isEmpty ? null : batchNum,
          expiryDate: _expiryDate,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          shopName: identity.shopName,
          proUnlocked: identity.proUnlocked,
          paperWidth: ThermalPaperWidth.mm80,
        );
        final t58 = EscPosService.buildDeliverySlipText(
          product: product,
          quantity: qty,
          reason: reason,
          supplier: supplier,
          batchNumber: batchNum.isEmpty ? null : batchNum,
          expiryDate: _expiryDate,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          shopName: identity.shopName,
          proUnlocked: identity.proUnlocked,
          paperWidth: ThermalPaperWidth.mm58,
        );
        final t80 = EscPosService.buildDeliverySlipText(
          product: product,
          quantity: qty,
          reason: reason,
          supplier: supplier,
          batchNumber: batchNum.isEmpty ? null : batchNum,
          expiryDate: _expiryDate,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          shopName: identity.shopName,
          proUnlocked: identity.proUnlocked,
          paperWidth: ThermalPaperWidth.mm80,
        );

        if (mounted) {
          await ThermalSlipPreviewSheet.show(
            context,
            title: 'Stock Inward Delivery Slip',
            slipBytes58: b58,
            slipBytes80: b80,
            slipText58: t58,
            slipText80: t80,
            fileNamePrefix: 'delivery_slip',
          );
        }
      } else if (action == 'print_labels' && product != null) {
        if (!mounted) return;
        if (!await requirePro(context, _db)) return;
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BarcodeLabelPrintPage(
                initialProduct: product,
                initialCount: qty,
                batchNumber: batchNum.isEmpty ? null : batchNum,
                expiryDate: _expiryDate,
              ),
            ),
          );
        }
      }
    }

    if (mounted) Navigator.pop(context);
  }
}
