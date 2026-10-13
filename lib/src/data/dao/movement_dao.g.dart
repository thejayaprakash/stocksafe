// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movement_dao.dart';

// ignore_for_file: type=lint
mixin _$MovementDaoMixin on DatabaseAccessor<AppDatabase> {
  $SuppliersTable get suppliers => attachedDatabase.suppliers;
  $ProductsTable get products => attachedDatabase.products;
  $MovementsTable get movements => attachedDatabase.movements;
  MovementDaoManager get managers => MovementDaoManager(this);
}

class MovementDaoManager {
  final _$MovementDaoMixin _db;
  MovementDaoManager(this._db);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db.attachedDatabase, _db.suppliers);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$MovementsTableTableManager get movements =>
      $$MovementsTableTableManager(_db.attachedDatabase, _db.movements);
}
