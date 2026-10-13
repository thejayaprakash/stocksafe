import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/database.dart';

enum ThermalPaperWidth {
  mm58(32, '58mm (32 chars)'),
  mm80(48, '80mm (48 chars)');

  const ThermalPaperWidth(this.charactersPerLine, this.label);
  final int charactersPerLine;
  final String label;
}

/// ESC/POS Thermal Receipt & Slip Generator.
/// Generates standard ESC/POS bytecode streams for 58mm and 80mm
/// Bluetooth thermal receipt printers used in retail Kirana shops.
///
/// Also provides formatted plain-text receipts for visual preview
/// and WhatsApp/SMS transmission.
class EscPosService {
  // ─── Vendor branding ──────────────────────────────────────────────
  //
  // The lines that mark a slip as produced by StockSafe. Removing them is
  // what the paid tier buys - see [brandingLines] and the `proUnlocked`
  // parameter on each build method.
  //
  // Deliberately not gated behind the shop name: a receipt headed with the
  // shop's own name is what makes it a receipt, and a free tier that prints
  // "STOCKSAFE" where the shop's name belongs is not reduced, it is broken.
  // A shopkeeper would simply stop printing. The vendor mark is the thing
  // worth paying to remove, and while it is there it is also the only
  // distribution this app has.

  /// Footer on the audit discrepancy slip.
  static const String brandingAudit = 'Powered by StockSafe Enterprise';

  /// Footer on the delivery / stock inward slip.
  ///
  /// Was 'StockSafe · Offline Inventory Management' - 40 characters, which
  /// [_center] clips to the paper width. On 58mm rolls, the default and the
  /// common one for a kirana, it printed as 'StockSafe · Offline Inventory Ma'
  /// on a slip handed to a supplier. Every mark now fits the narrowest paper,
  /// which `a vendor mark fits the narrowest paper` pins.
  static const String brandingDelivery = 'StockSafe · Offline Inventory';

  /// Footer on the low-stock reorder slip.
  static const String brandingReorder = 'StockSafe Enterprise';

  /// Every vendor mark, for tests that assert a Pro slip carries none of them.
  static const List<String> brandingLines = [
    brandingAudit,
    brandingDelivery,
    brandingReorder,
  ];

  // ESC/POS Command Constants
  static const int _esc = 0x1B;
  static const int _gs = 0x1D;

  static const List<int> cmdInit = [_esc, 0x40]; // ESC @
  static const List<int> cmdAlignLeft = [_esc, 0x61, 0x00]; // ESC a 0
  static const List<int> cmdAlignCenter = [_esc, 0x61, 0x01]; // ESC a 1
  static const List<int> cmdAlignRight = [_esc, 0x61, 0x02]; // ESC a 2
  static const List<int> cmdBoldOn = [_esc, 0x45, 0x01]; // ESC E 1
  static const List<int> cmdBoldOff = [_esc, 0x45, 0x00]; // ESC E 0
  static const List<int> cmdTextNormal = [_gs, 0x21, 0x00]; // GS ! 0
  static const List<int> cmdTextDoubleHeight = [_gs, 0x21, 0x01]; // GS ! 1
  static const List<int> cmdTextDoubleWidth = [_gs, 0x21, 0x10]; // GS ! 16
  static const List<int> cmdTextDoubleBoth = [_gs, 0x21, 0x11]; // GS ! 17
  static const List<int> cmdUnderlineOn = [_esc, 0x2D, 0x01]; // ESC - 1
  static const List<int> cmdUnderlineOff = [_esc, 0x2D, 0x00]; // ESC - 0
  static const List<int> cmdCut = [_gs, 0x56, 0x00]; // GS V 0 (full cut)
  static const List<int> cmdPartialCut = [_gs, 0x56, 0x01]; // GS V 1

  static List<int> cmdFeed(int lines) => [_esc, 0x64, lines]; // ESC d n

  // ──────────────────────────────────────────────────────────────────
  // 1. Physical Stock Audit Discrepancy Slip
  // ──────────────────────────────────────────────────────────────────

