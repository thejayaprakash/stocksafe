import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../data/database.dart';
import 'print_identity.dart';
import '../services/app_localization.dart';
import '../services/barcode_label_service.dart';
import '../app_scope.dart';

/// Interactive Barcode Label Sticker Generator & Print Screen.
/// Generates standard A4 multi-up sticker sheets (24, 30, 40 labels)
/// and thermal label rolls (50x25mm, 50x30mm) with Code 128 or QR codes
/// for unbranded and loose items packaged in the retail shop.
class BarcodeLabelPrintPage extends StatefulWidget {
  const BarcodeLabelPrintPage({
    super.key,
    this.initialProduct,
    this.initialCount = 24,
    this.batchNumber,
    this.expiryDate,
  });
  final Product? initialProduct;
  final int initialCount;
  final String? batchNumber;
  final DateTime? expiryDate;

  @override
  State<BarcodeLabelPrintPage> createState() => _BarcodeLabelPrintPageState();
}

class _BarcodeLabelPrintPageState extends State<BarcodeLabelPrintPage> {
  /// The live database, read through the scope rather than passed in.
  /// Uses [AppScope.read] so it is safe to call from initState; widgets that
  /// must rebuild when the connection is replaced should call AppScope.of in
  /// build instead.
  AppDatabase get _db => AppScope.read(context).db;

  Product? _selectedProduct;
  late int _count = widget.initialCount;
  LabelSheetFormat _format = LabelSheetFormat.a4_24;
  BarcodeSymbology _symbology = BarcodeSymbology.code128;
  String _shopName = shopNamePlaceholder;
  int _startOffset = 0;
  bool _showPrice = true;
  bool _showPackDate = true;
  final DateTime _packedDate = DateTime.now();
  late final TextEditingController _countController;
  late final TextEditingController _shopNameController;

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.initialProduct;
    _countController = TextEditingController(text: '$_count');
    _shopNameController = TextEditingController(text: _shopName);
    _loadShopName();
  }

  Future<void> _loadShopName() async {
    final saved = await _db.settingDao.get(shopNameSettingKey);
    if (saved != null && saved.trim().isNotEmpty && mounted) {
      setState(() {
        _shopName = saved.trim();
        _shopNameController.text = _shopName;
      });
    }
  }

  @override
  void dispose() {
    _countController.dispose();
    _shopNameController.dispose();
    super.dispose();
  }

  BarcodeLabelConfig _buildConfig() {
    return BarcodeLabelConfig(
      product: _selectedProduct!,
      count: _count,
      format: _format,
      symbology: _symbology,
      shopName: _shopName,
      batchNumber: widget.batchNumber,
      packedDate: _packedDate,
      expiryDate: widget.expiryDate,
      showPrice: _showPrice,
      showPackDate: _showPackDate,
      startOffset: _startOffset,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocale.tr('barcode_label_printing')),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Customize Label Settings',
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: _selectedProduct == null
          ? _buildProductSelector(theme)
          : Column(
              children: [
                _buildQuickControlsBar(theme),
                Expanded(
                  child: PdfPreview(
                    build: (format) => BarcodeLabelService.generateLabelSheet(_buildConfig()),
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    previewPageMargin: const EdgeInsets.all(12),
                    pdfFileName: 'labels_${_selectedProduct!.name.replaceAll(" ", "_")}.pdf',
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProductSelector(ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Select a product to print barcode / QR sticker labels for:',
            style: theme.textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Product>>(
            stream: _db.productDao.watchAll(),
            builder: (context, snapshot) {
              final products = snapshot.data ?? [];
              if (products.isEmpty) {
                return const Center(child: Text('No products available.'));
              }
              return ListView.separated(
                itemCount: products.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final p = products[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: const Icon(Icons.qr_code),
                    ),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'Unit: ${p.unit} · MRP: ₹${p.sellPrice.toStringAsFixed(0)} · Code: ${p.barcode ?? p.sku ?? "SK-${p.id}"}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => setState(() => _selectedProduct = p),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickControlsBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedProduct!.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_format.name} · $_count labels · ${_symbology.label.split(" ").first}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Configure'),
            onPressed: _showSettingsDialog,
          ),
          if (widget.initialProduct == null) ...[
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Switch Product',
              onPressed: () => setState(() => _selectedProduct = null),
            ),
          ],
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Label Sheet Options',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),

                  // Label Format
                  const Text('Sheet / Roll Format:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<LabelSheetFormat>(
                    initialValue: _format,
                    isExpanded: true,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    items: [
                      for (final f in LabelSheetFormat.values)
                        DropdownMenuItem(value: f, child: Text(f.name, style: const TextStyle(fontSize: 13))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => _format = val);
                        setState(() => _format = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Symbology (Code 128 vs QR)
                  const Text('Barcode Type:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  SegmentedButton<BarcodeSymbology>(
                    segments: const [
                      ButtonSegment(value: BarcodeSymbology.code128, label: Text('Code 128 (Bar)')),
                      ButtonSegment(value: BarcodeSymbology.qrCode, label: Text('QR Code (2D)')),
                    ],
                    selected: {_symbology},
                    onSelectionChanged: (s) {
                      setModalState(() => _symbology = s.first);
                      setState(() => _symbology = s.first);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Quantity and Start Offset Row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _countController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Stickers Count',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            final n = int.tryParse(val.trim());
                            if (n != null && n > 0) {
                              setState(() => _count = n);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Skip First Slots',
                            helperText: 'For used sheets',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            final n = int.tryParse(val.trim()) ?? 0;
                            setModalState(() => _startOffset = n);
                            setState(() => _startOffset = n);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Shop Name
                  TextField(
                    controller: _shopNameController,
                    decoration: const InputDecoration(
                      labelText: 'Shop / Brand Name on Label',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      setState(() => _shopName = val.trim());
                    },
                  ),
                  const SizedBox(height: 8),

                  // Toggles
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show Retail Price (MRP)'),
                    value: _showPrice,
                    onChanged: (v) {
                      setModalState(() => _showPrice = v);
                      setState(() => _showPrice = v);
                    },
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show Packed Date'),
                    value: _showPackDate,
                    onChanged: (v) {
                      setModalState(() => _showPackDate = v);
                      setState(() => _showPackDate = v);
                    },
                  ),

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Apply Changes & Refresh Preview'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
