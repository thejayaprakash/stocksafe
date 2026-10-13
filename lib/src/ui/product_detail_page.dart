import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import 'package:url_launcher/url_launcher.dart';

import 'barcode_label_print_page.dart';
import 'product_edit_page.dart';
import 'stock_movement_page.dart';
import '../app_scope.dart';

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

        return Scaffold(
          appBar: AppBar(
            title: Text(product.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.qr_code_2),
                tooltip: 'Print Barcode Labels',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BarcodeLabelPrintPage(
                      initialProduct: product,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit Product',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProductEditPage(product: product),
                  ),
                ),
              ),
            ],
          ),
          body: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${product.stockQty}',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: lowStock
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          product.unit,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (lowStock) ...[
                          const SizedBox(width: 12),
                          Chip(
                            label: const Text('Low stock'),
                            backgroundColor:
                                Theme.of(context).colorScheme.errorContainer,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      [
                        if (product.category != null) 'Category: ${product.category}',
                        if (product.sku != null) 'SKU: ${product.sku}',
                        if (product.barcode != null) 'Barcode: ${product.barcode}',
                        'Buy: ₹${product.buyPrice}  ·  Sell: ₹${product.sellPrice}',
                        'Alert at: ${product.lowStockLevel}',
                      ].join('\n'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),

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
                            onPressed: () {
                              final clean = s.phone.replaceAll(RegExp(r'[^0-9+]'), '');
                              launchUrl(Uri.parse('tel:$clean'));
                            },
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
                    Text(
                      'Batches & Expiry',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
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
                            Text(
                              'Where it is',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
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
                child: Text(
                  'Movement history',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
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
                                '${m.qtyDelta > 0 ? '+' : ''}${m.qtyDelta} · ${m.reason}',
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
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'stock_in',
                tooltip: 'Stock in',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StockMovementPage(
                      productId: productId,
                      initialDirection: StockDirection.inward,
                    ),
                  ),
                ),
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'stock_out',
                tooltip: 'Stock out',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StockMovementPage(
                      productId: productId,
                      initialDirection: StockDirection.outward,
                    ),
                  ),
                ),
                child: const Icon(Icons.remove),
              ),
            ],
          ),
        );
      },
    );
  }

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
