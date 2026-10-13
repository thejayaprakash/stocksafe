// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'batch_dao.dart';

// ignore_for_file: type=lint
mixin _$BatchDaoMixin on DatabaseAccessor<AppDatabase> {
  $ProductsTable get products => attachedDatabase.products;
  $BatchesTable get batches => attachedDatabase.batches;
  BatchDaoManager get managers => BatchDaoManager(this);
}

class BatchDaoManager {
  final _$BatchDaoMixin _db;
  BatchDaoManager(this._db);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$BatchesTableTableManager get batches =>
      $$BatchesTableTableManager(_db.attachedDatabase, _db.batches);
}
