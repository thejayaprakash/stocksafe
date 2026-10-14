import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import 'movement_reason.dart';
import 'pro_gate.dart';

import 'barcode_label_print_page.dart';
import 'product_edit_page.dart';
import 'stock_movement_page.dart';
import '../app_scope.dart';
import '../services/theme_service.dart';
import 'money_format.dart';
import 'widgets/app_tiles.dart';
import 'widgets/external_app.dart';
import 'widgets/product_avatar.dart';

/// Product detail: current stock (derived) plus full movement history.
class ProductDetailPage extends StatelessWidget {
  const ProductDetailPage({super.key, required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context) {
    final db = AppScope.of(context).db;
    final fmt = DateFormat.yMMMd().add_jm();

    return StreamBuilder<Product?>(
      stream: db.productDao.watchById(productId),
      builder: (context, productSnap) {
        final product = productSnap.data;
        if (product == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Product')),
            body: const Center(child: Text('Product not found')),
          );
        }
        final lowStock = product.stockQty <= product.lowStockLevel;

        final palette = context.palette;

        return Scaffold(
          appBar: AppBar(
            // No title: the product's name is the first thing in the body, at
            // a size it deserves, and repeating it in the bar truncates it.
            actions: [
              IconButton(
                icon: const Icon(Icons.qr_code_2),
                tooltip: 'Print Barcode Labels',
                onPressed: () async {
                  if (!await requirePro(context, db)) return;
                  if (!context.mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BarcodeLabelPrintPage(
                        initialProduct: product,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit Product',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductEditPage(product: product),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // Hero. A photo belongs here; until products carry one this is
              // the same tinted square the catalogue uses, at a size that
              // anchors the page.
              Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                  child: ProductAvatar(
                    product: product,
                    size: 168,
                    radiusFactor: 0.12,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.4,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (product.sku != null &&
                            product.sku!.trim().isNotEmpty)
                          Text(
                            'SKU: ${product.sku}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: palette.textTertiary,
                            ),
                          ),
                        _DetailChip(
                          label: product.stockQty <= 0
                              ? 'Out of stock'
                              : (lowStock ? 'Low stock' : 'In stock'),
                          accent: product.stockQty <= 0
                              ? palette.error
                              : (lowStock ? palette.warning : palette.success),
                          icon: product.stockQty <= 0
                              ? Icons.remove_circle_outline
                              : (lowStock
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (product.category != null &&
                            product.category!.trim().isNotEmpty)
                          _DetailChip(
                            label: product.category!,
                            accent: palette.primary,
                          ),
                        _DetailChip(
                          label: product.unit,
                          accent: palette.secondary,
                        ),
                        if (product.barcode != null &&
                            product.barcode!.trim().isNotEmpty)
                          _DetailChip(
                            label: product.barcode!,
                            accent: palette.textTertiary,
                            icon: Icons.qr_code_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const SectionTitle(
                  'Stock Information',
                  padding: EdgeInsets.only(bottom: 10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.cardSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.border),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // The unit belongs in the label, not after the
                          // number. It holds a pack size as often as a
                          // counting word, and "30 200 g" is not a sentence.
                          Expanded(
                            child: _StockFact(
                              label: 'Current Stock (${product.unit})',
                              value: '${product.stockQty}',
                              accent: product.stockQty <= 0
                                  ? palette.error
                                  : (lowStock ? palette.warning : null),
                            ),
                          ),
                          Expanded(
                            child: _StockFact(
                              label: 'Low Stock Alert (${product.unit})',
                              value: product.lowStockLevel > 0
                                  ? '${product.lowStockLevel}'
                                  : 'Not set',
                            ),
                          ),
                        ],
                      ),
                      Divider(height: 24, color: palette.border),
                      Row(
                        children: [
                          Expanded(
                            child: _StockFact(
                              label: 'Buy Price (Cost)',
                              value: formatRupees(product.buyPrice),
                            ),
                          ),
                          Expanded(
                            child: _StockFact(
                              label: 'Sell Price (MRP)',
                              value: formatRupees(product.sellPrice),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // SUPPLIER CARD (TAP-TO-CALL)
              if (product.supplierId != null)
                StreamBuilder<Supplier?>(
                  stream: db.supplierDao.watchById(product.supplierId!),
                  builder: (context, supSnap) {
                    final s = supSnap.data;
                    if (s == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Card.outlined(
                        color: Colors.green.withValues(alpha: 0.05),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            child: Icon(Icons.store_outlined),
                          ),
                          title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Vendor: ${s.phone}${s.gstin != null ? " · GST: ${s.gstin}" : ""}'),
                          trailing: FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green.withValues(alpha: 0.2),
                              foregroundColor: Colors.green.shade900,
                            ),
                            icon: const Icon(Icons.phone, size: 16, color: Colors.green),
                            label: const Text('Call'),
                            onPressed: () => ExternalApp.dial(context, s.phone),
                          ),
                        ),
                      ),
                    );
                  },
                ),

              const Divider(),
              // BATCHES & EXPIRY SECTION
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SectionTitle('Batches & Expiry'),
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StockMovementPage(
                            productId: productId,
                            initialDirection: StockDirection.inward,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Batch'),
                    ),
                  ],
                ),
              ),
              StreamBuilder<List<ProductBatch>>(
                stream: db.batchDao.watchBatchesForProduct(productId),
                builder: (context, batchSnap) {
                  final batches = batchSnap.data ?? [];
                  if (batches.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Text(
                        'No specific batches tracked for this product.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    );
                  }

                  final now = DateTime.now();
                  final dateFmt = DateFormat.yMMMd();

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: batches.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, index) {
                      final b = batches[index];
                      final isExpired = b.expiryDate != null && b.expiryDate!.isBefore(now);
                      final daysLeft = b.expiryDate?.difference(now).inDays;

                      return ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.qr_code_2,
                          color: isExpired ? Colors.red : (daysLeft != null && daysLeft <= 30 ? Colors.orange : Colors.blueGrey),
                        ),
                        title: Text(
                          'Batch #${b.batchNumber}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Qty: ${b.stockQty} ${product.unit}'
                          '${b.expiryDate != null ? " · Exp: ${dateFmt.format(b.expiryDate!)}" : ""}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (b.expiryDate != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isExpired
                                      ? Colors.red.withValues(alpha: 0.15)
                                      : (daysLeft != null && daysLeft <= 30
                                          ? Colors.orange.withValues(alpha: 0.15)
                                          : Colors.green.withValues(alpha: 0.15)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isExpired
                                      ? 'Expired'
                                      : (daysLeft != null && daysLeft <= 30
                                          ? '$daysLeft d left'
                                          : 'Safe'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isExpired
                                        ? Colors.red.shade900
                                        : (daysLeft != null && daysLeft <= 30 ? Colors.deepOrange.shade900 : Colors.green.shade900),
                                  ),
                                ),
                              ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.arrow_outward, size: 18),
                              tooltip: 'Deduct from this batch',
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StockMovementPage(
                                    productId: productId,
                                    initialDirection: StockDirection.outward,
                                    initialBatchId: b.id,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              // Where the stock actually is. Hidden entirely when there is
              // only one place for it to be, so a single-shop user is not
              // shown a breakdown of one row against their own total.
              StreamBuilder<List<LocationStock>>(
                stream: db.locationDao.watchBreakdownFor(productId),
                builder: (context, snap) {
                  final rows = snap.data ?? const <LocationStock>[];
                  if (rows.length < 2) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SectionTitle('Where it is'),
                            TextButton.icon(
                              onPressed: () => _showTransferSheet(
                                context, db, product, rows),
                              icon: const Icon(Icons.swap_horiz, size: 18),
                              label: const Text('Move stock'),
                            ),
                          ],
                        ),
                      ),
                      for (final row in rows)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            row.isDefault
                                ? Icons.store
                                : Icons.warehouse_outlined,
                            size: 20,
                          ),
                          title: Text(row.locationName),
                          trailing: Text(
                            '${row.quantity} ${product.unit}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: row.quantity < 0
                                  ? Colors.red
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: const SectionTitle('Movement history'),
              ),
              StreamBuilder<List<Movement>>(
                stream: db.movementDao.watchForProduct(productId),
                builder: (context, movementSnap) {
                  final movements = movementSnap.data ?? const <Movement>[];
                  if (movements.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No movements yet.'),
                    );
                  }
                  return Column(
                    children: [
                      for (final m in movements)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            m.qtyDelta > 0
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: m.qtyDelta > 0
                                ? Colors.green
                                : Theme.of(context).colorScheme.error,
                          ),
                          title: Row(
                            children: [
                              Text(
                                '${m.qtyDelta > 0 ? '+' : ''}${m.qtyDelta} · '
                                '${readableMovementReason(m.reason)}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              if (m.auditSessionId != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Audit #${m.auditSessionId}',
                                    style: const TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                              if (m.batchId != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Batch',
                                    style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            [
                              fmt.format(m.createdAt),
                              if (m.note != null && m.note!.isNotEmpty) m.note!,
                            ].join(' — '),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          // Two labelled buttons rather than the stacked + and - FABs that
          // were here. A small circle with a minus in it does not say "take
          // stock off this product", and getting it wrong writes a movement
          // the wrong way round into an append-only ledger.
          bottomNavigationBar: _DetailActionBar(
            onEdit: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductEditPage(product: product),
              ),
            ),
            onAdjust: () => _showAdjustSheet(context, product),
          ),
        );
      },
    );
  }

  /// Turns a stored reason into something a shopkeeper reads.
  ///
  /// Reasons are machine identifiers in the ledger — they are filtered on and
  /// exported — but `transfer_in` was reaching the screen verbatim while
  /// hand-entered movements showed "Stock in". Mapping here keeps the stored
  /// value stable and the displayed one human.

  /// Moves stock from one location to another.
  ///
  /// The product total does not change — nothing entered or left the
  /// business, it only moved — so this deliberately reads as "move", never
  /// as stock in or out.
  Future<void> _showTransferSheet(
    BuildContext context,
    AppDatabase db,
    Product product,
    List<LocationStock> holdings,
  ) async {
    final all = await db.locationDao.getAll();
    if (all.length < 2 || !context.mounted) return;

    var fromId = holdings.first.locationId;
    var toId = all.firstWhere((l) => l.id != fromId).id;
    final qtyController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) {
            final available = holdings
                .firstWhere(
                  (h) => h.locationId == fromId,
                  orElse: () => LocationStock(
                    locationId: fromId,
                    locationName: '',
                    isDefault: false,
                    quantity: 0,
                  ),
                )
                .quantity;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Move ${product.name}',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: fromId,
                  decoration: const InputDecoration(
                    labelText: 'From', border: OutlineInputBorder()),
                  items: [
                    for (final l in all)
                      DropdownMenuItem(value: l.id, child: Text(l.name)),
                  ],
                  onChanged: (v) => setSheetState(() {
                    fromId = v!;
                    if (toId == fromId) {
                      toId = all.firstWhere((l) => l.id != fromId).id;
                    }
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: toId,
                  decoration: const InputDecoration(
                    labelText: 'To', border: OutlineInputBorder()),
                  items: [
                    for (final l in all.where((l) => l.id != fromId))
                      DropdownMenuItem(value: l.id, child: Text(l.name)),
                  ],
                  onChanged: (v) => setSheetState(() => toId = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    helperText: '$available ${product.unit} here now',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final qty = int.tryParse(qtyController.text.trim());
                      if (qty == null || qty <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Enter a quantity above zero')),
                        );
                        return;
                      }
                      final navigator = Navigator.of(ctx);
                      final messenger = ScaffoldMessenger.of(ctx);
                      await db.movementDao.transferStock(
                        productId: product.id,
                        fromLocationId: fromId,
                        toLocationId: toId,
                        quantity: qty,
                      );
                      navigator.pop();
                      messenger.showSnackBar(
                        SnackBar(content: Text('Moved $qty ${product.unit}')),
                      );
                    },
                    child: const Text('Move stock'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

}

/// Asks which way the stock is moving, then hands over to the movement
/// screen with that direction already chosen.
Future<void> _showAdjustSheet(BuildContext context, Product product) {
  final palette = context.palette;

  void open(BuildContext sheetContext, StockDirection direction) {
    Navigator.pop(sheetContext);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockMovementPage(
          productId: product.id,
          initialDirection: direction,
        ),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${product.stockQty} in stock · ${product.unit}',
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: IconBadge(
              icon: Icons.arrow_downward_rounded,
              accent: palette.success,
            ),
            title: const Text('Stock In'),
            subtitle: const Text('A delivery, a return, a correction upward'),
            onTap: () => open(sheetContext, StockDirection.inward),
          ),
          ListTile(
            leading: IconBadge(
              icon: Icons.arrow_upward_rounded,
              accent: palette.error,
            ),
            title: const Text('Stock Out'),
            subtitle: const Text('A sale, damage, a correction downward'),
            onTap: () => open(sheetContext, StockDirection.outward),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// A small tinted pill carrying one fact about the product.
class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label, required this.accent, this.icon});

  final String label;
  final Color accent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 10 : 8, 5, 10, 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// One label-over-value cell of the stock information card.
class _StockFact extends StatelessWidget {
  const _StockFact({required this.label, required this.value, this.accent});

  final String label;
  final String value;

  /// Tints the value when it is the one that needs attention.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11.5, color: palette.textTertiary),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: accent ?? palette.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// The pinned Edit / Adjust Stock bar at the foot of the product page.
class _DetailActionBar extends StatelessWidget {
  const _DetailActionBar({required this.onEdit, required this.onAdjust});

  final VoidCallback onEdit;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.cardSurface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 19),
                    label: const Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.primary,
                      side: BorderSide(color: palette.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: onAdjust,
                    icon: const Icon(Icons.swap_vert_rounded, size: 20),
                    label: const Text(
                      'Adjust Stock',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
}
