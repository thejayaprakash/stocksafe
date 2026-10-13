import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/esc_pos_service.dart';

/// Modal bottom sheet providing a realistic ESC/POS thermal receipt preview,
/// paper size toggling (58mm vs 80mm), Bluetooth printer file export (RawBT),
/// PDF printing, and clipboard copying.
class ThermalSlipPreviewSheet extends StatefulWidget {
  const ThermalSlipPreviewSheet({
    super.key,
    required this.title,
    required this.slipBytes58,
    required this.slipBytes80,
    required this.slipText58,
    required this.slipText80,
    this.fileNamePrefix = 'receipt',
  });

  final String title;
  final Uint8List slipBytes58;
  final Uint8List slipBytes80;
  final String slipText58;
  final String slipText80;
  final String fileNamePrefix;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required Uint8List slipBytes58,
    required Uint8List slipBytes80,
    required String slipText58,
    required String slipText80,
    String fileNamePrefix = 'receipt',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ThermalSlipPreviewSheet(
        title: title,
        slipBytes58: slipBytes58,
        slipBytes80: slipBytes80,
        slipText58: slipText58,
        slipText80: slipText80,
        fileNamePrefix: fileNamePrefix,
      ),
    );
  }

  @override
  State<ThermalSlipPreviewSheet> createState() => _ThermalSlipPreviewSheetState();
}

class _ThermalSlipPreviewSheetState extends State<ThermalSlipPreviewSheet> {
  ThermalPaperWidth _selectedWidth = ThermalPaperWidth.mm58;
  bool _isExporting = false;

  Uint8List get _activeBytes =>
      _selectedWidth == ThermalPaperWidth.mm58 ? widget.slipBytes58 : widget.slipBytes80;

  String get _activeText =>
      _selectedWidth == ThermalPaperWidth.mm58 ? widget.slipText58 : widget.slipText80;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.print_outlined, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Paper Width Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Thermal Paper Width:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                SegmentedButton<ThermalPaperWidth>(
                  segments: const [
                    ButtonSegment(
                      value: ThermalPaperWidth.mm58,
                      label: Text('58mm (Kirana)'),
                    ),
                    ButtonSegment(
                      value: ThermalPaperWidth.mm80,
                      label: Text('80mm (Wide)'),
                    ),
                  ],
                  selected: {_selectedWidth},
                  onSelectionChanged: (s) => setState(() => _selectedWidth = s.first),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Receipt Paper View
          Expanded(
            child: Container(
              color: Colors.grey.shade200,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: _selectedWidth == ThermalPaperWidth.mm58 ? 320 : 420,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Perforated Top
                      _buildPerforatedEdge(),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: SelectableText(
                            _activeText,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              height: 1.35,
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      // Perforated Bottom
                      _buildPerforatedEdge(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Action Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Copy Text
                  OutlinedButton.icon(
                    onPressed: _copyText,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                  ),
                  const SizedBox(width: 8),

                  // Print / Save PDF
                  OutlinedButton.icon(
                    onPressed: _printAsPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('PDF'),
                  ),
                  const SizedBox(width: 8),

                  // Send to Bluetooth / RawBT
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blueGrey.shade800,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _isExporting ? null : _sendToBluetoothPrinter,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.bluetooth_searching, size: 20),
                      label: const Text(
                        'Print (Bluetooth ESC/POS)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerforatedEdge() {
    return Container(
      height: 8,
      color: Colors.grey.shade100,
      child: Row(
        children: List.generate(
          40,
          (i) => Expanded(
            child: Container(
              color: i.isEven ? Colors.white : Colors.grey.shade300,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copyText() async {
    await Clipboard.setData(ClipboardData(text: _activeText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Slip text copied to clipboard (ready to paste in WhatsApp/SMS)')),
      );
    }
  }

  Future<void> _sendToBluetoothPrinter() async {
    setState(() => _isExporting = true);
    try {
      final file = await EscPosService.saveEscPosBinary(
        _activeBytes,
        prefix: widget.fileNamePrefix,
      );

      if (!mounted) return;
      setState(() => _isExporting = false);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/octet-stream')],
        subject: '${widget.title} - ESC/POS Raw Binary',
        text: 'Select your Bluetooth Thermal Printer app (e.g. RawBT, ESC POS Bluetooth Print, or POS-Printer).',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export ESC/POS binary: $e')),
      );
    }
  }

  Future<void> _printAsPdf() async {
    final text = _activeText;
    final title = widget.title;

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        final pdf = pw.Document();
        pdf.addPage(
          pw.Page(
            pageFormat: _selectedWidth == ThermalPaperWidth.mm58
                ? const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm)
                : const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 3 * PdfPageFormat.mm),
            build: (pw.Context ctx) => pw.Text(
              text,
              style: const pw.TextStyle(
                fontSize: 8.5,
                lineSpacing: 1.2,
              ),
            ),
          ),
        );
        return pdf.save();
      },
      name: '$title.pdf',
    );
  }
}
