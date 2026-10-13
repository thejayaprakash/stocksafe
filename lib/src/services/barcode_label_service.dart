import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

import '../data/database.dart';

enum BarcodeSymbology {
  code128('Code 128 (Standard Barcode)'),
  qrCode('QR Code (Compact 2D)');

  const BarcodeSymbology(this.label);
  final String label;
}

enum LabelSheetFormat {
  a4_24(
    name: 'A4 Sheet (24 Labels: 3 x 8)',
    columns: 3,
    rows: 8,
    labelsPerPage: 24,
    pageFormat: PdfPageFormat.a4,
    horizontalMarginMm: 7.0,
    verticalMarginMm: 12.0,
    labelWidthMm: 64.0,
    labelHeightMm: 33.9,
  ),
  a4_30(
    name: 'A4 Sheet (30 Labels: 3 x 10)',
    columns: 3,
    rows: 10,
    labelsPerPage: 30,
    pageFormat: PdfPageFormat.a4,
    horizontalMarginMm: 7.0,
    verticalMarginMm: 10.0,
    labelWidthMm: 64.0,
    labelHeightMm: 27.5,
  ),
  a4_40(
    name: 'A4 Sheet (40 Labels: 4 x 10)',
    columns: 4,
    rows: 10,
    labelsPerPage: 40,
    pageFormat: PdfPageFormat.a4,
    horizontalMarginMm: 6.0,
    verticalMarginMm: 10.0,
    labelWidthMm: 48.0,
    labelHeightMm: 27.5,
  ),
  thermal_50x25(
    name: 'Thermal Roll (50mm x 25mm)',
    columns: 1,
    rows: 1,
    labelsPerPage: 1,
    pageFormat: PdfPageFormat(50.0 * PdfPageFormat.mm, 25.0 * PdfPageFormat.mm),
    horizontalMarginMm: 1.5,
    verticalMarginMm: 1.5,
    labelWidthMm: 47.0,
    labelHeightMm: 22.0,
  ),
  thermal_50x30(
    name: 'Thermal Roll (50mm x 30mm)',
    columns: 1,
    rows: 1,
    labelsPerPage: 1,
    pageFormat: PdfPageFormat(50.0 * PdfPageFormat.mm, 30.0 * PdfPageFormat.mm),
    horizontalMarginMm: 1.5,
    verticalMarginMm: 1.5,
    labelWidthMm: 47.0,
    labelHeightMm: 27.0,
  );

  const LabelSheetFormat({
    required this.name,
    required this.columns,
    required this.rows,
    required this.labelsPerPage,
    required this.pageFormat,
    required this.horizontalMarginMm,
    required this.verticalMarginMm,
    required this.labelWidthMm,
    required this.labelHeightMm,
  });

  final String name;
  final int columns;
  final int rows;
  final int labelsPerPage;
  final PdfPageFormat pageFormat;
  final double horizontalMarginMm;
  final double verticalMarginMm;
  final double labelWidthMm;
  final double labelHeightMm;
}

/// Request configuration for printing barcode labels.
class BarcodeLabelConfig {
  final Product product;
  final int count;
  final LabelSheetFormat format;
  final BarcodeSymbology symbology;
  final String shopName;
  final String? batchNumber;
  final DateTime? packedDate;
  final DateTime? expiryDate;
  final bool showPrice;
  final bool showPackDate;
  final int startOffset; // Skip labels on a used sheet

  const BarcodeLabelConfig({
    required this.product,
    required this.count,
    this.format = LabelSheetFormat.a4_24,
    this.symbology = BarcodeSymbology.code128,
    this.shopName = 'STOCKSAFE',
    this.batchNumber,
    this.packedDate,
    this.expiryDate,
    this.showPrice = true,
    this.showPackDate = true,
    this.startOffset = 0,
  });
}

/// Barcode Label Printing Service.
/// Generates PDF sticker sheets and thermal label rolls with Code 128 / QR codes
/// for unbranded or loose items packaged in the retail shop (grains, pulses, snacks).
class BarcodeLabelService {
  /// Bundled Unicode font, loaded once and reused.
  ///
  /// The pdf package defaults to Helvetica and Courier, which carry no
  /// Unicode coverage — so a Tamil shop or product name printed as blank
  /// boxes, in an app that ships Tamil as a selling point. Noto Sans Tamil
  /// also covers Latin, so one font serves both languages and there is no
  /// script detection to get wrong.
  static pw.ThemeData? _theme;

  static Future<pw.ThemeData> unicodeTheme() async {
    if (_theme != null) return _theme!;
    final data = await rootBundle.load('assets/fonts/NotoSansTamil.ttf');
    final font = pw.Font.ttf(data);
    return _theme = pw.ThemeData.withFont(base: font, bold: font);
  }

  /// Clears the cached font. Tests only.
  @visibleForTesting
  static void resetFontCache() => _theme = null;

