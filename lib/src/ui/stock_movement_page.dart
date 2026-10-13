import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../services/app_localization.dart';

enum StockDirection { inward, outward }

/// Stock in / stock out. Writes an append-only movement row — the
/// product's stock number is only ever a derived cache.
/// Supports batch assignment and FIFO expiry tracking.
class StockMovementPage extends StatefulWidget {
  const StockMovementPage({
    super.key,
    required this.db,
    required this.productId,
    this.initialDirection = StockDirection.inward,
    this.initialQty,
    this.initialBatchId,
  });

  final AppDatabase db;
  final int productId;
  final StockDirection initialDirection;
  final int? initialQty;
  final int? initialBatchId;

  @override
  State<StockMovementPage> createState() => _StockMovementPageState();
}

class _StockMovementPageState extends State<StockMovementPage> {
  late StockDirection _direction = widget.initialDirection;
  late final _qtyController = TextEditingController(
    text: widget.initialQty != null ? '${widget.initialQty}' : '',
  );
  final _noteController = TextEditingController();
  final _batchNumberController = TextEditingController();
  DateTime? _expiryDate;
  int? _selectedBatchId;
  List<ProductBatch> _availableBatches = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedBatchId = widget.initialBatchId;
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    final batches = await widget.db.batchDao.getBatchesForProduct(widget.productId);
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
        future: widget.db.productDao.getById(widget.productId),
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
      batchIdToRecord = await widget.db.batchDao.getOrCreateBatch(
        productId: widget.productId,
        batchNumber: batchNum,
        expiryDate: _expiryDate,
      );
    }

    await widget.db.movementDao.recordMovement(
      productId: widget.productId,
      qtyDelta: signedQty,
      reason: reason,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      batchId: batchIdToRecord,
    );

    if (mounted) Navigator.pop(context);
  }
}
