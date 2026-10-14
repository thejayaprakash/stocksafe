import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../theme/app_palette.dart';
import '../money_format.dart';

/// The bar of actions shown while products are selected.
///
/// Every one of these writes to more than one row, so each asks first and
/// each says exactly how many products it is about to touch. "Delete" on a
/// screen where the selection is off-screen above the fold is otherwise a
/// button whose consequences the user cannot see.
class BulkActionBar extends StatelessWidget {
  const BulkActionBar({
    super.key,
    required this.count,
    required this.onAdjustStock,
    required this.onUpdatePrice,
    required this.onChangeCategory,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onAdjustStock;
  final VoidCallback onUpdatePrice;
  final VoidCallback onChangeCategory;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = count > 0;

    Widget action(IconData icon, String label, VoidCallback onTap,
        {Color? accent}) {
      final tint = accent ?? palette.textSecondary;
      return Expanded(
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: enabled ? tint : palette.textDisabled,
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: enabled ? tint : palette.textDisabled,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: palette.cardSurface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              action(Icons.swap_vert_rounded, 'Adjust\nStock', onAdjustStock),
              action(Icons.sell_outlined, 'Update\nPrice', onUpdatePrice),
              action(
                Icons.category_outlined,
                'Change\nCategory',
                onChangeCategory,
              ),
              action(
                Icons.delete_outline_rounded,
                'Delete',
                onDelete,
                accent: palette.error,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for a signed quantity and a reason, for [BulkActionBar.onAdjustStock].
///
/// Returns null if the user backs out. The delta is applied to every selected
/// product, not divided between them.
Future<({int qtyDelta, String reason})?> askBulkAdjustment(
  BuildContext context,
  int productCount,
) {
  return showDialog<({int qtyDelta, String reason})>(
    context: context,
    builder: (context) => _BulkAdjustDialog(productCount: productCount),
  );
}

class _BulkAdjustDialog extends StatefulWidget {
  const _BulkAdjustDialog({required this.productCount});

  final int productCount;

  @override
  State<_BulkAdjustDialog> createState() => _BulkAdjustDialogState();
}

class _BulkAdjustDialogState extends State<_BulkAdjustDialog> {
  final _quantity = TextEditingController();
  bool _inward = true;
  String _reason = 'purchase';

  static const _inReasons = {
    'purchase': 'Purchase',
    'return': 'Return',
    'opening_stock': 'Opening stock',
  };
  static const _outReasons = {
    'sale': 'Sale',
    'damage': 'Damage',
    'return': 'Return',
  };

  Map<String, String> get _reasons => _inward ? _inReasons : _outReasons;

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  void _setDirection(bool inward) {
    setState(() {
      _inward = inward;
      // The reason lists differ, so a reason chosen for one direction can be
      // meaningless in the other.
      if (!_reasons.containsKey(_reason)) _reason = _reasons.keys.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final quantity = int.tryParse(_quantity.text.trim()) ?? 0;

    return AlertDialog(
      title: const Text('Adjust stock'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Applied to each of the ${widget.productCount} selected '
            '${widget.productCount == 1 ? 'product' : 'products'}.',
            style: TextStyle(fontSize: 12.5, color: palette.textTertiary),
          ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                icon: Icon(Icons.arrow_downward_rounded, size: 17),
                label: Text('Stock In'),
              ),
              ButtonSegment(
                value: false,
                icon: Icon(Icons.arrow_upward_rounded, size: 17),
                label: Text('Stock Out'),
              ),
            ],
            selected: {_inward},
            onSelectionChanged: (s) => _setDirection(s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _quantity,
            autofocus: true,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Quantity per product',
              hintText: '0',
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _reason,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: [
              for (final entry in _reasons.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) => setState(() => _reason = value ?? _reason),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          // Zero is not an adjustment, and the ledger rejects it outright.
          onPressed: quantity <= 0
              ? null
              : () => Navigator.pop(
                    context,
                    (
                      qtyDelta: _inward ? quantity : -quantity,
                      reason: _reason,
                    ),
                  ),
          child: Text(_inward ? 'Add to all' : 'Remove from all'),
        ),
      ],
    );
  }
}

/// Asks for one selling price to put on every selected product.
Future<double?> askBulkPrice(BuildContext context, int productCount) async {
  final controller = TextEditingController();
  final palette = context.palette;

  final result = await showDialog<double>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final parsed = double.tryParse(controller.text.trim());
        return AlertDialog(
          title: const Text('Update selling price'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Replaces the MRP on all $productCount selected '
                '${productCount == 1 ? 'product' : 'products'}. '
                'Cost prices are left alone.',
                style: TextStyle(fontSize: 12.5, color: palette.textTertiary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Sell Price (MRP)',
                  prefixText: '₹ ',
                  hintText: '0',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: parsed == null || parsed < 0
                  ? null
                  : () => Navigator.pop(context, parsed),
              child: Text(
                parsed == null ? 'Apply' : 'Set ${formatRupees(parsed)}',
              ),
            ),
          ],
        );
      },
    ),
  );

  controller.dispose();
  return result;
}

/// Asks which category the selection should move to, offering the ones the
/// shop already uses before a free-text field.
Future<({String? category})?> askBulkCategory(
  BuildContext context,
  AppDatabase db,
  int productCount,
) async {
  final existing = await db.productDao.getCategories();
  if (!context.mounted) return null;

  final controller = TextEditingController();
  final palette = context.palette;

  final result = await showDialog<({String? category})>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Change category'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Moves all $productCount selected '
                '${productCount == 1 ? 'product' : 'products'}.',
                style: TextStyle(fontSize: 12.5, color: palette.textTertiary),
              ),
              const SizedBox(height: 14),
              if (existing.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in existing)
                      ActionChip(
                        label: Text(category),
                        onPressed: () =>
                            Navigator.pop(context, (category: category)),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: controller,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Or a new category',
                  hintText: 'Beverages',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          // Clearing is a real intent, not a mistake: a bad CSV import puts
          // the wrong category on everything, and the way out is to empty it.
          TextButton(
            onPressed: () => Navigator.pop(context, (category: null)),
            child: const Text('Clear category'),
          ),
          FilledButton(
            onPressed: controller.text.trim().isEmpty
                ? null
                : () => Navigator.pop(
                      context,
                      (category: controller.text.trim()),
                    ),
            child: const Text('Apply'),
          ),
        ],
      ),
    ),
  );

