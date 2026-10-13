import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/database.dart';
import '../services/diagnostic_service.dart';
import '../services/label_ocr_service.dart';
import '../services/license_service.dart';
import 'widgets/paywall_sheet.dart';
import '../app_scope.dart';

/// Add or edit a product. Soft fields only — stock changes go through
/// the movement ledger, never this screen.
///
/// [prefillBarcode] is set when arriving from the scanner with an unknown
/// barcode — saves the user from typing it manually.
class ProductEditPage extends StatefulWidget {
  const ProductEditPage({
    super.key,
    this.product,
    this.prefillBarcode,
  });
  final Product? product;
  final String? prefillBarcode;

  @override
  State<ProductEditPage> createState() => _ProductEditPageState();
}

class _ProductEditPageState extends State<ProductEditPage> {
  /// The live database, read through the scope rather than passed in.
  /// Uses [AppScope.read] so it is safe to call from initState; widgets that
  /// must rebuild when the connection is replaced should call AppScope.of in
  /// build instead.
  AppDatabase get _db => AppScope.read(context).db;

  final _formKey = GlobalKey<FormState>();
  final _ocrService = LabelOcrService();
  final _picker = ImagePicker();

  late final TextEditingController _name = TextEditingController(
    text: widget.product?.name ?? '',
  );
  late final TextEditingController _category = TextEditingController(
    text: widget.product?.category ?? '',
  );
  late final TextEditingController _sku = TextEditingController(
    text: widget.product?.sku ?? '',
  );
  late final TextEditingController _barcode = TextEditingController(
    text: widget.product?.barcode ?? widget.prefillBarcode ?? '',
  );
  late final TextEditingController _unit = TextEditingController(
    text: widget.product?.unit ?? 'pcs',
  );
  late final TextEditingController _buyPrice = TextEditingController(
    text: widget.product == null ? '' : _fmt(widget.product!.buyPrice),
  );
  late final TextEditingController _sellPrice = TextEditingController(
    text: widget.product == null ? '' : _fmt(widget.product!.sellPrice),
  );
  late final TextEditingController _lowStock = TextEditingController(
    text: widget.product == null ? '' : '${widget.product!.lowStockLevel}',
  );
  int? _supplierId;