  /// Generates ESC/POS bytecode for physical stock audit discrepancy sheets.
  static Uint8List buildAuditDiscrepancySlipBytes({
    bool proUnlocked = false,
    required StockAuditSession session,
    required List<StockAuditItemWithProduct> items,
    required String shopName,
    ThermalPaperWidth paperWidth = ThermalPaperWidth.mm58,
  }) {
    final builder = BytesBuilder();
    final width = paperWidth.charactersPerLine;
    final dateFmt = DateFormat('dd-MM-yyyy hh:mm a');

    int matchedCount = 0;
    int discrepancyCount = 0;
    int netDiscrepancyUnits = 0;
    double netDiscrepancyValue = 0.0;

    for (final it in items) {
      if (it.item.difference == 0) {
        matchedCount++;
      } else {
        discrepancyCount++;
        netDiscrepancyUnits += it.item.difference;
        netDiscrepancyValue += it.item.difference * (it.product?.buyPrice ?? 0.0);
      }
    }

    // 1. Initialize
    builder.add(cmdInit);

    // 2. Header
    builder.add(cmdAlignCenter);
    builder.add(cmdTextDoubleBoth);
    builder.add(cmdBoldOn);
    builder.add(_encode(shopName.isEmpty ? 'STOCKSAFE' : shopName.toUpperCase()));
    builder.add([0x0A]);
    builder.add(cmdTextNormal);
    builder.add(cmdBoldOff);

    builder.add(_encode('PHYSICAL AUDIT DISCREPANCY'));
    builder.add([0x0A]);
    builder.add(_encode(dateFmt.format(DateTime.now())));
    builder.add([0x0A]);

    builder.add(cmdAlignLeft);
    builder.add(_encode(_divider(width, '=')));
    builder.add([0x0A]);

    builder.add(_encode(_twoCols('Session:', session.name, width)));
    builder.add([0x0A]);
    builder.add(_encode(_twoCols('Audit Mode:', session.auditMode.toUpperCase(), width)));
    builder.add([0x0A]);
    builder.add(_encode(_twoCols('Status:', session.status.toUpperCase(), width)));
    builder.add([0x0A]);

    builder.add(_encode(_divider(width, '-')));
    builder.add([0x0A]);

    // 3. Stats Summary
    builder.add(cmdBoldOn);
    builder.add(_encode('AUDIT SUMMARY:'));
    builder.add([0x0A]);
    builder.add(cmdBoldOff);

    builder.add(_encode(_twoCols('Total Counted:', '${items.length} items', width)));
    builder.add([0x0A]);
    builder.add(_encode(_twoCols('Matched Count:', '$matchedCount items', width)));
    builder.add([0x0A]);

    builder.add(cmdBoldOn);
    builder.add(_encode(_twoCols('Discrepancies:', '$discrepancyCount items', width)));
    builder.add([0x0A]);
    builder.add(_encode(_twoCols(
      'Net Unit Diff:',
      '${netDiscrepancyUnits >= 0 ? "+" : ""}$netDiscrepancyUnits units',
      width,
    )));
    builder.add([0x0A]);
    builder.add(_encode(_twoCols(
      'Shrinkage/Gain Value:',
      'Rs ${netDiscrepancyValue.toStringAsFixed(2)}',
      width,
    )));
    builder.add([0x0A]);
    builder.add(cmdBoldOff);

    builder.add(_encode(_divider(width, '-')));
    builder.add([0x0A]);

    // 4. Discrepancy Breakdown Table
    builder.add(cmdBoldOn);
    builder.add(_encode('DISCREPANCY DETAILS:'));
    builder.add([0x0A]);
    builder.add(cmdBoldOff);

    final discrepancyItems = items.where((i) => i.item.difference != 0).toList();

    if (discrepancyItems.isEmpty) {
      builder.add(cmdAlignCenter);
      builder.add(_encode('*** NO DISCREPANCIES FOUND ***'));
      builder.add([0x0A]);
      builder.add(_encode('Physical stock matches system 100%'));
      builder.add([0x0A]);
      builder.add(cmdAlignLeft);
    } else {
      for (final di in discrepancyItems) {
        final prod = di.product;
        final name = prod?.name ?? 'Item #${di.item.productId}';
        final diffStr = di.item.difference > 0 ? '+${di.item.difference}' : '${di.item.difference}';
        final unit = prod?.unit ?? 'pcs';
        final val = di.item.difference * (prod?.buyPrice ?? 0.0);

        if (paperWidth == ThermalPaperWidth.mm58) {
          // 58mm compact 2-line layout
          builder.add(cmdBoldOn);
          builder.add(_encode(_truncate(name, width)));
          builder.add([0x0A]);
          builder.add(cmdBoldOff);

          final l2 = 'Sys:${di.item.expectedQty} Cnt:${di.item.countedQty} Diff:$diffStr $unit';
          builder.add(_encode(_truncate(l2, width)));
          builder.add([0x0A]);
          if (val != 0.0) {
            builder.add(_encode(_twoCols('Val Impact:', 'Rs ${val.toStringAsFixed(2)}', width)));
            builder.add([0x0A]);
          }
        } else {
          // 80mm table layout
          builder.add(cmdBoldOn);
          builder.add(_encode(_truncate(name, width)));
          builder.add([0x0A]);
          builder.add(cmdBoldOff);

          final row = _threeCols(
            'Sys: ${di.item.expectedQty}',
            'Physical: ${di.item.countedQty}',
            'Diff: $diffStr (Rs ${val.toStringAsFixed(0)})',
            width,
          );
          builder.add(_encode(row));
          builder.add([0x0A]);
        }
        builder.add(_encode(_divider(width, '.')));
        builder.add([0x0A]);
      }
    }

    // 5. Signatures
    builder.add([0x0A]);
    builder.add(_encode(_twoCols('Audited by:', 'Store Manager:', width)));
    builder.add([0x0A]);
    builder.add([0x0A]);
    builder.add(_encode(_twoCols('_______________', '_______________', width)));
    builder.add([0x0A]);

    // 6. Footer
    builder.add(cmdAlignCenter);
    builder.add([0x0A]);
    if (!proUnlocked) {
      builder.add(_encode(brandingAudit));
      builder.add([0x0A]);
    }
    builder.add(_encode('Data Sovereignty & Ledger Verified'));
    builder.add([0x0A]);

    // Feed lines & cut
    builder.add(cmdFeed(4));
    builder.add(cmdCut);

    return builder.toBytes();
  }

