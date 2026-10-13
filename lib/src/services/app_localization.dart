import 'package:flutter/material.dart';

/// Supported application languages.
enum AppLanguage {
  english('en', 'English'),
  tamil('ta', 'தமிழ்');

  const AppLanguage(this.code, this.label);
  final String code;
  final String label;
}

/// Bilingual Localization Engine supporting English and Tamil (தமிழ்).
/// Provides reactive language switching across all screens without external packages.
class AppLocale extends ChangeNotifier {
  AppLocale._();
  static final AppLocale instance = AppLocale._();

  AppLanguage _current = AppLanguage.english;
  AppLanguage get current => _current;

  void setLanguage(AppLanguage lang) {
    if (_current != lang) {
      _current = lang;
      notifyListeners();
    }
  }

  static String tr(String key) {
    final lang = instance._current;
    final map = lang == AppLanguage.tamil ? _tamilStrings : _englishStrings;
    return map[key] ?? _englishStrings[key] ?? key;
  }

  static const Map<String, String> _englishStrings = {
    'app_name': 'StockSafe',
    'products': 'Products',
    'low_stock': 'Low Stock',
    'settings': 'Settings',
    'search_hint': 'Search name, SKU or barcode',
    'all_categories': 'All',
    'add_product': 'Add Product',
    'edit_product': 'Edit Product',
    'name': 'Product Name',
    'category': 'Category',
    'sku_brand': 'SKU / Brand',
    'barcode': 'Barcode',
    'unit': 'Unit / Pack',
    'buy_price': 'Buy Price (Cost)',
    'sell_price': 'Sell Price (MRP)',
    'low_stock_limit': 'Low Stock Alert Threshold',
    'stock_audit': 'Stocktake Audit',
    'reconcile': 'Reconcile',
    'matched': 'Matched',
    'discrepancies': 'Discrepancies',
    'backup_export': 'Backup & Data Sovereignty',
    'rebuild_cache': 'Rebuild Stock Cache',
    'active_products': 'active products',
    'offline_tag': '100% Offline & Private',
    'ask_ai': 'Ask StockSafe AI',
    'start_audit': 'Start Audit Session',
    'scan_barcode': 'Scan Barcode',
    'opening_stock': 'Opening Stock',
    'inventory_valuation': 'Inventory Valuation',
    'cost_value': 'Cost Value',
    'retail_value': 'Retail Value',
    'est_margin': 'Est. Gross Margin',
    'total_units': 'Total Units',
    'batches': 'Batches & Expiry',
    'batch_number': 'Batch Number',
    'expiry_date': 'Expiry Date',
    'expiring_soon': 'Expiring Soon',
    'expired': 'Expired',
    'no_batches': 'No batches recorded',
    'add_batch': 'Add Batch',
    'days_left': 'days left',
    'select_expiry': 'Select Expiry Date',
    'fifo_recommended': 'FIFO Recommended',
    'suppliers': 'Suppliers & Vendors',
    'call_supplier': 'Call Supplier',
    'assign_supplier': 'Assign Supplier',
    'print_reorder_slip': 'Print Reorder Slip (ESC/POS)',
    'print_discrepancy_slip': 'Print Discrepancy Slip (ESC/POS)',
    'barcode_label_printing': 'Barcode Sticker Printing',
    'thermal_printing': 'Thermal Slip (ESC/POS)',
  };

  static const Map<String, String> _tamilStrings = {
    'app_name': 'ஸ்டாக்சேஃப்',
    'products': 'பொருட்கள்',
    'low_stock': 'குறைந்த இருப்பு',
    'settings': 'அமைப்புகள்',
    'search_hint': 'பெயர், SKU அல்லது பார்கோடு தேடுக',
    'all_categories': 'அனைத்தும்',
    'add_product': 'பொருளைச் சேர்',
    'edit_product': 'பொருளைத் திருத்து',
    'name': 'பொருளின் பெயர்',
    'category': 'பிரிவு (வகை)',
    'sku_brand': 'SKU / பிராண்ட்',
    'barcode': 'பார்கோடு',
    'unit': 'அலகு (எ.கா: பாக்கெட், கிலோ)',
    'buy_price': 'வாங்கிய விலை (அடக்கம்)',
    'sell_price': 'விற்பனை விலை (MRP)',
    'low_stock_limit': 'குறைந்த இருப்பு எச்சரிக்கை அளவு',
    'stock_audit': 'இருப்பு தணிக்கை',
    'reconcile': 'சரிபார் மற்றும் புதுப்பி',
    'matched': 'பொருந்தியவை',
    'discrepancies': 'முரண்பாடுகள்',
    'backup_export': 'காப்புநகல் & பாதுகாப்பு',
    'rebuild_cache': 'இருப்பு கணக்கை புதுப்பி',
    'active_products': 'செயலில் உள்ள பொருட்கள்',
    'offline_tag': '100% ஆஃப்லைன் & பாதுகாப்பானது',
    'ask_ai': 'ஸ்டாக்சேஃப் AI ஆலோசனை',
    'start_audit': 'தணிக்கையைத் தொடங்கு',
    'scan_barcode': 'பார்கோடு ஸ்கேன் செய்க',
    'opening_stock': 'தொடக்க இருப்பு',
    'inventory_valuation': 'இருப்பு மதிப்பு',
    'cost_value': 'வாங்கிய மதிப்பு',
    'retail_value': 'விற்பனை மதிப்பு',
    'est_margin': 'மதிப்பிடப்பட்ட லாபம்',
    'total_units': 'மொத்த அலகுகள்',
    'batches': 'கட்டுகள் & காலாவதி',
    'batch_number': 'கட்டு எண்',
    'expiry_date': 'காலாவதி தேதி',
    'expiring_soon': 'விரைவில் காலாவதி',
    'expired': 'காலாவதியானது',
    'no_batches': 'கட்டுகள் பதிவு செய்யப்படவில்லை',
    'add_batch': 'கட்டைச் சேர்',
    'days_left': 'நாட்கள் மீதம்',
    'select_expiry': 'காலாவதி தேதியைத் தேர்ந்தெடுக்கவும்',
    'fifo_recommended': 'முதலில் வந்ததை முதலில் விற்கவும்',
    'suppliers': 'விற்பனையாளர்கள் / சப்ளையர்கள்',
    'call_supplier': 'சப்ளையரை அழைக்கவும்',
    'assign_supplier': 'சப்ளையரை ஒதுக்கவும்',
    'print_reorder_slip': 'மறுவரிசை சீட்டு அச்சிடுக (ESC/POS)',
    'print_discrepancy_slip': 'மாறுபாடு சீட்டு அச்சிடுக (ESC/POS)',
    'barcode_label_printing': 'பார்கோடு லேபிள் அச்சிடுதல்',
    'thermal_printing': 'தெர்மல் ரசீது (ESC/POS)',
  };
}
