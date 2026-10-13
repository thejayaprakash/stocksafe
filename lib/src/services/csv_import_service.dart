import 'package:csv/csv.dart';
import 'package:drift/drift.dart';

import '../data/database.dart';
import 'license_service.dart';

/// Result summary of an import operation.
class CsvImportResult {
  const CsvImportResult({
    required this.totalRows,
    required this.importedCount,
    required this.skippedCount,
    required this.errors,
  });

  final int totalRows;
  final int importedCount;
  final int skippedCount;
  final List<String> errors;

  bool get hasErrors => errors.isNotEmpty;
}

/// Robust, streaming CSV Catalog Importer for retail inventories.
///
/// Features:
/// - Flexible header mapping (tolerates variations like "Product Name", "Cost Price", "MRP")
/// - Row-by-row validation with actionable error reporting
/// - Preserves immutable ledger integrity: items with initial stock generate
///   an auditable 'opening_stock' movement transaction.
/// - Atomic database transaction: failures roll back cleanly.
class CsvImportService {
  CsvImportService(this._db);

  final AppDatabase _db;

  /// Parse and import products from raw CSV string.
  Future<CsvImportResult> importFromCsvString(String csvContent) async {
    final trimmedContent = csvContent.trim();
    if (trimmedContent.isEmpty) {
      return const CsvImportResult(
        totalRows: 0,
        importedCount: 0,
        skippedCount: 0,
        errors: ['CSV file is empty.'],
      );
    }

    final normalizedContent = trimmedContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    final rows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
      allowInvalid: true,
    ).convert(normalizedContent);

    rows.removeWhere((r) => r.isEmpty || r.every((c) => c.toString().trim().isEmpty));

    if (rows.isEmpty) {
      return const CsvImportResult(
        totalRows: 0,
        importedCount: 0,
        skippedCount: 0,
        errors: ['CSV file is empty.'],
      );
    }

    final headers = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
    final colMap = _resolveHeaderMap(headers);

    if (colMap['name'] == null) {
      return const CsvImportResult(
        totalRows: 0,
        importedCount: 0,
        skippedCount: 0,
        errors: ['Could not find a "Name" or "Product Name" column in the header row.'],
      );
    }

    final dataRows = rows.sublist(1);
    final errors = <String>[];
    int imported = 0;
    int skipped = 0;

    final license = LicenseService(_db);
    final isPro = await license.isProUnlocked();
    final currentCount = await _db.productDao.countActive();
    final freeLimit = await license.getFreeLimit();
    final availableQuota = isPro ? 999999 : (freeLimit - currentCount).clamp(0, freeLimit);

    // Barcodes already claimed by rows accepted earlier in this same file.
    final seenBarcodes = <String>{};

