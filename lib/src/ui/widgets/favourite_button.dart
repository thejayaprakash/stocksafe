import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../data/database.dart';
import '../../theme/app_palette.dart';

/// The heart on a product tile or product page.
///
/// It writes straight to the database and lets the product's own stream
/// bring the new value back, rather than holding a local copy. The same
/// product is on screen in more than one place at once — a grid tile and the
/// page opened from it — and two hearts disagreeing about the same row is
/// worse than a frame of latency on a local write.
///
/// Favourites are a local preference, so this works with no network and
/// there is nothing to retry.
class FavouriteButton extends StatelessWidget {
  const FavouriteButton({
    super.key,
    required this.product,
    this.size = 20,
    this.padding = const EdgeInsets.all(6),
  });

  final Product product;
  final double size;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = AppScope.of(context).db;
    final isFavourite = product.isFavourite;

    return Semantics(
      button: true,
      label: isFavourite
          ? 'Remove ${product.name} from favourites'
          : 'Add ${product.name} to favourites',
      child: InkResponse(
        radius: size + 8,
        onTap: () {
          HapticFeedback.selectionClick();
          // Not awaited: the row's own stream delivers the new value, and
          // nothing here needs to run after the write.
          unawaited(db.productDao.setFavourite(product.id, !isFavourite));
        },
        child: Padding(
          padding: padding,
          child: Icon(
            isFavourite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: size,
            // Red only when it is on. An outline in the accent colour reads
            // as "already favourited" at a glance across a grid.
            color: isFavourite ? palette.error : palette.textTertiary,
          ),
        ),
      ),
    );
  }
}
