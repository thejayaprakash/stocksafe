import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../services/product_image_service.dart';

/// The square that leads a product row or tile.
///
/// It shows `product.imagePath` when there is one, and otherwise a tinted
/// initial drawn from the product's own category and name — which is what
/// every product has today, since nothing writes that column yet.
///
/// The photo is a best effort, never a requirement: the file lives on this
/// device, so it can have been deleted, moved by the OS, or restored onto a
/// different phone than the one the database came from. Any failure to load
/// falls straight back to the initial rather than leaving a broken box in
/// the middle of the catalogue.
class ProductAvatar extends StatelessWidget {
  const ProductAvatar({
    super.key,
    required this.product,
    this.size = 44,
    this.radiusFactor = 0.26,
  });

  final Product product;
  final double size;

  /// Corner radius as a fraction of [size]; the hero panel on the product
  /// page is much larger than a row's square and needs a softer corner.
  final double radiusFactor;

  static const _swatches = [
    Color(0xFF1A73E8),
    Color(0xFF7C3AED),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF0EA5E9),
  ];

  /// A stable colour per category, so a shelf reads as one group.
  Color get _accent {
    final key = (product.category ?? product.name).trim();
    if (key.isEmpty) return _swatches.first;
    final hash = key.codeUnits.fold<int>(0, (a, b) => a + b);
    return _swatches[hash % _swatches.length];
  }

  String get _initial {
    final name = product.name.trim();
    return name.isEmpty ? '?' : name.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _accent;
    final radius = BorderRadius.circular(size * radiusFactor);

    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.22 : 0.14),
        borderRadius: radius,
      ),
      child: Text(
        _initial,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );

    // Stored relative to the app's support directory, so a database
    // restored onto another phone still finds its photos.
    final file = ProductImageService.resolve(product.imagePath);
    if (file == null) return fallback;

    // The initial sits underneath rather than inside an errorBuilder, so the
    // square is never blank: reading the file is disk I/O that completes a
    // frame or more after the row is laid out, and a missing file is only
    // discovered at the end of it. The photo covers this when it arrives.
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          fallback,
          ClipRRect(
            borderRadius: radius,
            child: Image.file(
              file,
              width: size,
              height: size,
              fit: BoxFit.cover,
              // Decoded at the size it is drawn at. A 4MP shop photo in a
              // 44px square would otherwise hold several megabytes of bitmap
              // per row, times every row on screen.
              cacheWidth:
                  (size * MediaQuery.devicePixelRatioOf(context)).round(),
              // Fade in, or the initial visibly pops out from under it.
              frameBuilder: (context, child, frame, wasSyncLoaded) {
                if (wasSyncLoaded) return child;
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 180),
                  child: child,
                );
              },
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