  /// Formatted plain text for on-screen preview or WhatsApp text sharing.
  static String buildAuditDiscrepancyText({
    bool proUnlocked = false,
    required StockAuditSession session,
    required List<StockAuditItemWithProduct> items,
    required String shopName,
    ThermalPaperWidth paperWidth = ThermalPaperWidth.mm58,
  }) {
    final width = paperWidth.charactersPerLine;
    final dateFmt = DateFormat('dd-MM-yyyy hh:mm a');
    final buffer = StringBuffer();

    int matchedCount = 0;
    int discrepancyCount = 0;
    int netDiscrepancyUnits = 0;
    double netDiscrepancyValue = 0.0;

    for (final it in items) {
      if (it.item.difference == 0) {
        matchedCount++;
      } else {
        discrepancyCount++;
        netDiscrepancyUnits += it.item.difference;
        netDiscrepancyValue += it.item.difference * (it.product?.buyPrice ?? 0.0);
      }
    }

    buffer.writeln(_center(shopName.isEmpty ? 'STOCKSAFE' : shopName.toUpperCase(), width));
    buffer.writeln(_center('PHYSICAL AUDIT DISCREPANCY', width));
    buffer.writeln(_center(dateFmt.format(DateTime.now()), width));
    buffer.writeln(_divider(width, '='));

    buffer.writeln(_twoCols('Session:', session.name, width));
    buffer.writeln(_twoCols('Audit Mode:', session.auditMode.toUpperCase(), width));
    buffer.writeln(_twoCols('Status:', session.status.toUpperCase(), width));
    buffer.writeln(_divider(width, '-'));

    buffer.writeln('AUDIT SUMMARY:');
    buffer.writeln(_twoCols('Total Counted:', '${items.length} items', width));
    buffer.writeln(_twoCols('Matched Count:', '$matchedCount items', width));
    buffer.writeln(_twoCols('Discrepancies:', '$discrepancyCount items', width));
    buffer.writeln(_twoCols(
      'Net Unit Diff:',
      '${netDiscrepancyUnits >= 0 ? "+" : ""}$netDiscrepancyUnits units',
      width,
    ));
    buffer.writeln(_twoCols(
      'Shrinkage/Gain Value:',
      'Rs ${netDiscrepancyValue.toStringAsFixed(2)}',
      width,
    ));
    buffer.writeln(_divider(width, '-'));

    buffer.writeln('DISCREPANCY DETAILS:');
    final discrepancyItems = items.where((i) => i.item.difference != 0).toList();

    if (discrepancyItems.isEmpty) {
      buffer.writeln(_center('*** NO DISCREPANCIES FOUND ***', width));
      buffer.writeln(_center('Physical stock matches system 100%', width));
    } else {
      for (final di in discrepancyItems) {
        final prod = di.product;
        final name = prod?.name ?? 'Item #${di.item.productId}';
        final diffStr = di.item.difference > 0 ? '+${di.item.difference}' : '${di.item.difference}';
        final unit = prod?.unit ?? 'pcs';
        final val = di.item.difference * (prod?.buyPrice ?? 0.0);

        buffer.writeln(_truncate(name, width));
        final l2 = 'Sys:${di.item.expectedQty} Cnt:${di.item.countedQty} Diff:$diffStr $unit';
        buffer.writeln(_truncate(l2, width));
        if (val != 0.0) {
          buffer.writeln(_twoCols('Val Impact:', 'Rs ${val.toStringAsFixed(2)}', width));
        }
        buffer.writeln(_divider(width, '.'));
      }
    }

    buffer.writeln();
    buffer.writeln(_twoCols('Audited by:', 'Store Manager:', width));
    buffer.writeln();
    buffer.writeln(_twoCols('_______________', '_______________', width));
    buffer.writeln();
    if (!proUnlocked) buffer.writeln(_center(brandingAudit, width));

    return buffer.toString();
  }

