import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/database.dart';
import '../services/diagnostic_service.dart';
import '../services/license_service.dart';
import '../services/theme_service.dart';
import 'product_detail_page.dart';
import 'product_edit_page.dart';
import 'widgets/paywall_sheet.dart';
import '../app_scope.dart';

/// Barcode scanner using CameraX + ML Kit bundled model (works offline).
///
/// On scan:
///   • Existing barcode → jump to product detail
///   • Unknown barcode → jump to add-product with barcode pre-filled
///
/// Shopkeepers scan without looking — beep + vibrate on every hit.
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage>
    with WidgetsBindingObserver {
  /// The live database, read through the scope rather than passed in.
  /// Uses [AppScope.read] so it is safe to call from initState; widgets that
  /// must rebuild when the connection is replaced should call AppScope.of in
  /// build instead.
  AppDatabase get _db => AppScope.read(context).db;

  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );

  bool _processing = false;
  bool _isContinuousMode = false;
  final Map<String, _BatchScanItem> _batchItems = {};
  DateTime? _lastScannedTime;
  String? _lastScannedBarcode;
  bool _showingBatchDrawer = false;

  /// Guards the gallery button while the picker and the analysis run, so a
  /// second tap cannot open two pickers.
  bool _busyWithGallery = false;

  /// True while the camera is deliberately stopped — because the app went to
  /// the background, or because the picker is in front of us.
  bool _cameraSuspended = false;

  /// Feedback on every successful scan.
  ///
  /// The dev plan is explicit that this is worth more goodwill than any
  /// feature: shopkeepers scan without looking at the screen, so the scan has
  /// to announce itself. Only the vibration existed; the beep did not.
  Future<void> _confirmScan() async {
    await SystemSound.play(SystemSoundType.click);
    await HapticFeedback.mediumImpact();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Releases the camera. Without it the torch can stay lit and the
    // preview keeps a hold on the device after the page is gone, which the
    // next app to want the camera then cannot get.
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Android can take the camera away while the app is in the background,
    // and a preview left running is a black rectangle on return. Stop on
    // the way out, start again on the way back, and do neither while the
    // gallery picker is in front of us — that suspension is ours to undo.
    switch (state) {
      case AppLifecycleState.resumed:
        if (_cameraSuspended && !_busyWithGallery) {
          _cameraSuspended = false;
          unawaited(_controller.start());
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (!_cameraSuspended) {
          _cameraSuspended = true;
          unawaited(_controller.stop());
        }
    }
  }

  int get _totalScannedUnits =>
      _batchItems.values.fold(0, (sum, item) => sum + item.quantity);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.appBackground,
      appBar: AppBar(
        title: Text(
          _isContinuousMode ? 'Continuous Batch Scan' : 'Scan Barcode',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        actions: [
          // Torch earns the one visible slot: it is the control a shopkeeper
          // reaches for mid-scan, in a dim aisle, without looking away from
          // the shelf. The rest sit in the menu.
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (_, state, __) {
              final on = state.torchState == TorchState.on;
              return IconButton(
                icon: Icon(
                  on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  color: on ? palette.warning : null,
                ),
                onPressed: () => _controller.toggleTorch(),
                tooltip: on ? 'Turn torch off' : 'Turn torch on',
              );
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'More scanner options',
            onSelected: (value) {
              if (value == 'camera') _controller.switchCamera();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'camera',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.cameraswitch_outlined),
                  title: Text('Switch camera'),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(child: _buildViewfinder(palette)),
            _buildControls(palette),
            if (_isContinuousMode && _batchItems.isNotEmpty)
              _buildBatchTray(Theme.of(context)),
          ],
        ),
      ),
    );
  }

  /// The camera, inset and rounded, with the framing brackets and the caption
  /// drawn over it.
  Widget _buildViewfinder(AppPalette palette) {
    final accent = _isContinuousMode ? palette.warning : palette.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                errorBuilder: (context, error) => _buildCameraError(error),
              ),

              // Framing brackets.
              IgnorePointer(
                child: CustomPaint(
                  painter: _ViewfinderPainter(color: accent),
                ),
              ),

              // Continuous-mode status, where the design puts nothing because
              // the design only drew the single-scan case.
              if (_isContinuousMode)
                Positioned(
                  top: 14,
                  left: 14,
                  right: 14,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: palette.warning),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt, color: palette.warning, size: 17),
                          const SizedBox(width: 6),
                          Text(
                            '${_batchItems.length} items · '
                            '$_totalScannedUnits units',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Caption. The gradient is what makes it readable: white text
              // over a live camera is otherwise legible or not depending on
              // what the shelf happens to look like.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 30, 16, 22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _processing
                              ? 'Looking up…'
                              : 'Point barcode within frame',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Works completely offline',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Gallery, the mode switch, and manual entry.
  Widget _buildControls(AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ScanControl(
            icon: Icons.photo_library_outlined,
            label: 'Gallery',
            onTap: _busyWithGallery ? null : _scanFromGallery,
            busy: _busyWithGallery,
          ),
          _ScanControl(
            icon: _isContinuousMode
                ? Icons.bolt_rounded
                : Icons.qr_code_scanner_rounded,
            label: _isContinuousMode ? 'Batch scan' : 'Single scan',
            primary: true,
            accent: _isContinuousMode ? palette.warning : palette.primary,
            onTap: _toggleContinuousMode,
          ),
          _ScanControl(
            icon: Icons.keyboard_outlined,
            label: 'Manual SKU',
            onTap: _showManualBarcodeDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildCameraError(MobileScannerException error) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_outlined,
              size: 56,
              color: Colors.orangeAccent,
            ),
            const SizedBox(height: 16),
            Text(
              'Camera unavailable or permission needed',
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.errorDetails?.message ?? error.errorCode.name,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  onPressed: () => _controller.start(),
                ),
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
  }

  /// The tray of everything scanned so far in continuous mode.
  Widget _buildBatchTray(ThemeData theme) {
    return Container(
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
            onTap: () =>
                setState(() => _showingBatchDrawer = !_showingBatchDrawer),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.inventory, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Batch Tray (${_batchItems.length} items, '
                      '$_totalScannedUnits units)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Icon(
                    _showingBatchDrawer
                        ? Icons.expand_more
                        : Icons.expand_less,
                  ),
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Code: ${item.barcode}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
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
                      Text(
                        '${item.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
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
    );
  }

  void _toggleContinuousMode() {
    setState(() {
      _isContinuousMode = !_isContinuousMode;
      _showingBatchDrawer = _isContinuousMode && _batchItems.isNotEmpty;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        content: Text(
          _isContinuousMode
              ? 'Batch scan on: keep scanning, then apply the whole tray'
              : 'Single scan on',
        ),
      ),
    );
  }

  /// Reads a barcode out of a photo already on the device.
  ///
  /// A supplier's invoice photographed on arrival, or a code too high on a
  /// shelf to hold a phone against, are both things a shopkeeper already has
  /// in their gallery. The same handler runs on the result, so a code found
  /// this way behaves exactly like one found through the lens.
  Future<void> _scanFromGallery() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busyWithGallery = true);
    // The picker is another activity in front of this one, so the camera is
    // stopped for its duration rather than left running behind it.
    await _controller.stop();
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      // Cancelling is a normal outcome, not an error: nothing is said, and
      // the camera comes back in `finally`.
      if (picked == null) return;

      final capture = await _controller.analyzeImage(picked.path);
      final code = capture?.barcodes
          .map((b) => b.rawValue)
          .whereType<String>()
          .firstWhere((value) => value.isNotEmpty, orElse: () => '');

      if (code == null || code.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('No barcode found in that picture'),
          ),
        );
        return;
      }

      await _confirmScan();
      if (!mounted) return;
      if (_isContinuousMode) {
        await _handleContinuousBarcode(code);
      } else {
        await _handleBarcode(code);
      }
    } on UnsupportedError {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Reading a barcode from a picture is not supported '
              'on this device'),
        ),
      );
    } catch (error) {
      DiagnosticService.instance.log(
        'Gallery barcode scan failed: $error',
        level: 'WARN',
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not read that picture')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyWithGallery = false);
        // Only if the app is actually in front. Coming back from the picker
        // straight into the background would otherwise restart a camera
        // that the lifecycle handler had just stopped.
        if (!_cameraSuspended) {
          try {
            await _controller.start();
          } catch (error) {
            DiagnosticService.instance.log(
              'Could not restart the camera after the gallery: $error',
              level: 'WARN',
            );
          }
        }
      }
    }
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

    await _confirmScan();

    if (_batchItems.containsKey(code)) {
      setState(() {
        _batchItems[code]!.quantity++;
        _showingBatchDrawer = true;
      });
    } else {
      final p = await _db.productDao.getByBarcode(code);
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
      await _db.movementDao.recordMovement(
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

    await _confirmScan();

    final existing = await _db.productDao.getByBarcode(code);

    if (!mounted) return;

    if (existing != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailPage(
            productId: existing.id,
          ),
        ),
      );
    } else {
      final canAdd = await LicenseService(_db).canAddProduct();
      if (!mounted) return;
      if (!canAdd) {
        setState(() => _processing = false);
        final unlocked = await PaywallSheet.show(context);
        if (unlocked != true) return;
      }
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProductEditPage(prefillBarcode: code),
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

/// One of the three controls under the viewfinder.
class _ScanControl extends StatelessWidget {
  const _ScanControl({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.accent,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// The larger, filled middle control.
  final bool primary;

  final Color? accent;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tint = accent ?? palette.primary;
    final size = primary ? 68.0 : 52.0;
    final enabled = onTap != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: primary ? tint : palette.cardSurface,
            shape: CircleBorder(
              side: primary
                  ? BorderSide.none
                  : BorderSide(color: palette.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: size,
                height: size,
                child: busy
                    ? Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.primary,
                          ),
                        ),
                      )
                    : Icon(
                        icon,
                        size: primary ? 30 : 23,
                        color: primary
                            ? Colors.white
                            : (enabled
                                ? palette.textSecondary
                                : palette.textDisabled),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: primary ? FontWeight.w700 : FontWeight.w500,
              color: primary ? palette.textPrimary : palette.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The four corner brackets that mark where the barcode should sit.
///
/// Brackets rather than a full rectangle: a closed box reads as a boundary
/// the code must fit inside, and shopkeepers back away from the shelf trying
/// to obey it. The corners suggest the same area without the instruction.
class _ViewfinderPainter extends CustomPainter {
  const _ViewfinderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.78,
      height: size.height * 0.36,
    );
    // The arm length is capped so the brackets stay brackets on a short
    // frame rather than meeting in the middle of each edge.
    final arm = (frame.shortestSide * 0.26).clamp(16.0, 42.0);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    const r = 14.0;
    final path = Path()
      // Top left.
      ..moveTo(frame.left, frame.top + arm)
      ..lineTo(frame.left, frame.top + r)
      ..arcToPoint(
        Offset(frame.left + r, frame.top),
        radius: const Radius.circular(r),
      )
      ..lineTo(frame.left + arm, frame.top)
      // Top right.
      ..moveTo(frame.right - arm, frame.top)
      ..lineTo(frame.right - r, frame.top)
      ..arcToPoint(
        Offset(frame.right, frame.top + r),
        radius: const Radius.circular(r),
      )
      ..lineTo(frame.right, frame.top + arm)
      // Bottom right.
      ..moveTo(frame.right, frame.bottom - arm)
      ..lineTo(frame.right, frame.bottom - r)
      ..arcToPoint(
        Offset(frame.right - r, frame.bottom),
        radius: const Radius.circular(r),
      )
      ..lineTo(frame.right - arm, frame.bottom)
      // Bottom left.
      ..moveTo(frame.left + arm, frame.bottom)
      ..lineTo(frame.left + r, frame.bottom)
      ..arcToPoint(
        Offset(frame.left, frame.bottom - r),
        radius: const Radius.circular(r),
      )
      ..lineTo(frame.left, frame.bottom - arm);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderPainter old) => old.color != color;
}
