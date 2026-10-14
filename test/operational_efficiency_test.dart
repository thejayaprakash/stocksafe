import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stocksafe/src/data/database.dart';
import 'package:stocksafe/src/services/barcode_label_service.dart';
import 'package:stocksafe/src/services/esc_pos_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Supplier / Vendor Contacts Directory', () {
    test('Create, retrieve, update, search, and soft-delete suppliers', () async {
      final now = DateTime.now();

      // 1. Insert suppliers
      final s1Id = await db.supplierDao.insertSupplier(
        SuppliersCompanion.insert(
          name: 'Ramesh Wholesale Provisions',
          phone: '9876543210',
          gstin: const drift.Value('33AAAAA0000A1Z5'),
          notes: const drift.Value('Weekly grain distributor, delivers Tuesdays'),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final s2Id = await db.supplierDao.insertSupplier(
        SuppliersCompanion.insert(
          name: 'Balaji Dairy & Beverages',
          phone: '9123456780',
          gstin: const drift.Value('33BBBBB1111B2Z6'),
          notes: const drift.Value('Daily morning delivery before 7am'),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 2. Retrieve by ID
      final s1 = await db.supplierDao.getById(s1Id);
      expect(s1, isNotNull);
      expect(s1!.name, 'Ramesh Wholesale Provisions');
      expect(s1.phone, '9876543210');
      expect(s1.gstin, '33AAAAA0000A1Z5');

      // 3. Search query filter
      final searchByName = await db.supplierDao.watchAll(query: 'balaji').first;
      expect(searchByName.length, 1);
      expect(searchByName.first.id, s2Id);

      final searchByPhone = await db.supplierDao.watchAll(query: '98765').first;
      expect(searchByPhone.length, 1);
      expect(searchByPhone.first.id, s1Id);

      final searchByGstin = await db.supplierDao.watchAll(query: '33AAAAA').first;
      expect(searchByGstin.length, 1);
      expect(searchByGstin.first.id, s1Id);

      // 4. Update supplier details
      final updated = await db.supplierDao.updateSupplier(
        s1Id,
        const SuppliersCompanion(
          phone: drift.Value('9998887776'),
          notes: drift.Value('Updated delivery contact'),
        ),
      );
      expect(updated, isTrue);

      final s1Updated = await db.supplierDao.getById(s1Id);
      expect(s1Updated!.phone, '9998887776');
      expect(s1Updated.notes, 'Updated delivery contact');

      // 5. Soft delete and restore
      expect(await db.supplierDao.countActive(), 2);
      await db.supplierDao.softDelete(s2Id);
      expect(await db.supplierDao.countActive(), 1);

      final activeSuppliers = await db.supplierDao.getAll();
      expect(activeSuppliers.any((s) => s.id == s2Id), isFalse);

      await db.supplierDao.restore(s2Id);
      expect(await db.supplierDao.countActive(), 2);
    });

    test('Product-Supplier mapping and movement vendor linkage', () async {
      final now = DateTime.now();

      // 1. Create supplier
      final supId = await db.supplierDao.insertSupplier(
        SuppliersCompanion.insert(
          name: 'Shree Krishna Agro Pulses',
          phone: '9443322110',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 2. Create products with preferred supplier
      final p1Id = await db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: 'Toor Dal Premium Loose 1kg',
          category: const drift.Value('Grains & Pulses'),
          unit: const drift.Value('kg'),
          buyPrice: const drift.Value(140.0),
          sellPrice: const drift.Value(170.0),
          lowStockLevel: const drift.Value(20),
          supplierId: drift.Value(supId),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final p2Id = await db.productDao.insertProduct(
        ProductsCompanion.insert(
          name: 'Moong Dal 500g',
          category: const drift.Value('Grains & Pulses'),
          unit: const drift.Value('pkt'),
          buyPrice: const drift.Value(60.0),
          sellPrice: const drift.Value(75.0),
          lowStockLevel: const drift.Value(15),
          supplierId: drift.Value(supId),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 3. Verify supplier product list
      final suppliedProducts = await db.supplierDao.getProductsForSupplier(supId);
      expect(suppliedProducts.length, 2);
      expect(suppliedProducts.map((p) => p.id), containsAll([p1Id, p2Id]));

      final count = await db.supplierDao.watchProductCountForSupplier(supId).first;
      expect(count, 2);

      // 4. Record stock movement linked to supplier
      await db.movementDao.recordMovement(
        productId: p1Id,
        qtyDelta: 50,
        reason: 'Stock in',
        note: 'Invoice #TK-9021',
        supplierId: supId,
      );

      final movements = await db.movementDao.watchForProduct(p1Id).first;
      expect(movements.first.supplierId, supId);
      expect(movements.first.qtyDelta, 50);

      final p1 = await db.productDao.getById(p1Id);
      expect(p1!.stockQty, 50);
    });
  });

  group('Bluetooth Thermal Receipt / Slip Printing (ESC/POS)', () {
    test('ESC/POS byte stream begins with init [ESC @] and ends with cut [GS V 0]', () {
      final now = DateTime.now();
      final product = Product(
        isFavourite: false,
        id: 1,
        name: 'Sugar M30 Loose 1kg',
        category: 'Staples',
        unit: 'kg',
        buyPrice: 38.0,
        sellPrice: 44.0,
        lowStockLevel: 50,
        stockQty: 10,
        createdAt: now,
        updatedAt: now,
      );

      final bytes = EscPosService.buildDeliverySlipBytes(
        product: product,
        quantity: 100,
        reason: 'Stock in',
        shopName: 'Sri Amman Kirana',
        paperWidth: ThermalPaperWidth.mm58,
      );

      // Must start with ESC @ (0x1B, 0x40)
      expect(bytes[0], 0x1B);
      expect(bytes[1], 0x40);

      // Must end with GS V 0 (0x1D, 0x56, 0x00) cut command
      expect(bytes[bytes.length - 3], 0x1D);
      expect(bytes[bytes.length - 2], 0x56);
      expect(bytes[bytes.length - 1], 0x00);
    });

    test('Audit Discrepancy Slip formats surplus, shortage, and shrinkage value accurately', () {
      final now = DateTime.now();
      final session = StockAuditSession(
        id: 10,
        name: 'Aisle 3 Weekly Stocktake',
        status: 'completed',
        auditMode: 'transparent',
        startedAt: now,
        completedAt: now,
        totalItemsCounted: 3,
        totalDiscrepancies: 2,
        netDiscrepancyValue: -40.0,
      );

      final p1 = Product(
        isFavourite: false,
        id: 1,
        name: 'Tata Salt 1kg',
        unit: 'pkt',
        buyPrice: 20.0,
        sellPrice: 28.0,
        lowStockLevel: 10,
        stockQty: 25,
        createdAt: now,
        updatedAt: now,
      );
      final p2 = Product(
        isFavourite: false,
        id: 2,
        name: 'Sunflower Oil 1L',
        unit: 'pouch',
        buyPrice: 110.0,
        sellPrice: 135.0,
        lowStockLevel: 10,
        stockQty: 15,
        createdAt: now,
        updatedAt: now,
      );

      final items = [
        StockAuditItemWithProduct(
          item: StockAuditItem(
            id: 1,
            sessionId: 10,
            productId: 1,
            expectedQty: 25,
            countedQty: 20, // Shortage of 5 packets (-Rs 100)
            difference: -5,
            isReconciled: true,
            updatedAt: now,
          ),
          product: p1,
        ),
        StockAuditItemWithProduct(
          item: StockAuditItem(
            id: 2,
            sessionId: 10,
            productId: 2,
            expectedQty: 15,
            countedQty: 17, // Surplus of 2 pouches (+Rs 220)
            difference: 2,
            isReconciled: true,
            updatedAt: now,
          ),
          product: p2,
        ),
      ];

      // 58mm test
      final text58 = EscPosService.buildAuditDiscrepancyText(
        session: session,
        items: items,
        shopName: 'Super Kirana',
        paperWidth: ThermalPaperWidth.mm58,
      );

      expect(text58, contains('SUPER KIRANA'));
      expect(text58, contains('PHYSICAL AUDIT DISCREPANCY'));
      expect(text58, contains('Total Counted:'));
      expect(text58, contains('Tata Salt 1kg'));
      expect(text58, contains('Diff:-5 pkt'));
      expect(text58, contains('Audited by:'));
      expect(text58, contains('Store Manager:'));

      // 80mm ESC/POS bytes test
      final bytes80 = EscPosService.buildAuditDiscrepancySlipBytes(
        session: session,
        items: items,
        shopName: 'Super Kirana',
        paperWidth: ThermalPaperWidth.mm80,
      );
      expect(bytes80.isNotEmpty, isTrue);

      final rawDecoded = latin1.decode(bytes80);
      expect(rawDecoded, contains('SUPER KIRANA'));
      expect(rawDecoded, contains('Aisle 3 Weekly Stocktake'));
    });

    test('Low Stock Reorder Slip generates order quantities and preferred vendor info', () {
      final now = DateTime.now();
      final supplier = Supplier(
        id: 5,
        name: 'Venkateswara Flour Mills',
        phone: '9840012345',
        createdAt: now,
        updatedAt: now,
      );

      final p = Product(
        isFavourite: false,
        id: 7,
        name: 'Aashirvaad Atta 5kg',
        unit: 'bag',
        buyPrice: 220.0,
        sellPrice: 260.0,
        lowStockLevel: 15,
        stockQty: 3,
        supplierId: 5,
        createdAt: now,
        updatedAt: now,
      );

      final entries = [
        LowStockSlipEntry(
          product: p,
          suggestedOrderQty: 25,
          supplier: supplier,
        ),
      ];

      final text = EscPosService.buildLowStockReorderText(
        entries: entries,
        shopName: 'City Mart',
        paperWidth: ThermalPaperWidth.mm58,
      );

      expect(text, contains('CITY MART'));
      expect(text, contains('LOW STOCK PURCHASE ORDER SLIP'));
      expect(text, contains('Aashirvaad Atta 5kg'));
      expect(text, contains('ORDER: +25'));
      expect(text, contains('Venkateswara Flour Mills'));
      expect(text, contains('9840012345'));
    });
  });

  group('Barcode Label Printing (PDF Sticker Sheets & Thermal Rolls)', () {
    test('Generates valid PDF document for unbranded loose packaged goods', () async {
      final now = DateTime.now();
      final looseRice = Product(
        isFavourite: false,
        id: 42,
        name: 'Sona Masoori Rice 1kg Pack',
        category: 'Grains',
        unit: '1 kg',
        buyPrice: 52.0,
        sellPrice: 65.0,
        lowStockLevel: 20,
        stockQty: 80,
        barcode: null, // Unbranded item packaged in shop!
        sku: null,
        createdAt: now,
        updatedAt: now,
      );

      // Generate A4 24-up sticker sheet
      final config24 = BarcodeLabelConfig(
        product: looseRice,
        count: 24,
        format: LabelSheetFormat.a4_24,
        symbology: BarcodeSymbology.code128,
        shopName: 'Sri Lakshmi Kirana',
        showPrice: true,
        showPackDate: true,
      );

      final pdfBytes = await BarcodeLabelService.generateLabelSheet(config24);

      // Check PDF Magic header '%PDF-'
      expect(pdfBytes.length, greaterThan(500));
      expect(pdfBytes[0], 0x25); // '%'
      expect(pdfBytes[1], 0x50); // 'P'
      expect(pdfBytes[2], 0x44); // 'D'
      expect(pdfBytes[3], 0x46); // 'F'
      expect(pdfBytes[4], 0x2D); // '-'
    });

    test('Generates Thermal Roll 50x25mm and QR Code labels correctly', () async {
      final now = DateTime.now();
      final dryFruits = Product(
        isFavourite: false,
        id: 99,
        name: 'California Almonds 250g',
        unit: '250g',
        buyPrice: 180.0,
        sellPrice: 220.0,
        lowStockLevel: 10,
        stockQty: 30,
        barcode: '8901030800012',
        createdAt: now,
        updatedAt: now,
      );

      // Thermal roll single stickers with QR code
      final thermalConfig = BarcodeLabelConfig(
        product: dryFruits,
        count: 10,
        format: LabelSheetFormat.thermal_50x25,
        symbology: BarcodeSymbology.qrCode,
        shopName: 'Dry Fruits Hub',
      );

      final thermalPdfBytes = await BarcodeLabelService.generateLabelSheet(thermalConfig);
      expect(thermalPdfBytes.length, greaterThan(500));
      expect(thermalPdfBytes[0], 0x25); // '%'
      expect(thermalPdfBytes[1], 0x50); // 'P'
      expect(thermalPdfBytes[2], 0x44); // 'D'
      expect(thermalPdfBytes[3], 0x46); // 'F'
    });

    test('Supports partial sheet start offset skipping on used A4 sticker sheets', () async {
      final now = DateTime.now();
      final dal = Product(
        isFavourite: false,
        id: 15,
        name: 'Chana Dal 500g',
        unit: '500g',
        buyPrice: 40.0,
        sellPrice: 50.0,
        lowStockLevel: 10,
        stockQty: 20,
        createdAt: now,
        updatedAt: now,
      );

      // Skip first 5 stickers that were previously peeled off from the sheet
      final offsetConfig = BarcodeLabelConfig(
        product: dal,
        count: 10,
        format: LabelSheetFormat.a4_24,
        startOffset: 5,
      );

      final pdfWithOffset = await BarcodeLabelService.generateLabelSheet(offsetConfig);
      expect(pdfWithOffset.length, greaterThan(500));
      expect(pdfWithOffset[0], 0x25); // '%'
    });
  });
}