  // ──────────────────────────────────────────────────────────────────
  // 2. Delivery / Stock Inward Slip
  // ──────────────────────────────────────────────────────────────────

  /// Generates ESC/POS bytecode for Delivery Slips (Stock In / Inward).
  static Uint8List buildDeliverySlipBytes({
    bool proUnlocked = false,
    required Product product,
    required int quantity,
    required String reason,
    Supplier? supplier,
    String? batchNumber,
    DateTime? expiryDate,
    String? note,
    required String shopName,
    ThermalPaperWidth paperWidth = ThermalPaperWidth.mm58,
  }) {
    final builder = BytesBuilder();
    final width = paperWidth.charactersPerLine;
    final dateFmt = DateFormat('dd-MM-yyyy hh:mm a');
    final expFmt = DateFormat('dd-MMM-yyyy');

    builder.add(cmdInit);

    // Header
    builder.add(cmdAlignCenter);
    builder.add(cmdTextDoubleBoth);
    builder.add(cmdBoldOn);
    builder.add(_encode(shopName.isEmpty ? 'STOCKSAFE' : shopName.toUpperCase()));
    builder.add([0x0A]);
    builder.add(cmdTextNormal);
    builder.add(cmdBoldOff);

    builder.add(_encode('STOCK DELIVERY / INWARD SLIP'));
    builder.add([0x0A]);
    builder.add(_encode(dateFmt.format(DateTime.now())));
    builder.add([0x0A]);

    builder.add(cmdAlignLeft);
    builder.add(_encode(_divider(width, '=')));
    builder.add([0x0A]);

    if (supplier != null) {
      builder.add(cmdBoldOn);
      builder.add(_encode('SUPPLIER / VENDOR DETAILS:'));
      builder.add([0x0A]);
      builder.add(cmdBoldOff);
      builder.add(_encode(_twoCols('Name:', supplier.name, width)));
      builder.add([0x0A]);
      builder.add(_encode(_twoCols('Phone:', supplier.phone, width)));
      builder.add([0x0A]);
      if (supplier.gstin != null && supplier.gstin!.isNotEmpty) {
        builder.add(_encode(_twoCols('GSTIN:', supplier.gstin!, width)));
        builder.add([0x0A]);
      }
      builder.add(_encode(_divider(width, '-')));
      builder.add([0x0A]);
    }

    // Product Section
    builder.add(cmdBoldOn);
    builder.add(_encode('PRODUCT DETAILS:'));
    builder.add([0x0A]);
    builder.add(cmdBoldOff);

    builder.add(_encode(_twoCols('Item:', product.name, width)));
    builder.add([0x0A]);
    if (product.category != null) {
      builder.add(_encode(_twoCols('Category:', product.category!, width)));
      builder.add([0x0A]);
    }
    if (product.barcode != null) {
      builder.add(_encode(_twoCols('Barcode:', product.barcode!, width)));
      builder.add([0x0A]);
    }

    builder.add(cmdBoldOn);
    builder.add(_encode(_twoCols('Quantity In:', '+$quantity ${product.unit}', width)));
    builder.add([0x0A]);
    builder.add(cmdBoldOff);

    if (product.buyPrice > 0) {
      final subtotal = quantity * product.buyPrice;
      builder.add(_encode(_twoCols('Cost Rate:', 'Rs ${product.buyPrice.toStringAsFixed(2)}', width)));
      builder.add([0x0A]);
      builder.add(cmdBoldOn);
      builder.add(_encode(_twoCols('Total Cost:', 'Rs ${subtotal.toStringAsFixed(2)}', width)));
      builder.add([0x0A]);
      builder.add(cmdBoldOff);
    }

    if (batchNumber != null && batchNumber.isNotEmpty) {
      builder.add(_encode(_twoCols('Batch No:', '#$batchNumber', width)));
      builder.add([0x0A]);
    }
    if (expiryDate != null) {
      builder.add(_encode(_twoCols('Expiry Date:', expFmt.format(expiryDate), width)));
      builder.add([0x0A]);
    }

    if (note != null && note.isNotEmpty) {
      builder.add(_encode(_twoCols('Note:', note, width)));
      builder.add([0x0A]);
    }

    builder.add(_encode(_twoCols('New Stock Balance:', '${product.stockQty + quantity} ${product.unit}', width)));
    builder.add([0x0A]);

    builder.add(_encode(_divider(width, '-')));
    builder.add([0x0A]);

    // Signatures
    builder.add([0x0A]);
    builder.add(_encode(_twoCols('Received By:', 'Supplier Sign:', width)));
    builder.add([0x0A]);
    builder.add([0x0A]);
    builder.add(_encode(_twoCols('_______________', '_______________', width)));
    builder.add([0x0A]);

    // Footer
    builder.add(cmdAlignCenter);
    builder.add([0x0A]);
    if (!proUnlocked) {
      builder.add(_encode(brandingDelivery));
      builder.add([0x0A]);
    }

    builder.add(cmdFeed(4));
    builder.add(cmdCut);

    return builder.toBytes();
  }

