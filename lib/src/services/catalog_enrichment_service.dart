import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Information retrieved from public product catalogs by barcode.
class CatalogProductInfo {
  const CatalogProductInfo({
    required this.barcode,
    this.name,
    this.brand,
    this.category,
    this.unit,
    this.imageUrl,
  });

  final String barcode;
  final String? name;
  final String? brand;
  final String? category;
  final String? unit;
  final String? imageUrl;

  String get displayName {
    if (name != null && name!.isNotEmpty) {
      if (brand != null && brand!.isNotEmpty && !name!.toLowerCase().contains(brand!.toLowerCase())) {
        return '$brand $name';
      }
      return name!;
    }
    return brand ?? '';
  }
}

/// Service that queries online catalogs to enrich scanned barcodes
/// with product names, brands, pack sizes, and categories.
class CatalogEnrichmentService {
  CatalogEnrichmentService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Look up an unknown barcode with a strict timeout to ensure zero UI lag.
  Future<CatalogProductInfo?> lookupBarcode(String barcode) async {
    final cleanCode = barcode.trim();
    if (cleanCode.length < 6) return null;

    try {
      final url = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$cleanCode.json');
      final response = await _client.get(
        url,
        headers: {
          'User-Agent': 'StockSafe - Android - Version 0.1.0 - OpenSourceInventory',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 1 || data['product'] == null) {
        return null;
      }

      final product = data['product'] as Map<String, dynamic>;

      final rawName = product['product_name'] as String? ??
          product['product_name_en'] as String? ??
          product['generic_name'] as String?;

      final rawBrand = product['brands'] as String?;
      final rawQuantity = product['quantity'] as String?;
      final rawCategory = product['categories'] as String?;
      final rawImage = product['image_front_small_url'] as String? ??
          product['image_front_url'] as String?;

      return CatalogProductInfo(
        barcode: cleanCode,
        name: rawName?.trim(),
        brand: rawBrand?.split(',').first.trim(),
        unit: rawQuantity?.trim() ?? 'pcs',
        category: rawCategory?.split(',').first.trim(),
        imageUrl: rawImage,
      );
    } catch (_) {
      // Offline, DNS failure, timeout, or invalid JSON — return null silently.
      return null;
    }
  }
}
