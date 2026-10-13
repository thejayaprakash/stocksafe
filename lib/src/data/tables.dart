import 'package:drift/drift.dart';

/// Supplier / Vendor Contacts Directory.
/// Lightweight directory allowing retailers to record contact details,
/// call suppliers directly for restocks, and link inward movements.
class Suppliers extends Table {
  @override
  String get tableName => 'supplier';

  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get phone => text().withLength(min: 1, max: 50)();
  TextColumn get gstin => text().nullable()();
  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Product master data. Soft delete only — `deletedAt` marks removal,
/// the row is never dropped. Cached `stockQty` is a speed convenience;
/// the movement ledger is the source of truth and it is rebuildable.
class Products extends Table {
  @override
  String get tableName => 'product';

  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get sku => text().nullable()();
  TextColumn get barcode => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get unit => text().withDefault(const Constant('pcs'))();

  RealColumn get buyPrice => real().withDefault(const Constant(0))();
  RealColumn get sellPrice => real().withDefault(const Constant(0))();

  IntColumn get lowStockLevel => integer().withDefault(const Constant(0))();

  /// Rebuildable cache of SUM(movement.qty_delta). Never authoritative.
  IntColumn get stockQty => integer().withDefault(const Constant(0))();

  /// Preferred supplier / vendor for this product.
  IntColumn get supplierId =>
      integer().nullable().references(Suppliers, #id, onDelete: KeyAction.setNull)();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// Append-only stock movement ledger. Rows are inserted, never updated
/// or deleted. `qtyDelta` is signed: +10 in, -10 out.
class Movements extends Table {
  @override
  String get tableName => 'movement';

  IntColumn get id => integer().autoIncrement()();

  IntColumn get productId =>
      integer().references(Products, #id, onDelete: KeyAction.cascade)();

  IntColumn get qtyDelta => integer()();
  TextColumn get reason => text()();
  TextColumn get note => text().nullable()();
  IntColumn get auditSessionId => integer().nullable()();
  IntColumn get batchId => integer().nullable()();
  IntColumn get supplierId =>
      integer().nullable().references(Suppliers, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get createdAt => dateTime()();
}

/// Persistent physical stocktake sessions (draft, in_progress, completed, cancelled).
class StockAuditSessions extends Table {
  @override
  String get tableName => 'stock_audit_session';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get status => text().withDefault(const Constant('in_progress'))();
  TextColumn get auditMode => text().withDefault(const Constant('transparent'))();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get totalItemsCounted => integer().withDefault(const Constant(0))();
  IntColumn get totalDiscrepancies => integer().withDefault(const Constant(0))();
  RealColumn get netDiscrepancyValue => real().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
}

/// Individual item audit records linked to a persistent audit session.
class StockAuditItems extends Table {
  @override
  String get tableName => 'stock_audit_item';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(StockAuditSessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get productId =>
      integer().references(Products, #id, onDelete: KeyAction.cascade)();
  IntColumn get expectedQty => integer()();
  IntColumn get countedQty => integer()();
  IntColumn get difference => integer()();
  BoolColumn get isReconciled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get reconciledAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
}

/// Batch and expiry tracking for perishable and high-velocity goods.
@DataClassName('ProductBatch')
class Batches extends Table {
  @override
  String get tableName => 'batch';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId =>
      integer().references(Products, #id, onDelete: KeyAction.cascade)();
  TextColumn get batchNumber => text().withLength(min: 1, max: 100)();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  IntColumn get stockQty => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

/// Small key/value store: schema metadata, backup timestamps, unlock state.
class Settings extends Table {
  @override
  String get tableName => 'setting';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
