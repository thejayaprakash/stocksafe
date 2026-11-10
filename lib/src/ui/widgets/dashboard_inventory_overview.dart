import 'package:flutter/material.dart';

import '../../data/dao/product_dao.dart';
import '../../theme/app_palette.dart';
import '../money_format.dart';

/// 4-metric Inventory Overview section.
///
/// Displays:
/// 1. Total Products
/// 2. Total Units
/// 3. Inventory Valuation
/// 4. Low Stock Count
class DashboardInventoryOverview extends StatefulWidget {
  const DashboardInventoryOverview({
    super.key,
    required this.valuation,
    required this.lowStockCount,
    required this.onTapProducts,
    required this.onTapLowStock,
  });

  final InventoryValuationSummary valuation;
  final int lowStockCount;
  final VoidCallback onTapProducts;
  final VoidCallback onTapLowStock;

  @override
  State<DashboardInventoryOverview> createState() =>
      _DashboardInventoryOverviewState();
}

class _DashboardInventoryOverviewState
    extends State<DashboardInventoryOverview> {
  String _selectedTimeframe = 'This Week';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final formattedValue = _formatValuation(widget.valuation.totalRetailValue);
    final formattedUnits = _formatNumber(widget.valuation.totalUnits);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Inventory Overview',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: palette.textPrimary,
              ),
            ),
            // Timeframe dropdown pill
            _TimeframeDropdown(
              selected: _selectedTimeframe,
              onChanged: (val) => setState(() => _selectedTimeframe = val),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 4-Card Responsive Row
        LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              children: [
                // 1. Total Products
                Expanded(
                  child: _MetricCard(
                    accentColor: const Color(0xFF3B82F6), // Blue
                    icon: Icons.inventory_2_rounded,
                    value: '${widget.valuation.totalProducts}',
                    label: 'Products',
                    onTap: widget.onTapProducts,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),

                // 2. Total Units
                Expanded(
                  child: _MetricCard(
                    accentColor: const Color(0xFF22C55E), // Green
                    icon: Icons.layers_rounded,
                    value: formattedUnits,
                    label: 'Total Units',
                    onTap: widget.onTapProducts,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Inventory Value
                Expanded(
                  child: _MetricCard(
                    accentColor: const Color(0xFFA855F7), // Purple
                    icon: Icons.currency_rupee_rounded,
                    value: formattedValue,
                    label: 'Inventory Value',
                    onTap: widget.onTapProducts,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),

                // 4. Low Stock
                Expanded(
                  child: _MetricCard(
                    accentColor: const Color(0xFFF59E0B), // Amber
                    icon: Icons.warning_amber_rounded,
                    value: '${widget.lowStockCount}',
                    label: 'Low Stock',
                    onTap: widget.onTapLowStock,
                    isDark: isDark,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  static String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
    if (number >= 1000) {
      // Use comma formatted number, e.g. 1,248
      final s = number.toString();
      final regex = RegExp(r'\B(?=(\d{3})+(?!\d))');
      return s.replaceAll(regex, ',');
    }
    return number.toString();
  }

  static String _formatValuation(double value) {
    if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(1)}L';
    }
    if (value >= 10000) {
      final whole = value.toInt();
      final s = whole.toString();
      final regex = RegExp(r'\B(?=(\d{3})+(?!\d))');
      return '₹${s.replaceAll(regex, ',')}';
    }
    return formatRupees(value);
  }
}

/// Compact individual metric card.
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.accentColor,
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  final Color accentColor;
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      height: 104,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151E2E) : palette.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? const Color(0xFF334155).withValues(alpha: 0.7)
              : palette.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top: Colored circular/rounded icon badge
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: isDark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: accentColor,
                  ),
                ),

                // Middle: Value
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: isDark ? const Color(0xFFF8FAFC) : palette.textPrimary,
                    ),
                  ),
                ),

                // Bottom: Metric Label
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact timeframe filter chip / dropdown.
class _TimeframeDropdown extends StatelessWidget {
  const _TimeframeDropdown({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopupMenuButton<String>(
      initialValue: selected,
      onSelected: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDark ? const Color(0xFF1E293B) : palette.surfaceCard,
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'Today', child: Text('Today')),
        const PopupMenuItem(value: 'This Week', child: Text('This Week')),
        const PopupMenuItem(value: 'This Month', child: Text('This Month')),
        const PopupMenuItem(value: 'All Time', child: Text('All Time')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : palette.inputBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : palette.border,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFCBD5E1) : palette.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 15,
              color: isDark ? const Color(0xFF94A3B8) : palette.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