  bool _isOcrProcessing = false;

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    _supplierId = widget.product?.supplierId;
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _sku.dispose();
    _barcode.dispose();
    _unit.dispose();
    _buyPrice.dispose();
    _sellPrice.dispose();
    _lowStock.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit product' : 'Add product'),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined),
            tooltip: 'Scan Label (AI OCR)',
            onPressed: _isOcrProcessing ? null : _scanLabelOcr,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // AI Label OCR Trigger
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: _isOcrProcessing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.document_scanner_outlined, color: Colors.purple),
              label: Text(_isOcrProcessing ? 'Reading label with ML Kit…' : 'Scan Label with AI OCR (MRP, Expiry, Pack)'),
              onPressed: _isOcrProcessing ? null : _scanLabelOcr,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Name *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _category,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Category (e.g. Dairy, Spices, Beverages)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category_outlined),
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _sku,
                    decoration: const InputDecoration(
                      labelText: 'SKU / Brand',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _unit,
                    decoration: const InputDecoration(
                      labelText: 'Unit / Pack',
                      hintText: 'pcs, 500g, 1L',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _barcode,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: 'Barcode',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.qr_code),
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _buyPrice,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Buy Price (Cost)',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _sellPrice,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Sell Price (MRP)',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _lowStock,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Low Stock Alert Threshold',
                helperText: 'Shows restock alert when count is at or below this level',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),

            // Preferred Supplier Dropdown
            StreamBuilder<List<Supplier>>(
              stream: _db.supplierDao.watchAll(),
              builder: (context, snapshot) {
                final suppliers = snapshot.data ?? [];
                return DropdownButtonFormField<int?>(
                  initialValue: _supplierId,
                  decoration: const InputDecoration(
                    labelText: 'Preferred Supplier / Vendor',
                    hintText: 'Select supplier for reorders',
                    prefixIcon: Icon(Icons.store_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('None (Unassigned)'),
                    ),
                    for (final s in suppliers)
                      DropdownMenuItem<int?>(
                        value: s.id,
                        child: Text('${s.name} (${s.phone})'),
                      ),
                  ],
                  onChanged: (val) => setState(() => _supplierId = val),
                );
              },
            ),
            const SizedBox(height: 24),

            FilledButton(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _save,
              child: Text(_isEdit ? 'Save Changes' : 'Add Product', style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanLabelOcr() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Capture Label with Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pick Image from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      setState(() => _isOcrProcessing = true);
      final picked = await _picker.pickImage(source: source);
      if (picked == null) {
        setState(() => _isOcrProcessing = false);
        return;
      }

      final parsed = await _ocrService.extractFromImage(picked.path);

      if (!mounted) return;
      setState(() => _isOcrProcessing = false);

      if (!parsed.hasAnyExtractedField) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No text recognized. Hold camera steady with clear lighting.'),
          ),
        );
        return;
      }

      _showOcrResultSheet(parsed);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isOcrProcessing = false);
      DiagnosticService.instance.log('Label OCR failed: $e', level: 'ERROR');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not read the label. Try better light, or type the '
            'details in.',
          ),
        ),
      );
    }
  }

  void _showOcrResultSheet(ParsedLabelData data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'AI OCR Extracted Values',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Review values extracted directly from packaging label:',
              style: TextStyle(color: Colors.grey),
            ),
            const Divider(height: 24),
            if (data.mrp != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.currency_rupee, color: Colors.green),
                title: const Text('Printed MRP'),
                trailing: Text(
                  '₹${data.mrp}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            if (data.netQuantity != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.scale_outlined, color: Colors.blue),
                title: const Text('Net Quantity / Pack'),
                trailing: Text(
                  data.netQuantity!,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            if (data.expiryDate != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today, color: Colors.orange),
                title: const Text('Expiry / Best Before'),
                trailing: Text(
                  data.expiryDate!,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            if (data.batchNumber != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.tag, color: Colors.deepPurple),
                title: const Text('Batch Number'),
                trailing: Text(
                  data.batchNumber!,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Apply Extracted Values to Product'),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    if (data.suggestedName != null && _name.text.isEmpty) {
                      _name.text = data.suggestedName!;
                    }
                    if (data.mrp != null) {
                      _sellPrice.text = '${data.mrp}';
                    }
                    if (data.netQuantity != null) {
                      _unit.text = data.netQuantity!;
                    }
                    final identifiers = [
                      if (data.batchNumber != null) data.batchNumber!,
                      if (data.expiryDate != null) 'EXP:${data.expiryDate!}',
                    ];
                    if (identifiers.isNotEmpty && _sku.text.isEmpty) {
                      _sku.text = identifiers.join(' · ');
                    }
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Label data applied to fields!')),
                  );
                },
              ),
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
    final category = _category.text.trim();
    final sku = _sku.text.trim();
    final barcode = _barcode.text.trim();
    final unit = _unit.text.trim().isEmpty ? 'pcs' : _unit.text.trim();
    final buyPrice = double.tryParse(_buyPrice.text.trim()) ?? 0;
    final sellPrice = double.tryParse(_sellPrice.text.trim()) ?? 0;
    final lowStock = int.tryParse(_lowStock.text.trim()) ?? 0;

    // Duplicate barcode detection
    if (barcode.isNotEmpty) {
      final existing = await _db.productDao.getByBarcode(barcode);
      if (existing != null && (_isEdit ? existing.id != widget.product!.id : true)) {
        if (!mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text('Duplicate Barcode'),
              ],
            ),
            content: Text(
              'Barcode "$barcode" is already assigned to "${existing.name}".\n\n'
              'Using duplicate barcodes can lead to ambiguity during scanner operations. Do you want to save anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel & Change'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Proceed Anyway'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }
    }

    if (_isEdit) {
      await _db.productDao.updateProduct(
        widget.product!.id,
        ProductsCompanion(
          name: Value(name),
          category: Value(category.isEmpty ? null : category),
          sku: Value(sku.isEmpty ? null : sku),
          barcode: Value(barcode.isEmpty ? null : barcode),
          unit: Value(unit),
          buyPrice: Value(buyPrice),
          sellPrice: Value(sellPrice),
          lowStockLevel: Value(lowStock),
          supplierId: Value(_supplierId),
        ),
      );
    } else {
      final canAdd = await LicenseService(_db).canAddProduct();
      if (!mounted) return;
      if (!canAdd) {
        final unlocked = await PaywallSheet.show(context);
        if (unlocked != true) return;
      }
      if (!mounted) return;

      await _db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: name,
          category: Value(category.isEmpty ? null : category),
          sku: Value(sku.isEmpty ? null : sku),
          barcode: Value(barcode.isEmpty ? null : barcode),
          unit: Value(unit),
          buyPrice: Value(buyPrice),
          sellPrice: Value(sellPrice),
          lowStockLevel: Value(lowStock),
          supplierId: Value(_supplierId),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    if (mounted) Navigator.pop(context);
  }
}