    await _db.transaction(() async {
      final now = DateTime.now();

      for (int i = 0; i < dataRows.length; i++) {
        final row = dataRows[i];
        final rowNum = i + 2; // 1-indexed, accounting for header

        if (!isPro && imported >= availableQuota) {
          errors.add(
            'Free tier limit reached ($freeLimit products). '
            'Remaining ${dataRows.length - i} rows skipped. Upgrade to StockSafe Pro for unlimited imports.',
          );
          skipped += dataRows.length - i;
          break;
        }

        if (row.isEmpty || row.every((c) => c.toString().trim().isEmpty)) {
          skipped++;
          continue;
        }

        final name = _getString(row, colMap['name']);
        if (name.isEmpty) {
          errors.add('Row $rowNum: Product name is empty.');
          skipped++;
          continue;
        }

        final sku = _getString(row, colMap['sku']);
        final barcode = _getString(row, colMap['barcode']);
        final category = _getString(row, colMap['category']);
        final unit = _getString(row, colMap['unit'], defaultValue: 'pcs');
        final buyPrice = _getDouble(row, colMap['buy_price']);
        final sellPrice = _getDouble(row, colMap['sell_price']);
        final lowStock = _getInt(row, colMap['low_stock']);
        final initialStock = _getInt(row, colMap['initial_stock']);

        // A barcode identifies one product. The previous version reported the
        // duplicate and then inserted it anyway, so importing the same
        // supplier file twice produced two rows sharing a code; scanning then
        // resolved to an arbitrary one and stock landed on the wrong product.
        // There is now a unique index on live barcodes, so inserting would
        // abort the whole transaction and lose the good rows with the bad.
        if (barcode.isNotEmpty) {
          if (!seenBarcodes.add(barcode)) {
            errors.add('Row $rowNum: barcode "$barcode" is repeated '
                'earlier in this file — row skipped.');
            skipped++;
            continue;
          }
          final existing = await _db.productDao.getByBarcode(barcode);
          if (existing != null) {
            errors.add('Row $rowNum: barcode "$barcode" already belongs to '
                '"${existing.name}" — row skipped.');
            skipped++;
            continue;
          }
        }

        // Insert product
        final prodId = await _db.productDao.insertProduct(
          ProductsCompanion.insert(
            name: name,
            sku: Value(sku.isEmpty ? null : sku),
            barcode: Value(barcode.isEmpty ? null : barcode),
            category: Value(category.isEmpty ? null : category),
            unit: Value(unit),
            buyPrice: Value(buyPrice),
            sellPrice: Value(sellPrice),
            lowStockLevel: Value(lowStock),
            stockQty: Value(initialStock),
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Record opening stock in immutable movement ledger if quantity > 0
        if (initialStock != 0) {
          await _db.movementDao.recordMovement(
            productId: prodId,
            qtyDelta: initialStock,
            reason: 'opening_stock',
            note: 'Imported via CSV',
            createdAt: now,
          );
        }

        imported++;
      }
    });

    return CsvImportResult(
      totalRows: dataRows.length,
      importedCount: imported,
      skippedCount: skipped,
      errors: errors,
    );
  }

  static Map<String, int?> _resolveHeaderMap(List<String> headers) {
    int? findIndex(List<String> synonyms) {
      for (int i = 0; i < headers.length; i++) {
        final h = headers[i].toLowerCase().replaceAll(RegExp(r'[\s_]+'), ' ');
        for (final s in synonyms) {
          if (h == s || h.contains(s)) return i;
        }
      }
      return null;
    }

    return {
      'name': findIndex(['product name', 'item name', 'name', 'title']),
      'sku': findIndex(['sku', 'brand', 'item code', 'code']),
      'barcode': findIndex(['barcode', 'upc', 'ean', 'qr code']),
      'category': findIndex(['category', 'group', 'department', 'type']),
      'unit': findIndex(['unit', 'pack', 'uom', 'measurement']),
      'buy_price': findIndex(['buy price', 'cost price', 'cost', 'purchase price']),
      'sell_price': findIndex(['sell price', 'selling price', 'mrp', 'price', 'rate']),
      'low_stock': findIndex(['low stock', 'reorder level', 'min stock', 'alert level']),
      'initial_stock': findIndex(['initial stock', 'opening stock', 'current stock', 'stock', 'qty', 'quantity']),
    };
  }

  static String _getString(List<dynamic> row, int? index, {String defaultValue = ''}) {
    if (index == null || index >= row.length) return defaultValue;
    final val = row[index]?.toString().trim() ?? '';
    return val.isEmpty ? defaultValue : val;
  }

  static double _getDouble(List<dynamic> row, int? index, {double defaultValue = 0.0}) {
    if (index == null || index >= row.length) return defaultValue;
    final raw = row[index]?.toString().replaceAll(RegExp(r'[^\d.-]'), '').trim() ?? '';
    return double.tryParse(raw) ?? defaultValue;
  }

  static int _getInt(List<dynamic> row, int? index, {int defaultValue = 0}) {
    if (index == null || index >= row.length) return defaultValue;
    final raw = row[index]?.toString().replaceAll(RegExp(r'[^\d-]'), '').trim() ?? '';
    return int.tryParse(raw) ?? defaultValue;
  }
}
