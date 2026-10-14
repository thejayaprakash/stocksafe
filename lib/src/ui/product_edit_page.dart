import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/database.dart';
import '../services/diagnostic_service.dart';
import '../services/label_ocr_service.dart';
import '../services/expiry_parser.dart';
import '../services/license_service.dart';
import '../services/theme_service.dart';
import 'money_format.dart';
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

  /// Batch and expiry read off a label, waiting for the product to exist.
  ///
  /// A batch row needs a product id, and on a new product there is not one
  /// until save. These hold the scanned values in the meantime; [_save]
  /// writes them to the batch table once the id is known.
  String? _pendingBatchNumber;
  DateTime? _pendingExpiry;
  String? _pendingExpiryText;

  static String _fmt(double v) => formatAmount(v);

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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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

            // Batch and expiry no longer land in a text field, so without
            // this the scan would look like it dropped them. They are saved
            // to the batch table, which the form has no column for.
            if (_pendingBatchNumber != null || _pendingExpiryText != null)
              _ScannedBatchNotice(
                batchNumber: _pendingBatchNumber,
                expiryText: _pendingExpiryText,
                expiryParsed: _pendingExpiry,
                onClear: () => setState(() {
                  _pendingBatchNumber = null;
                  _pendingExpiry = null;
                  _pendingExpiryText = null;
                }),
              ),

            const SizedBox(height: 16),

            _Field(
              label: 'Product Name',
              required: true,
              child: TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Aachi Sambar Powder 200g',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
            ),

            _Field(
              label: 'Category',
              child: TextFormField(
                controller: _category,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Dairy, Spices, Beverages…',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
              ),
            ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Field(
                    label: 'SKU / Brand',
                    child: TextFormField(
                      controller: _sku,
                      decoration: const InputDecoration(hintText: 'AASAM200'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Field(
                    label: 'Unit / Pack',
                    child: TextFormField(
                      controller: _unit,
                      decoration: const InputDecoration(
                        hintText: 'pcs, 500g, 1L',
                      ),
                    ),
                  ),
                ),
              ],
            ),

            _Field(
              label: 'Barcode',
              child: TextFormField(
                controller: _barcode,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  hintText: '8901234567890',
                  prefixIcon: Icon(Icons.qr_code),
                ),
              ),
            ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Field(
                    label: 'Buy Price (Cost)',
                    child: TextFormField(
                      controller: _buyPrice,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        prefixText: '₹ ',
                        hintText: '0',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Field(
                    label: 'Sell Price (MRP)',
                    child: TextFormField(
                      controller: _sellPrice,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        prefixText: '₹ ',
                        hintText: '0',
                      ),
                    ),
                  ),
                ),
              ],
            ),

            _Field(
              label: 'Low Stock Alert Threshold',
              hint: 'Shows an alert when stock is at or below this level',
              child: TextFormField(
                controller: _lowStock,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(hintText: '0'),
              ),
            ),

            // Preferred Supplier Dropdown
            StreamBuilder<List<Supplier>>(
              stream: _db.supplierDao.watchAll(),
              builder: (context, snapshot) {
                final suppliers = snapshot.data ?? [];
                return _Field(
                  label: 'Preferred Supplier',
                  child: DropdownButtonFormField<int?>(
                  initialValue: _supplierId,
                  decoration: const InputDecoration(
                    hintText: 'Select supplier for reorders',
                    prefixIcon: Icon(Icons.store_outlined),
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
                  ),
                );
              },
            ),
          ],
        ),
      ),
      // Pinned, so the one button that commits the form is reachable without
      // scrolling past every field to find it.
      bottomNavigationBar: _SaveBar(
        label: _isEdit ? 'Save Changes' : 'Save Product',
        onPressed: _save,
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
                    // Batch and expiry are not SKU text. They used to be
                    // joined into the SKU field, which put a date into the
                    // field used for search and CSV export and left the
                    // "Expiring Soon" tab permanently empty for scanned
                    // products - the one thing scanning an expiry is for.
                    // They are held here and written to the batch table on
                    // save, where getExpiringBatches() can see them.
                    if (data.batchNumber != null || data.expiryDate != null) {
                      _pendingBatchNumber = data.batchNumber;
                      _pendingExpiryText = data.expiryDate;
                      _pendingExpiry = parseLabelExpiry(data.expiryDate);
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
      await _recordScannedBatch(widget.product!.id);
    } else {
      final canAdd = await LicenseService(_db).canAddProduct();
      if (!mounted) return;
      if (!canAdd) {
        final unlocked = await PaywallSheet.show(context);
        if (unlocked != true) return;
      }
      if (!mounted) return;

      final newId = await _db.productDao.insertProduct(
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
      await _recordScannedBatch(newId);
    }

    if (mounted) Navigator.pop(context);
  }

  /// Writes what the label scan found to the batch table.
  ///
  /// A batch row needs a product id, which a new product does not have until
  /// save - hence the pending fields rather than writing it at scan time.
  Future<void> _recordScannedBatch(int productId) async {
    await _db.batchDao.recordScannedLabel(
      productId: productId,
      batchNumber: _pendingBatchNumber,
      expiryText: _pendingExpiryText,
    );
  }
}

/// What the label scan found that the form has no field for.
///
/// Shown because the alternative is a scan that silently appears to lose the
/// batch and expiry it just reported finding.
class _ScannedBatchNotice extends StatelessWidget {
  const _ScannedBatchNotice({
    required this.batchNumber,
    required this.expiryText,
    required this.expiryParsed,
    required this.onClear,
  });

  final String? batchNumber;
  final String? expiryText;
  final DateTime? expiryParsed;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = [
      if (batchNumber != null) 'Batch $batchNumber',
      if (expiryText != null) 'expires $expiryText',
    ];

    // An expiry the parser could not read is worth saying out loud: the batch
    // still saves, but it will never appear under "Expiring Soon".
    final unreadable = expiryText != null && expiryParsed == null;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              unreadable ? Icons.help_outline : Icons.inventory_2_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                unreadable
                    ? '${parts.join(' · ')} — saved as a batch, but the date '
                        'could not be read, so it will not raise an expiry alert.'
                    : '${parts.join(' · ')} — saved as a batch when you save '
                        'this product.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Discard scanned batch',
              onPressed: onClear,
            ),
          ],
        ),
      ),
    );
  }
}

/// A form field with its label above it rather than floating inside.
///
/// A floating label vanishes into the border once the field has a value, so
/// a half-filled form stops saying what each box is for — which matters most
/// on the row where "Buy Price" and "Sell Price" sit side by side and
/// entering the wrong one silently inverts every margin the app reports.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.child,
    this.hint,
    this.required = false,
  });

  final String label;
  final Widget child;

  /// A line of explanation under the input.
  final String? hint;

  final bool required;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: label),
                if (required)
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: palette.error),
                  ),
              ],
            ),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          child,
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 5, left: 2),
              child: Text(
                hint!,
                style: TextStyle(fontSize: 11, color: palette.textTertiary),
              ),
            ),
        ],
      ),
    );
  }
}

/// The pinned save button at the foot of the form.
class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

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
          child: SizedBox(
            height: 50,
            width: double.infinity,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