  /// Formatted plain text for Delivery Slip.
  static String buildDeliverySlipText({
    bool proUnlocked = false,
    required Product product,
    required int quantity,
    required String reason,
    Supplier? supplier,
    String? batchNumber,
    DateTime? expiryDate,
    String? note,
    required String shopName,
    ThermalPaperWidth paperWidth = ThermalPaperWidth.mm58,
  }) {
    final width = paperWidth.charactersPerLine;
    final dateFmt = DateFormat('dd-MM-yyyy hh:mm a');
    final expFmt = DateFormat('dd-MMM-yyyy');
    final buffer = StringBuffer();

    buffer.writeln(_center(shopName.isEmpty ? 'STOCKSAFE' : shopName.toUpperCase(), width));
    buffer.writeln(_center('STOCK DELIVERY / INWARD SLIP', width));
    buffer.writeln(_center(dateFmt.format(DateTime.now()), width));
    buffer.writeln(_divider(width, '='));

    if (supplier != null) {
      buffer.writeln('SUPPLIER / VENDOR DETAILS:');
      buffer.writeln(_twoCols('Name:', supplier.name, width));
      buffer.writeln(_twoCols('Phone:', supplier.phone, width));
      if (supplier.gstin != null && supplier.gstin!.isNotEmpty) {
        buffer.writeln(_twoCols('GSTIN:', supplier.gstin!, width));
      }
      buffer.writeln(_divider(width, '-'));
    }

    buffer.writeln('PRODUCT DETAILS:');
    buffer.writeln(_twoCols('Item:', product.name, width));
    if (product.category != null) {
      buffer.writeln(_twoCols('Category:', product.category!, width));
    }
    buffer.writeln(_twoCols('Quantity In:', '+$quantity ${product.unit}', width));

    if (product.buyPrice > 0) {
      final subtotal = quantity * product.buyPrice;
      buffer.writeln(_twoCols('Cost Rate:', 'Rs ${product.buyPrice.toStringAsFixed(2)}', width));
      buffer.writeln(_twoCols('Total Cost:', 'Rs ${subtotal.toStringAsFixed(2)}', width));
    }

    if (batchNumber != null && batchNumber.isNotEmpty) {
      buffer.writeln(_twoCols('Batch No:', '#$batchNumber', width));
    }
    if (expiryDate != null) {
      buffer.writeln(_twoCols('Expiry Date:', expFmt.format(expiryDate), width));
    }

    if (note != null && note.isNotEmpty) {
      buffer.writeln(_twoCols('Note:', note, width));
    }
    buffer.writeln(_twoCols('New Balance:', '${product.stockQty + quantity} ${product.unit}', width));
    buffer.writeln(_divider(width, '-'));

    buffer.writeln();
    buffer.writeln(_twoCols('Received By:', 'Supplier Sign:', width));
    buffer.writeln();
    buffer.writeln(_twoCols('_______________', '_______________', width));
    buffer.writeln();
    if (!proUnlocked) buffer.writeln(_center(brandingDelivery, width));

    return buffer.toString();
  }