  controller.dispose();
  return result;
}

/// Confirms a bulk delete, naming the number and saying what survives it.
Future<bool> confirmBulkDelete(BuildContext context, int productCount) async {
  final palette = context.palette;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.delete_outline_rounded, color: palette.error),
      title: Text(
        'Delete $productCount '
        '${productCount == 1 ? 'product' : 'products'}?',
      ),
      content: const Text(
        'They are removed from the catalogue. Their stock history is kept, '
        'so nothing in your ledger is lost.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: palette.error),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// The header shown in place of the app bar while a selection is active.
class SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SelectionAppBar({
    super.key,
    required this.count,
    required this.total,
    required this.allSelected,
    required this.onCancel,
    required this.onToggleAll,
  });

  final int count;

  /// How many products the current filters show, which is what "all" means
  /// here — never the whole catalogue when part of it is filtered out.
  final int total;

  final bool allSelected;
  final VoidCallback onCancel;
  final VoidCallback onToggleAll;

  @override
  Size get preferredSize => const Size.fromHeight(104);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppBar(
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          TextButton(onPressed: onCancel, child: const Text('Cancel')),
          const Spacer(),
          Text(
            '$count selected',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          const SizedBox(width: 64),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: InkWell(
          onTap: onToggleAll,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 16, 8),
            child: Row(
              children: [
                Checkbox(
                  value: allSelected,
                  // Tristate reads the middle state as "some", which is what
                  // a partial selection is.
                  tristate: true,
                  onChanged: (_) => onToggleAll(),
                ),
                Text(
                  allSelected ? 'Clear all' : 'Select all ($total)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: palette.textSecondary,
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

/// A checkbox sized and tinted for a product row in selection mode.
class SelectionCheckbox extends StatelessWidget {
  const SelectionCheckbox({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Checkbox(
        value: selected,
        onChanged: (value) => onChanged(value ?? false),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// A short line confirming what a bulk action did, so the result is visible
/// without scrolling the list to check.
void showBulkResult(BuildContext context, String message, {IconData? icon}) {
  final palette = context.palette;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            Icon(icon ?? Icons.check_circle_outline, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: palette.elevatedSurface,
      ),
    );
}

/// Exported so the catalogue can show a tool tile for entering selection
/// mode without restating the icon and wording.
const selectionModeIcon = Icons.checklist_rounded;
