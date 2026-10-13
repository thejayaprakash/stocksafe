// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location_dao.dart';

// ignore_for_file: type=lint
mixin _$LocationDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocationsTable get locations => attachedDatabase.locations;
  $SuppliersTable get suppliers => attachedDatabase.suppliers;
  $ProductsTable get products => attachedDatabase.products;
  $MovementsTable get movements => attachedDatabase.movements;
  LocationDaoManager get managers => LocationDaoManager(this);
}

class LocationDaoManager {
  final _$LocationDaoMixin _db;
  LocationDaoManager(this._db);
  $$LocationsTableTableManager get locations =>
      $$LocationsTableTableManager(_db.attachedDatabase, _db.locations);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db.attachedDatabase, _db.suppliers);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$MovementsTableTableManager get movements =>
      $$MovementsTableTableManager(_db.attachedDatabase, _db.movements);
}
