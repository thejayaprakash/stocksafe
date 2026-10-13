import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/database.dart';

class AuditRecord {
  const AuditRecord({
    required this.product,
    required this.ledgerStock,
    required this.physicalCount,
    required this.difference,
    required this.auditedAt,
  });

  final Product product;
  final int ledgerStock;
  final int physicalCount;
  final int difference;
  final DateTime auditedAt;
}

/// Intelligent stock-count assistant for continuous shelf auditing.
/// Shopkeepers scan barcodes one after another, enter physical counts,
/// and instantly see discrepancies with one-tap reconciliation.
class StockAuditPage extends StatefulWidget {
  const StockAuditPage({super.key, required this.db});

  final AppDatabase db;

  @override
  State<StockAuditPage> createState() => _StockAuditPageState();
}

class _StockAuditPageState extends State<StockAuditPage> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );

  final List<AuditRecord> _auditHistory = [];
  bool _isProcessing = false;
  bool _cameraActive = true;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Count Audit'),
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
            icon: const Icon(Icons.keyboard),
            tooltip: 'Type Barcode Manually',
            onPressed: _showManualAuditDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera Preview Area
          if (_cameraActive)
            SizedBox(
              height: 220,
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
                    errorBuilder: (ctx, error, child) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.camera_alt_outlined, color: Colors.grey, size: 40),
                          const SizedBox(height: 8),
                          Text('Camera unavailable', style: theme.textTheme.bodyMedium),
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
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.primary, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Scan items sequentially on shelf',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Audit Stats Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('Audited', '${_auditHistory.length}', theme),
                _buildStat(
                  'Matched',
                  '${_auditHistory.where((a) => a.difference == 0).length}',
                  theme,
                  color: Colors.green,
                ),
                _buildStat(
                  'Discrepancies',
                  '${_auditHistory.where((a) => a.difference != 0).length}',
                  theme,
                  color: Colors.orange,
                ),
              ],
            ),
          ),

          // Audit Log List
          Expanded(
            child: _auditHistory.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fact_check_outlined, size: 56, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text('No items audited yet', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text(
                            'Scan shelf barcodes to audit inventory against system counts.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            icon: const Icon(Icons.search),
                            label: const Text('Audit by Search / Code'),
                            onPressed: _showManualAuditDialog,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _auditHistory.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _auditHistory[index];
                      final isMatched = item.difference == 0;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isMatched ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                          child: Icon(
                            isMatched ? Icons.check : Icons.warning_amber,
                            color: isMatched ? Colors.green : Colors.orange,
                          ),
                        ),
                        title: Text(item.product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          'Ledger: ${item.ledgerStock} • Counted: ${item.physicalCount}',
                        ),
                        trailing: Text(
                          isMatched ? 'MATCHED' : (item.difference > 0 ? '+${item.difference}' : '${item.difference}'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isMatched ? Colors.green : (item.difference > 0 ? Colors.blue : Colors.red),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, ThemeData theme, {Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Future<void> _handleScannedBarcode(String code) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    await HapticFeedback.selectionClick();

    final product = await widget.db.productDao.getByBarcode(code);
    if (!mounted) {
      _isProcessing = false;
      return;
    }

    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unknown barcode: $code. Add product first.')),
      );
      _isProcessing = false;
      return;
    }

    await _promptPhysicalCount(product);
    _isProcessing = false;
  }

  Future<void> _promptPhysicalCount(Product product) async {
    final countController = TextEditingController(text: '${product.stockQty}');

    final enteredCount = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Audit: ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ledger stock: ${product.stockQty} ${product.unit}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: countController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Physical Count on Shelf',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_outlined),
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
            child: const Text('Confirm Count'),
          ),
        ],
      ),
    );

    if (enteredCount == null || !mounted) return;

    final diff = enteredCount - product.stockQty;

    if (diff != 0) {
      // Create reconciliation movement in ledger
      await widget.db.movementDao.recordMovement(
        productId: product.id,
        qtyDelta: diff,
        reason: 'Physical Audit (Ledger: ${product.stockQty}, Counted: $enteredCount)',
      );
    }

    setState(() {
      _auditHistory.insert(
        0,
        AuditRecord(
          product: product,
          ledgerStock: product.stockQty,
          physicalCount: enteredCount,
          difference: diff,
          auditedAt: DateTime.now(),
        ),
      );
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            diff == 0
                ? '✅ ${product.name} count matched ($enteredCount)'
                : '⚖️ Reconciled: ${product.name} adjusted by $diff',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showManualAuditDialog() {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Audit Product by Code / SKU'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter barcode or SKU',
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              final val = textController.text.trim();
              if (val.isNotEmpty) {
                _handleScannedBarcode(val);
              }
            },
            child: const Text('Lookup'),
          ),
        ],
      ),
    );
  }
}