  // ──────────────────────────────────────────────────────────────────
  // 3. Low-Stock Reorder Purchase Slip
  // ──────────────────────────────────────────────────────────────────

  /// Generates ESC/POS bytecode for Low-Stock Reorder Slips.
  static Uint8List buildLowStockReorderSlipBytes({
    bool proUnlocked = false,
    required List<LowStockSlipEntry> entries,
    required String shopName,
    ThermalPaperWidth paperWidth = ThermalPaperWidth.mm58,
  }) {
    final builder = BytesBuilder();
    final width = paperWidth.charactersPerLine;
    final dateFmt = DateFormat('dd-MM-yyyy hh:mm a');

    builder.add(cmdInit);

    // Header
    builder.add(cmdAlignCenter);
    builder.add(cmdTextDoubleBoth);
    builder.add(cmdBoldOn);
    builder.add(_encode(shopName.isEmpty ? 'STOCKSAFE' : shopName.toUpperCase()));
    builder.add([0x0A]);
    builder.add(cmdTextNormal);
    builder.add(cmdBoldOff);

    builder.add(_encode('LOW STOCK PURCHASE ORDER SLIP'));
    builder.add([0x0A]);
    builder.add(_encode(dateFmt.format(DateTime.now())));
    builder.add([0x0A]);

    builder.add(cmdAlignLeft);
    builder.add(_encode(_divider(width, '=')));
    builder.add([0x0A]);

    builder.add(cmdBoldOn);
    builder.add(_encode(_twoCols('Total Items to Order:', '${entries.length} items', width)));
    builder.add([0x0A]);
    builder.add(cmdBoldOff);
    builder.add(_encode(_divider(width, '-')));
    builder.add([0x0A]);

    for (int i = 0; i < entries.length; i++) {
      final e = entries[i];
      builder.add(cmdBoldOn);
      builder.add(_encode('${i + 1}. ${_truncate(e.product.name, width - 4)}'));
      builder.add([0x0A]);
      builder.add(cmdBoldOff);

      final l2 = 'Stock:${e.product.stockQty} Min:${e.product.lowStockLevel} -> ORDER: +${e.suggestedOrderQty}';
      builder.add(_encode(_truncate(l2, width)));
      builder.add([0x0A]);

      if (e.supplier != null) {
        builder.add(_encode(_truncate('Vendor: ${e.supplier!.name}', width)));
        builder.add([0x0A]);
        builder.add(_encode(_truncate('Contact: ${e.supplier!.phone}', width)));
        builder.add([0x0A]);
      }
      builder.add(_encode(_divider(width, '.')));
      builder.add([0x0A]);
    }

    builder.add([0x0A]);
    builder.add(cmdAlignCenter);
    builder.add(_encode('Take to wholesale market / Hand to supplier'));
    builder.add([0x0A]);
    if (!proUnlocked) {
      builder.add(_encode(brandingReorder));
      builder.add([0x0A]);
    }

    builder.add(cmdFeed(4));
    builder.add(cmdCut);

    return builder.toBytes();
  }

