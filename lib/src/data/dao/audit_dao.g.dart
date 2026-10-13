// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audit_dao.dart';

// ignore_for_file: type=lint
mixin _$AuditDaoMixin on DatabaseAccessor<AppDatabase> {
  $StockAuditSessionsTable get stockAuditSessions =>
      attachedDatabase.stockAuditSessions;
  $SuppliersTable get suppliers => attachedDatabase.suppliers;
  $ProductsTable get products => attachedDatabase.products;
  $StockAuditItemsTable get stockAuditItems => attachedDatabase.stockAuditItems;
  $MovementsTable get movements => attachedDatabase.movements;
  AuditDaoManager get managers => AuditDaoManager(this);
}

class AuditDaoManager {
  final _$AuditDaoMixin _db;
  AuditDaoManager(this._db);
  $$StockAuditSessionsTableTableManager get stockAuditSessions =>
      $$StockAuditSessionsTableTableManager(
          _db.attachedDatabase, _db.stockAuditSessions);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db.attachedDatabase, _db.suppliers);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$StockAuditItemsTableTableManager get stockAuditItems =>
      $$StockAuditItemsTableTableManager(
          _db.attachedDatabase, _db.stockAuditItems);
  $$MovementsTableTableManager get movements =>
      $$MovementsTableTableManager(_db.attachedDatabase, _db.movements);
}
