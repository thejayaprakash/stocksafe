import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/database.dart';

/// Add or edit a product. Soft fields only — stock changes go through
/// the movement ledger, never this screen.
///
/// [prefillBarcode] is set when arriving from the scanner with an unknown
/// barcode — saves the user from typing it manually.
class ProductEditPage extends StatefulWidget {
  const ProductEditPage({
    super.key,
    required this.db,
    this.product,
    this.prefillBarcode,
  });

  final AppDatabase db;
  final Product? product;
  final String? prefillBarcode;

  @override
  State<ProductEditPage> createState() => _ProductEditPageState();
}

class _ProductEditPageState extends State<ProductEditPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name =
      TextEditingController(text: widget.product?.name ?? '');
  late final TextEditingController _sku =
      TextEditingController(text: widget.product?.sku ?? '');
  late final TextEditingController _barcode = TextEditingController(
    text: widget.product?.barcode ?? widget.prefillBarcode ?? '',
  );
  late final TextEditingController _unit =
      TextEditingController(text: widget.product?.unit ?? 'pcs');
  late final TextEditingController _buyPrice = TextEditingController(
    text: widget.product == null ? '' : _fmt(widget.product!.buyPrice),
  );
  late final TextEditingController _sellPrice = TextEditingController(
    text: widget.product == null ? '' : _fmt(widget.product!.sellPrice),
  );
  late final TextEditingController _lowStock = TextEditingController(
    text: widget.product == null ? '' : '${widget.product!.lowStockLevel}',
  );

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  bool get _isEdit => widget.product != null;

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _barcode.dispose();
    _unit.dispose();
    _buyPrice.dispose();
    _sellPrice.dispose();
    _lowStock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit product' : 'Add product')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sku,
              decoration: const InputDecoration(labelText: 'SKU'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _barcode,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Barcode',
                helperText: 'Scan or type — wire-up comes with the camera phase',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _unit,
              decoration: const InputDecoration(labelText: 'Unit'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _buyPrice,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Buy price'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _sellPrice,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Sell price'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lowStock,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Low stock alert at',
                helperText: 'You will see a warning at or below this level',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(_isEdit ? 'Save changes' : 'Add product'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final name = _name.text.trim();
    final sku = _sku.text.trim();
    final barcode = _barcode.text.trim();
    final unit = _unit.text.trim().isEmpty ? 'pcs' : _unit.text.trim();
    final buyPrice = double.tryParse(_buyPrice.text.trim()) ?? 0;
    final sellPrice = double.tryParse(_sellPrice.text.trim()) ?? 0;
    final lowStock = int.tryParse(_lowStock.text.trim()) ?? 0;

    if (_isEdit) {
      await widget.db.productDao.updateProduct(
        widget.product!.id,
        ProductsCompanion(
          name: Value(name),
          sku: Value(sku.isEmpty ? null : sku),
          barcode: Value(barcode.isEmpty ? null : barcode),
          unit: Value(unit),
          buyPrice: Value(buyPrice),
          sellPrice: Value(sellPrice),
          lowStockLevel: Value(lowStock),
        ),
      );
    } else {
      await widget.db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: name,
          sku: Value(sku.isEmpty ? null : sku),
          barcode: Value(barcode.isEmpty ? null : barcode),
          unit: Value(unit),
          buyPrice: Value(buyPrice),
          sellPrice: Value(sellPrice),
          lowStockLevel: Value(lowStock),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    if (mounted) Navigator.pop(context);
  }
}
