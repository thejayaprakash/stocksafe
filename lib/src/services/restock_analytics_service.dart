import 'dart:math';
import 'package:drift/drift.dart';

import '../data/database.dart';

/// Restocking recommendation calculated for a product.
class RestockRecommendation {
  const RestockRecommendation({
    required this.product,
    required this.currentStock,
    required this.lowStockLevel,
    required this.dailyConsumptionRate,
    required this.recommendedOrderQty,
    required this.daysOfStockRemaining,
    required this.velocityLabel,
  });

  final Product product;
  final int currentStock;
  final int lowStockLevel;
  final double dailyConsumptionRate;
  final int recommendedOrderQty;
  final double daysOfStockRemaining;
  final String velocityLabel;
}

/// Service that computes consumption velocity and intelligent restock
/// recommendations based on ledger movements.
class RestockAnalyticsService {
  const RestockAnalyticsService(this.db);

  final AppDatabase db;

  /// Calculate restock recommendations for all products currently below or near
  /// their low stock threshold.
  Future<List<RestockRecommendation>> getRecommendations({int daysToAnalyze = 14}) async {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: daysToAnalyze));

    // Get all active products
    final products = await db.productDao.getAllForExport();

    // Get all movements in the time window
    final recentMovements = await (db.select(db.movements)
          ..where((m) => m.createdAt.isBiggerOrEqualValue(cutoff)))
        .get();

    // Group outgoing movements (sales/issues: qtyDelta < 0) by productId
    final Map<int, int> productConsumption = {};
    for (final m in recentMovements) {
      if (m.qtyDelta < 0) {
        final consumed = m.qtyDelta.abs();
        productConsumption[m.productId] = (productConsumption[m.productId] ?? 0) + consumed;
      }
    }

    final List<RestockRecommendation> list = [];

    for (final p in products) {
      final totalConsumed = productConsumption[p.id] ?? 0;
      final dailyRate = totalConsumed / max(1, daysToAnalyze);

      // Determine days of stock remaining
      final double daysRemaining = dailyRate > 0 ? (p.stockQty / dailyRate) : 999.0;

      // Recommended order to cover 14 days of sales plus buffer to exceed lowStockLevel
      int suggestedOrder = 0;
      if (dailyRate > 0) {
        final targetQty = (dailyRate * 14).ceil() + p.lowStockLevel;
        suggestedOrder = max(0, targetQty - p.stockQty);
      } else {
        // No recent sales, but below low stock level
        if (p.stockQty <= p.lowStockLevel) {
          final diff = (p.lowStockLevel * 2) - p.stockQty;
          suggestedOrder = max(10, diff);
        }
      }

      String velocity = 'Slow';
      if (dailyRate >= 3.0) {
        velocity = 'Fast-moving';
      } else if (dailyRate >= 1.0) {
        velocity = 'Moderate';
      } else if (dailyRate == 0) {
        velocity = 'No recent movement';
      }

      // Include if below low stock or stock remaining < 7 days
      if (p.stockQty <= p.lowStockLevel || daysRemaining <= 7.0) {
        list.add(
          RestockRecommendation(
            product: p,
            currentStock: p.stockQty,
            lowStockLevel: p.lowStockLevel,
            dailyConsumptionRate: dailyRate,
            recommendedOrderQty: suggestedOrder,
            daysOfStockRemaining: daysRemaining,
            velocityLabel: velocity,
          ),
        );
      }
    }

    // Sort by most urgent (fewest days of stock remaining)
    list.sort((a, b) => a.daysOfStockRemaining.compareTo(b.daysOfStockRemaining));
    return list;
  }
}
