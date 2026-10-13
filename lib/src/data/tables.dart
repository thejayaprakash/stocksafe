import 'package:drift/drift.dart';

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
  TextColumn get unit => text().withDefault(const Constant('pcs'))();

  RealColumn get buyPrice => real().withDefault(const Constant(0))();
  RealColumn get sellPrice => real().withDefault(const Constant(0))();

  IntColumn get lowStockLevel => integer().withDefault(const Constant(0))();

  /// Rebuildable cache of SUM(movement.qty_delta). Never authoritative.
  IntColumn get stockQty => integer().withDefault(const Constant(0))();

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
  DateTimeColumn get createdAt => dateTime()();
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
