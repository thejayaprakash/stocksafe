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
    // This adds a few MB but is the whole offline positioning.
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
        title: const Text('Scan barcode'),
        actions: [
          // Torch toggle — shop storerooms are dark.
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
          // Camera switch for devices with multiple cameras.
          IconButton(
            icon: const Icon(Icons.cameraswitch),
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
          ),
          // Scan overlay guide
          Center(
            child: Container(
              width: 280,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.7),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Bottom instruction
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  _processing ? 'Looking up…' : 'Point at a barcode',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
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
    if (code == null || code.isEmpty) return;

    setState(() => _processing = true);

    // Haptic + sound feedback — shopkeepers scan without looking.
    await HapticFeedback.mediumImpact();

    final existing = await widget.db.productDao.getByBarcode(code);

    if (!mounted) return;

    if (existing != null) {
      // Known product — go to detail.
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
      // Unknown barcode — add new product with barcode pre-filled.
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
}
