import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/database.dart';
import '../services/catalog_enrichment_service.dart';
import '../services/license_service.dart';
import 'product_detail_page.dart';
import 'product_edit_page.dart';
import 'widgets/paywall_sheet.dart';

/// Barcode scanner using CameraX + ML Kit bundled model (works offline).
///
/// On scan:
///   • Existing barcode → jump to product detail
///   • Unknown barcode → jump to add-product with barcode pre-filled
///
/// Shopkeepers scan without looking — beep + vibrate on every hit.
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key, required this.db});

  final AppDatabase db;

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );

  bool _processing = false;
  bool _isContinuousMode = false;
  final Map<String, _BatchScanItem> _batchItems = {};
  DateTime? _lastScannedTime;
  String? _lastScannedBarcode;
  bool _showingBatchDrawer = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _totalScannedUnits =>
      _batchItems.values.fold(0, (sum, item) => sum + item.quantity);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isContinuousMode ? 'Continuous Batch Scan' : 'Scan Barcode'),
        actions: [
          // Continuous mode toggle button
          IconButton(
            icon: Icon(
              _isContinuousMode ? Icons.repeat_on : Icons.repeat,
              color: _isContinuousMode ? Colors.amber : null,
            ),
            tooltip: _isContinuousMode ? 'Switch to Single Scan' : 'Switch to Continuous Batch Scan',
            onPressed: () {
              setState(() {
                _isContinuousMode = !_isContinuousMode;
                _showingBatchDrawer = _isContinuousMode && _batchItems.isNotEmpty;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 1),
                  content: Text(
                    _isContinuousMode
                        ? '⚡ Continuous Mode ON: Scan multiple items rapidly'
                        : 'Single Scan Mode ON',
                  ),
                ),
              );
            },
          ),
          // Manual entry fallback
          IconButton(
            icon: const Icon(Icons.keyboard_outlined),
            onPressed: _showManualBarcodeDialog,
            tooltip: 'Enter barcode manually',
          ),
          // Torch toggle
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (_, state, __) {
              return IconButton(
                icon: Icon(
                  state.torchState == TorchState.on ? Icons.flash_on : Icons.flash_off,
                ),
                onPressed: () => _controller.toggleTorch(),
                tooltip: 'Toggle torch',
              );
            },
          ),
          // Camera switch
          IconButton(
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: () => _controller.switchCamera(),
            tooltip: 'Switch camera',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off_outlined, size: 64, color: Colors.orangeAccent),
                      const SizedBox(height: 16),
                      Text(
                        'Camera unavailable or permission needed',
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.errorDetails?.message ?? error.errorCode.name,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            onPressed: () => _controller.start(),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            icon: const Icon(Icons.keyboard),
                            label: const Text('Type Barcode'),
                            onPressed: _showManualBarcodeDialog,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Scan overlay guide
          Center(
            child: Container(
              width: 280,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isContinuousMode
                      ? Colors.amber.withValues(alpha: 0.85)
                      : theme.colorScheme.primary.withValues(alpha: 0.8),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // Top continuous mode status pill
          if (_isContinuousMode)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt, color: Colors.amber, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Continuous Mode: ${_batchItems.length} items ($_totalScannedUnits units)',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom Single-Scan Prompt
          if (!_isContinuousMode)
            Positioned(
              bottom: 36,
              left: 16,
              right: 16,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        _processing ? 'Looking up…' : 'Point camera at a barcode',
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.black54,
                      ),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Enter code manually'),
                      onPressed: _showManualBarcodeDialog,
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Continuous Batch Drawer / Tray
          if (_isContinuousMode && _batchItems.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, -2)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _showingBatchDrawer = !_showingBatchDrawer),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.inventory, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              'Batch Tray (${_batchItems.length} items, $_totalScannedUnits units)',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Icon(_showingBatchDrawer ? Icons.expand_more : Icons.expand_less),
                          ],
                        ),
                      ),
                    ),
                    if (_showingBatchDrawer) ...[
                      const Divider(height: 1),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          children: _batchItems.values.map((item) {
                            return Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.product?.name ?? 'Unknown #${item.barcode}',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Code: ${item.barcode}',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      if (item.quantity > 1) {
                                        item.quantity--;
                                      } else {
                                        _batchItems.remove(item.barcode);
                                      }
                                    });
                                  },
                                ),
                                Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 20),
                                  onPressed: () => setState(() => item.quantity++),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: Colors.green),
                              icon: const Icon(Icons.arrow_downward, size: 18),
                              label: Text('Stock In (+$_totalScannedUnits)'),
                              onPressed: () => _applyBatchMovements(true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: Colors.red),
                              icon: const Icon(Icons.arrow_upward, size: 18),
                              label: Text('Stock Out (-$_totalScannedUnits)'),
                              onPressed: () => _applyBatchMovements(false),
                            ),
                          ),
                        ],
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

  Future<void> _onDetect(BarcodeCapture capture) async {
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.trim().isEmpty) return;

    final trimmed = code.trim();

    if (_isContinuousMode) {
      await _handleContinuousBarcode(trimmed);
    } else {
      await _handleBarcode(trimmed);
    }
  }

  Future<void> _handleContinuousBarcode(String code) async {
    final now = DateTime.now();
    // Debounce duplicate camera frames for same barcode within 1.2s
    if (_lastScannedBarcode == code &&
        _lastScannedTime != null &&
        now.difference(_lastScannedTime!) < const Duration(milliseconds: 1200)) {
      return;
    }

    _lastScannedBarcode = code;
    _lastScannedTime = now;

    await HapticFeedback.mediumImpact();

    if (_batchItems.containsKey(code)) {
      setState(() {
        _batchItems[code]!.quantity++;
        _showingBatchDrawer = true;
      });
    } else {
      final p = await widget.db.productDao.getByBarcode(code);
      setState(() {
        _batchItems[code] = _BatchScanItem(barcode: code, product: p, quantity: 1);
        _showingBatchDrawer = true;
      });
    }
  }

  Future<void> _applyBatchMovements(bool isStockIn) async {
    final items = _batchItems.values.where((i) => i.product != null).toList();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No registered products in batch to update.')),
      );
      return;
    }

    for (final item in items) {
      final delta = isStockIn ? item.quantity : -item.quantity;
      final reason = isStockIn ? 'Continuous Stock In' : 'Continuous Stock Out';
      await widget.db.movementDao.recordMovement(
        productId: item.product!.id,
        qtyDelta: delta,
        reason: reason,
        note: 'Continuous Barcode Batch',
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Batch complete: ${items.length} products updated (${isStockIn ? "+" : "-"}$_totalScannedUnits units)',
        ),
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _handleBarcode(String code) async {
    if (_processing) return;
    setState(() => _processing = true);

    await HapticFeedback.mediumImpact();

    final existing = await widget.db.productDao.getByBarcode(code);

    if (!mounted) return;

    if (existing != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailPage(
            db: widget.db,
            productId: existing.id,
          ),
        ),
      );
    } else {
      final canAdd = await LicenseService(widget.db).canAddProduct();
      if (!mounted) return;
      if (!canAdd) {
        setState(() => _processing = false);
        final unlocked = await PaywallSheet.show(context, widget.db);
        if (unlocked != true) return;
      }
      if (!mounted) return;

      final catalogInfo = await CatalogEnrichmentService().lookupBarcode(code);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProductEditPage(
            db: widget.db,
            prefillBarcode: code,
            catalogInfo: catalogInfo,
          ),
        ),
      );
    }
  }

  void _showManualBarcodeDialog() {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Barcode'),
        content: TextField(
          controller: textController,
          autofocus: true,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(
            hintText: 'e.g. 8901030895421',
            prefixIcon: Icon(Icons.qr_code),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (val) {
            final trimmed = val.trim();
            if (trimmed.isNotEmpty) {
              Navigator.pop(ctx);
              if (_isContinuousMode) {
                _handleContinuousBarcode(trimmed);
              } else {
                _handleBarcode(trimmed);
              }
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
              final trimmed = textController.text.trim();
              if (trimmed.isNotEmpty) {
                Navigator.pop(ctx);
                if (_isContinuousMode) {
                  _handleContinuousBarcode(trimmed);
                } else {
                  _handleBarcode(trimmed);
                }
              }
            },
            child: const Text('Add to Scan'),
          ),
        ],
      ),
    );
  }
}

class _BatchScanItem {
  final String barcode;
  Product? product;
  int quantity;

  _BatchScanItem({
    required this.barcode,
    this.product,
    this.quantity = 1,
  });
}

