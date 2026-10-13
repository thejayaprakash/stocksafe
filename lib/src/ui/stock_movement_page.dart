import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/database.dart';

enum StockDirection { inward, outward }

/// Stock in / stock out. Writes an append-only movement row — the
/// product's stock number is only ever a derived cache.
class StockMovementPage extends StatefulWidget {
  const StockMovementPage({
    super.key,
    required this.db,
    required this.productId,
    this.initialDirection = StockDirection.inward,
  });

  final AppDatabase db;
  final int productId;
  final StockDirection initialDirection;

  @override
  State<StockMovementPage> createState() => _StockMovementPageState();
}

class _StockMovementPageState extends State<StockMovementPage> {
  late StockDirection _direction = widget.initialDirection;
  final _qtyController = TextEditingController();
  final _noteController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _qtyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock movement')),
      body: FutureBuilder<Product?>(
        future: widget.db.productDao.getById(widget.productId),
        builder: (context, snapshot) {
          final product = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (product != null) ...[
                Text(product.name, style: Theme.of(context).textTheme.titleLarge),
                Text(
                  'Current stock: ${product.stockQty} ${product.unit}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
              ],
              SegmentedButton<StockDirection>(
                segments: const [
                  ButtonSegment(
                    value: StockDirection.inward,
                    label: Text('Stock in'),
                    icon: Icon(Icons.arrow_downward),
                  ),
                  ButtonSegment(
                    value: StockDirection.outward,
                    label: Text('Stock out'),
                    icon: Icon(Icons.arrow_upward),
                  ),
                ],
                selected: {_direction},
                onSelectionChanged: (s) =>
                    setState(() => _direction = s.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _qtyController,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(
                  _direction == StockDirection.inward ? 'Add stock' : 'Remove stock',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    final qty = int.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a quantity above zero')),
      );
      return;
    }

    setState(() => _saving = true);
    final signedQty = _direction == StockDirection.inward ? qty : -qty;
    final reason =
        _direction == StockDirection.inward ? 'Stock in' : 'Stock out';

    await widget.db.movementDao.recordMovement(
      productId: widget.productId,
      qtyDelta: signedQty,
      reason: reason,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
    );

    if (mounted) Navigator.pop(context);
  }
}
