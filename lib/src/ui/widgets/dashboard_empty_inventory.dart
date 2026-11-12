import 'package:flutter/material.dart';

/// Empty inventory illustration and call-to-actions shown on the Home dashboard
/// when the inventory contains zero active products.
class DashboardEmptyInventory extends StatelessWidget {
  const DashboardEmptyInventory({
    super.key,
    required this.onAddProduct,
    required this.onScanBarcode,
  });

  final VoidCallback onAddProduct;
  final VoidCallback onScanBarcode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 3D Isometric Empty Box Illustration
          const SizedBox(
            width: 220,
            height: 125,
            child: CustomPaint(
              painter: _EmptyBoxIllustrationPainter(),
            ),
          ),
          const SizedBox(height: 14),

          // Heading
          const Text(
            'No products yet',
            style: TextStyle(
              fontSize: 18.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: Color(0xFFF8FAFC),
            ),
          ),
          const SizedBox(height: 6),

          // Subtitle
          const Text(
            'Add your first product to start tracking\nyour inventory.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
              color: Color(0xFF94A3B8),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),

          // Primary CTA Button: + Add Product
          ElevatedButton.icon(
            onPressed: onAddProduct,
            icon: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
            label: const Text(
              'Add Product',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.1,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: const Color(0xFF007AFF).withValues(alpha: 0.35),
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Secondary CTA: Scan Barcode Instead
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onScanBarcode,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 19,
                      color: Color(0xFF3B82F6),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Scan Barcode Instead',
                      style: TextStyle(
                        color: Color(0xFF3B82F6),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the 3D isometric empty inventory box with radiating golden
/// rays, open flaps, and subtle background cloud atmosphere.
class _EmptyBoxIllustrationPainter extends CustomPainter {
  const _EmptyBoxIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.65;

    // 1. Soft base shadow / ground hill
    final groundPaint = Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.85);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 22), width: 180, height: 36),
      groundPaint,
    );

    // 2. Background soft cloud puffs
    final cloudPaint = Paint()..color = const Color(0xFF131F35);
    canvas.drawCircle(Offset(cx - 50, cy - 8), 24, cloudPaint);
    canvas.drawCircle(Offset(cx + 50, cy - 8), 22, cloudPaint);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - 14), width: 70, height: 32),
      cloudPaint,
    );

    // 3. Golden Radiating Rays at Top
    final rayPaint = Paint()
      ..color = const Color(0xFFFBBF24)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Center ray
    canvas.drawLine(Offset(cx, cy - 48), Offset(cx, cy - 32), rayPaint);
    // Left ray (angled -30 deg)
    canvas.drawLine(Offset(cx - 20, cy - 42), Offset(cx - 10, cy - 28), rayPaint);
    // Right ray (angled +30 deg)
    canvas.drawLine(Offset(cx + 20, cy - 42), Offset(cx + 10, cy - 28), rayPaint);

    // Box dimensions
    const bw = 46.0; // half-width
    const topSlope = 14.0; // vertical rise of isometric axes
    const bodyHeight = 36.0; // height of front vertical faces

    // 4. Interior opening cavity
    final interiorPath = Path()
      ..moveTo(cx, cy - topSlope * 2)
      ..lineTo(cx - bw, cy - topSlope)
      ..lineTo(cx, cy)
      ..lineTo(cx + bw, cy - topSlope)
      ..close();
    final interiorPaint = Paint()..color = const Color(0xFF13223A);
    canvas.drawPath(interiorPath, interiorPaint);

    // 5. Back-left flap (angled up-left)
    final bLeftFlap = Path()
      ..moveTo(cx - bw, cy - topSlope)
      ..lineTo(cx - bw - 12, cy - topSlope - 16)
      ..lineTo(cx - 8, cy - topSlope * 2 - 14)
      ..lineTo(cx, cy - topSlope * 2)
      ..close();
    canvas.drawPath(
      bLeftFlap,
      Paint()..color = const Color(0xFF2B5EA6),
    );

    // 6. Back-right flap (angled up-right)
    final bRightFlap = Path()
      ..moveTo(cx, cy - topSlope * 2)
      ..lineTo(cx + 8, cy - topSlope * 2 - 14)
      ..lineTo(cx + bw + 12, cy - topSlope - 16)
      ..lineTo(cx + bw, cy - topSlope)
      ..close();
    canvas.drawPath(
      bRightFlap,
      Paint()..color = const Color(0xFF224E8F),
    );

    // 7. Front-left flap (folded forward-left)
    final fLeftFlap = Path()
      ..moveTo(cx - bw, cy - topSlope)
      ..lineTo(cx - bw - 15, cy - topSlope + 10)
      ..lineTo(cx - 12, cy + 8)
      ..lineTo(cx, cy)
      ..close();
    canvas.drawPath(
      fLeftFlap,
      Paint()..color = const Color(0xFF93C5FD),
    );

    // 8. Front-right flap (folded forward-right)
    final fRightFlap = Path()
      ..moveTo(cx, cy)
      ..lineTo(cx + 12, cy + 8)
      ..lineTo(cx + bw + 15, cy - topSlope + 10)
      ..lineTo(cx + bw, cy - topSlope)
      ..close();
    canvas.drawPath(
      fRightFlap,
      Paint()..color = const Color(0xFF60A5FA),
    );

    // 9. Front-left body face
    final leftFace = Path()
      ..moveTo(cx - bw, cy - topSlope)
      ..lineTo(cx, cy)
      ..lineTo(cx, cy + bodyHeight)
      ..lineTo(cx - bw, cy - topSlope + bodyHeight)
      ..close();
    final leftFacePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
      ).createShader(Rect.fromLTWH(cx - bw, cy - topSlope, bw, bodyHeight + topSlope));
    canvas.drawPath(leftFace, leftFacePaint);

    // 10. Front-right body face
    final rightFace = Path()
      ..moveTo(cx, cy)
      ..lineTo(cx + bw, cy - topSlope)
      ..lineTo(cx + bw, cy - topSlope + bodyHeight)
      ..lineTo(cx, cy + bodyHeight)
      ..close();
    final rightFacePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
      ).createShader(Rect.fromLTWH(cx, cy - topSlope, bw, bodyHeight + topSlope));
    canvas.drawPath(rightFace, rightFacePaint);

    // 11. Tape patch on front-left face
    final tapePath = Path()
      ..moveTo(cx - 16, cy + bodyHeight - 12)
      ..lineTo(cx - 8, cy + bodyHeight - 8)
      ..lineTo(cx - 8, cy + bodyHeight - 2)
      ..lineTo(cx - 16, cy + bodyHeight - 6)
      ..close();
    canvas.drawPath(tapePath, Paint()..color = const Color(0xFF1E3A8A));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
