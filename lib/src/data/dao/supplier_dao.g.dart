// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supplier_dao.dart';

// ignore_for_file: type=lint
mixin _$SupplierDaoMixin on DatabaseAccessor<AppDatabase> {
  $SuppliersTable get suppliers => attachedDatabase.suppliers;
  $ProductsTable get products => attachedDatabase.products;
  $MovementsTable get movements => attachedDatabase.movements;
  SupplierDaoManager get managers => SupplierDaoManager(this);
}

class SupplierDaoManager {
  final _$SupplierDaoMixin _db;
  SupplierDaoManager(this._db);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db.attachedDatabase, _db.suppliers);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$MovementsTableTableManager get movements =>
      $$MovementsTableTableManager(_db.attachedDatabase, _db.movements);
}
