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
    final capacity = await license.getEffectiveCapacity();
    final freeLimit = capacity > 0 ? capacity : await license.getFreeLimit();
    final availableQuota = isPro ? 999999 : (freeLimit - currentCount).clamp(0, freeLimit);

    // Every barcode already in the catalogue, read once.
    //
    // The importer used to run getByBarcode() per row. That is one query per
    // line of a supplier file — fine for the handful of pasted rows this
    // feature started with, quadratic-feeling for the thousand-row
    // spreadsheet it now accepts. Loading them up front turns the duplicate
    // check into a set lookup, and rows accepted during this import join the
    // same set, so in-file duplicates are caught by the same code.
    final catalogueBarcodes = await _existingBarcodes();
    // Kept separate from the catalogue set so the two cases can be told
    // apart: "this file lists it twice" and "you already stock it" need
    // different things from the user.
    final seenInThisFile = <String>{};

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
          if (!seenInThisFile.add(barcode)) {
            errors.add('Row $rowNum: barcode "$barcode" is repeated earlier '
                'in this file — row skipped.');
            skipped++;
            continue;
          }
          if (catalogueBarcodes.contains(barcode)) {
            errors.add('Row $rowNum: barcode "$barcode" is already in your '
                'catalogue — row skipped.');
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

  /// Barcodes belonging to live products, as a set.
  Future<Set<String>> _existingBarcodes() async {
    final rows = await _db
        .customSelect(
          'SELECT barcode FROM product '
          'WHERE barcode IS NOT NULL AND deleted_at IS NULL',
          readsFrom: {_db.products},
        )
        .get();
    return rows.map((r) => r.read<String>('barcode')).toSet();
  }

  /// Column synonyms, each list ordered most specific first.
  ///
  /// Deliberately overlapping: "code" catches "Item Code", but also appears
  /// inside "Barcode"; "price" catches a bare "Price" column, but also sits
  /// inside "Buy Price". Resolution below handles the overlap — the lists
  /// themselves stay permissive, because supplier headers are not consistent.
  static const Map<String, List<String>> _headerSynonyms = {
    'name': ['product name', 'item name', 'name', 'title'],
    'barcode': ['barcode', 'bar code', 'upc', 'ean', 'qr code'],
    'sku': ['sku', 'item code', 'product code', 'brand', 'code'],
    'category': ['category', 'group', 'department', 'type'],
    'unit': ['unit', 'uom', 'pack', 'measurement'],
    'buy_price': ['buy price', 'cost price', 'purchase price', 'cost'],
    'sell_price': ['sell price', 'selling price', 'mrp', 'rate', 'price'],
    'low_stock': ['low stock', 'reorder level', 'min stock', 'alert level'],
    'initial_stock': [
      'initial stock',
      'opening stock',
      'current stock',
      'quantity',
      'stock',
      'qty',
    ],
  };

  /// Maps a file's header row onto our fields.
  ///
  /// Fixes a bug that silently corrupted data. The previous resolver scanned
  /// headers in the outer loop and returned on the first synonym that hit, so
  /// for `Name,Buy Price,Sell Price` the loose synonym "price" matched
  /// "Buy Price" and every product imported with its selling price equal to
  /// its cost — wrong margins, wrong valuation, nothing to indicate it.
  ///
  /// Two mechanisms prevent it, and they are **redundant**: either alone is
  /// sufficient. Verified by mutation — removing one and then the other left
  /// the tests green; only removing both reproduced the 450.50-instead-of-520
  /// failure.
  ///
  ///  1. Synonyms are the outer loop, so a specific synonym is tried against
  ///     every column before a looser one is tried against any.
  ///  2. A column, once claimed, cannot be claimed again, and `buy_price` is
  ///     resolved before `sell_price`.
  ///
  /// Both are kept deliberately. Supplier headers are not consistent, and the
  /// failure mode here is silent and financial.
  static Map<String, int?> _resolveHeaderMap(List<String> headers) {
    final normalised = headers
        .map((h) => h.toLowerCase().trim().replaceAll(RegExp(r'[\s_]+'), ' '))
        .toList();

    final resolved = <String, int?>{};
    final claimed = <int>{};

    int? firstMatch(List<String> synonyms, bool Function(String, String) test) {
      for (final synonym in synonyms) {
        for (var i = 0; i < normalised.length; i++) {
          if (claimed.contains(i)) continue;
          if (test(normalised[i], synonym)) return i;
        }
      }
      return null;
    }

    for (final entry in _headerSynonyms.entries) {
      final index = firstMatch(
        entry.value,
        (header, synonym) => header == synonym || header.contains(synonym),
      );
      if (index != null) {
        resolved[entry.key] = index;
        claimed.add(index);
      }
    }

    for (final key in _headerSynonyms.keys) {
      resolved.putIfAbsent(key, () => null);
    }
    return resolved;
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
