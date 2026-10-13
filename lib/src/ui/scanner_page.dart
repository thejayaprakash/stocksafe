import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/database.dart';
import 'product_detail_page.dart';
import 'product_edit_page.dart';

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
    // Bundled model — works with no Play Services and no internet.
  );

  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        actions: [
          // Manual entry fallback
          IconButton(
            icon: const Icon(Icons.keyboard_outlined),
            onPressed: _showManualBarcodeDialog,
            tooltip: 'Enter barcode manually',
          ),
          // Torch toggle — storerooms are dark.
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
                  color: theme.colorScheme.primary.withValues(alpha: 0.8),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Bottom instruction and manual entry quick-action
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
        ],
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.trim().isEmpty) return;

    await _handleBarcode(code.trim());
  }

  Future<void> _handleBarcode(String code) async {
    if (_processing) return;
    setState(() => _processing = true);

    // Haptic feedback — shopkeepers scan without looking.
    await HapticFeedback.mediumImpact();

    final existing = await widget.db.productDao.getByBarcode(code);

    if (!mounted) return;

    if (existing != null) {
      // Known product — jump to detail.
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
      // Unknown barcode — jump to add-product with barcode pre-filled.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProductEditPage(
            db: widget.db,
            prefillBarcode: code,
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
              _handleBarcode(trimmed);
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
                _handleBarcode(trimmed);
              }
            },
            child: const Text('Search / Add'),
          ),
        ],
      ),
    );
  }
}