  /// Generate printable PDF sticker sheet bytes.
  static Future<Uint8List> generateLabelSheet(BarcodeLabelConfig config) async {
    final pdf = pw.Document(
      title: 'StockSafe Labels - ${config.product.name}',
      author: 'StockSafe',
      theme: await unicodeTheme(),
    );

    final totalSlotsNeeded = config.startOffset + config.count;
    final pagesNeeded = (totalSlotsNeeded / config.format.labelsPerPage).ceil();

    final barcodeData = _resolveBarcodeData(config.product);
    final dateFmt = DateFormat('dd/MM/yy');

    for (int pageIndex = 0; pageIndex < pagesNeeded; pageIndex++) {
      final startIndexForThisPage = pageIndex * config.format.labelsPerPage;

      pdf.addPage(
        pw.Page(
          pageFormat: config.format.pageFormat,
          margin: pw.EdgeInsets.symmetric(
            horizontal: config.format.horizontalMarginMm * PdfPageFormat.mm,
            vertical: config.format.verticalMarginMm * PdfPageFormat.mm,
          ),
          build: (pw.Context ctx) {
            final labelWidgets = <pw.Widget>[];

            for (int slot = 0; slot < config.format.labelsPerPage; slot++) {
              final absoluteSlot = startIndexForThisPage + slot;

              if (absoluteSlot < config.startOffset || absoluteSlot >= totalSlotsNeeded) {
                // Empty label slot (for skipped offset or trailing empty space)
                labelWidgets.add(pw.Container());
              } else {
                labelWidgets.add(
                  _buildSingleLabel(
                    config: config,
                    barcodeData: barcodeData,
                    dateFmt: dateFmt,
                  ),
                );
              }
            }

            if (config.format.columns == 1) {
              return labelWidgets.first;
            }

            return pw.GridView(
              crossAxisCount: config.format.columns,
              childAspectRatio: config.format.labelWidthMm / config.format.labelHeightMm,
              children: labelWidgets,
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// Builds a single label badge.
  static pw.Widget _buildSingleLabel({
    required BarcodeLabelConfig config,
    required String barcodeData,
    required DateFormat dateFmt,
  }) {
    final isThermal = config.format.columns == 1;
    final p = config.product;
    final effectivePackedDate = config.packedDate ?? DateTime.now();

    return pw.Container(
      margin: pw.EdgeInsets.all(1.0 * PdfPageFormat.mm),
      padding: pw.EdgeInsets.symmetric(
        horizontal: 2.0 * PdfPageFormat.mm,
        vertical: 1.5 * PdfPageFormat.mm,
      ),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: pw.BorderRadius.circular(2.0),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Header: Shop Name & Pack size
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                config.shopName.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: isThermal ? 6.5 : 7.0,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                p.unit,
                style: pw.TextStyle(
                  fontSize: isThermal ? 6.5 : 7.0,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),

          // Product Name
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
            child: pw.Text(
              p.name,
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: isThermal ? 8.5 : 9.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),

          // Barcode or QR Code
          pw.Expanded(
            child: pw.Center(
              child: config.symbology == BarcodeSymbology.qrCode
                  ? pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: barcodeData,
                      // BarcodeWidget renders its caption in Courier, which
                      // has no Unicode coverage. A QR's caption is illegible
                      // at 16 mm anyway, and Code 128 already prints the
                      // number separately below.
                      drawText: false,
                      width: isThermal ? 16 * PdfPageFormat.mm : 20 * PdfPageFormat.mm,
                      height: isThermal ? 16 * PdfPageFormat.mm : 20 * PdfPageFormat.mm,
                    )
                  : pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(),
                      data: barcodeData,
                      drawText: false,
                      height: isThermal ? 9 * PdfPageFormat.mm : 11 * PdfPageFormat.mm,
                      width: double.infinity,
                    ),
            ),
          ),

          // Human Readable Barcode Number (if Code 128)
          if (config.symbology == BarcodeSymbology.code128)
            pw.Text(
              barcodeData,
              style: const pw.TextStyle(
                fontSize: 6.0,
                color: PdfColors.grey800,
              ),
            ),

          // Footer: Price & Packed Date / Expiry
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (config.showPackDate)
                pw.Text(
                  'Pkd: ${dateFmt.format(effectivePackedDate)}'
                  '${config.expiryDate != null ? "\nExp: ${dateFmt.format(config.expiryDate!)}" : ""}',
                  style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey700),
                )
              else
                pw.SizedBox(),

              if (config.showPrice && p.sellPrice > 0)
                pw.Text(
                  'MRP: Rs ${p.sellPrice.toStringAsFixed(p.sellPrice == p.sellPrice.roundToDouble() ? 0 : 2)}',
                  style: pw.TextStyle(
                    fontSize: isThermal ? 8.0 : 9.0,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                )
              else
                pw.SizedBox(),
            ],
          ),
        ],
      ),
    );
  }

  /// Resolves the barcode string.
  /// If the product has a barcode recorded, uses it.
  /// Otherwise, auto-generates a clean internal Code 128 / SKU: e.g. "SK-00042".
  static String _resolveBarcodeData(Product product) {
    if (product.barcode != null && product.barcode!.trim().isNotEmpty) {
      return product.barcode!.trim();
    }
    if (product.sku != null && product.sku!.trim().isNotEmpty) {
      return product.sku!.trim();
    }
    // Auto-generate internal shop SKU code for loose unbranded item
    return 'SK-${product.id.toString().padLeft(5, '0')}';
  }
}