  /// Formatted plain text for Low-Stock Reorder Slip.
  static String buildLowStockReorderText({
    bool proUnlocked = false,
    required List<LowStockSlipEntry> entries,
    required String shopName,
    ThermalPaperWidth paperWidth = ThermalPaperWidth.mm58,
  }) {
    final width = paperWidth.charactersPerLine;
    final dateFmt = DateFormat('dd-MM-yyyy hh:mm a');
    final buffer = StringBuffer();

    buffer.writeln(_center(shopName.isEmpty ? 'STOCKSAFE' : shopName.toUpperCase(), width));
    buffer.writeln(_center('LOW STOCK PURCHASE ORDER SLIP', width));
    buffer.writeln(_center(dateFmt.format(DateTime.now()), width));
    buffer.writeln(_divider(width, '='));

    buffer.writeln(_twoCols('Items to Order:', '${entries.length} items', width));
    buffer.writeln(_divider(width, '-'));

    for (int i = 0; i < entries.length; i++) {
      final e = entries[i];
      buffer.writeln('${i + 1}. ${_truncate(e.product.name, width - 4)}');
      final l2 = 'Stock:${e.product.stockQty} Min:${e.product.lowStockLevel} -> ORDER: +${e.suggestedOrderQty}';
      buffer.writeln(_truncate(l2, width));
      if (e.supplier != null) {
        buffer.writeln(_truncate('Vendor: ${e.supplier!.name}', width));
        buffer.writeln(_truncate('Contact: ${e.supplier!.phone}', width));
      }
      buffer.writeln(_divider(width, '.'));
    }

    buffer.writeln();
    buffer.writeln(_center('Take to wholesale market / Hand to supplier', width));
    if (!proUnlocked) buffer.writeln(_center(brandingReorder, width));

    return buffer.toString();
  }

  // ──────────────────────────────────────────────────────────────────
  // File Persister for RawBT / Bluetooth Printer Sharing
  // ──────────────────────────────────────────────────────────────────

  /// Writes ESC/POS bytes into a temporary `.bin` file and returns the File handle.
  static Future<File> saveEscPosBinary(Uint8List bytes, {String prefix = 'receipt'}) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File(p.join(tempDir.path, '${prefix}_$timestamp.bin'));
    await file.writeAsBytes(bytes);
    return file;
  }

  // ──────────────────────────────────────────────────────────────────
  // Text Formatting Helpers
  // ──────────────────────────────────────────────────────────────────

  static List<int> _encode(String s) => latin1.encode(s);

  static String _divider(int width, String char) => char * width;

  static String _center(String text, int width) {
    if (text.length >= width) return text.substring(0, width);
    final totalPad = width - text.length;
    final leftPad = totalPad ~/ 2;
    return ' ' * leftPad + text;
  }

  static String _truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return text.substring(0, maxLen);
  }

  static String _twoCols(String left, String right, int width) {
    final maxLeft = width - right.length - 1;
    final truncatedLeft = left.length > maxLeft ? left.substring(0, maxLeft) : left;
    final spaces = width - truncatedLeft.length - right.length;
    return '$truncatedLeft${' ' * (spaces > 0 ? spaces : 1)}$right';
  }

  static String _threeCols(String c1, String c2, String c3, int width) {
    final target = width ~/ 3;
    final part1 = c1.padRight(target);
    final part2 = c2.padRight(target);
    final part3 = c3;
    final line = '$part1$part2$part3';
    return line.length > width ? line.substring(0, width) : line;
  }
}

/// Helper model binding StockAuditItem with its Product.
class StockAuditItemWithProduct {
  final StockAuditItem item;
  final Product? product;

  StockAuditItemWithProduct({required this.item, this.product});
}

/// Helper model for Low Stock slip item.
class LowStockSlipEntry {
  final Product product;
  final int suggestedOrderQty;
  final Supplier? supplier;

  LowStockSlipEntry({
    required this.product,
    required this.suggestedOrderQty,
    this.supplier,
  });
}
