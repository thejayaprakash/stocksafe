// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SuppliersTable extends Suppliers
    with TableInfo<$SuppliersTable, Supplier> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SuppliersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 200),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
      'phone', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 50),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _gstinMeta = const VerificationMeta('gstin');
  @override
  late final GeneratedColumn<String> gstin = GeneratedColumn<String>(
      'gstin', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, phone, gstin, notes, createdAt, updatedAt, deletedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'supplier';
  @override
  VerificationContext validateIntegrity(Insertable<Supplier> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
          _phoneMeta, phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta));
    } else if (isInserting) {
      context.missing(_phoneMeta);
    }
    if (data.containsKey('gstin')) {
      context.handle(
          _gstinMeta, gstin.isAcceptableOrUnknown(data['gstin']!, _gstinMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Supplier map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Supplier(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      phone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phone'])!,
      gstin: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}gstin']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $SuppliersTable createAlias(String alias) {
    return $SuppliersTable(attachedDatabase, alias);
  }
}

class Supplier extends DataClass implements Insertable<Supplier> {
  final int id;
  final String name;
  final String phone;
  final String? gstin;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Supplier(
      {required this.id,
      required this.name,
      required this.phone,
      this.gstin,
      this.notes,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['phone'] = Variable<String>(phone);
    if (!nullToAbsent || gstin != null) {
      map['gstin'] = Variable<String>(gstin);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  SuppliersCompanion toCompanion(bool nullToAbsent) {
    return SuppliersCompanion(
      id: Value(id),
      name: Value(name),
      phone: Value(phone),
      gstin:
          gstin == null && nullToAbsent ? const Value.absent() : Value(gstin),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Supplier.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Supplier(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String>(json['phone']),
      gstin: serializer.fromJson<String?>(json['gstin']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String>(phone),
      'gstin': serializer.toJson<String?>(gstin),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Supplier copyWith(
          {int? id,
          String? name,
          String? phone,
          Value<String?> gstin = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      Supplier(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        gstin: gstin.present ? gstin.value : this.gstin,
        notes: notes.present ? notes.value : this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  Supplier copyWithCompanion(SuppliersCompanion data) {
    return Supplier(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      gstin: data.gstin.present ? data.gstin.value : this.gstin,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Supplier(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('gstin: $gstin, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, name, phone, gstin, notes, createdAt, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Supplier &&
          other.id == this.id &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.gstin == this.gstin &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class SuppliersCompanion extends UpdateCompanion<Supplier> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> phone;
  final Value<String?> gstin;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  const SuppliersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.gstin = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  SuppliersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String phone,
    this.gstin = const Value.absent(),
    this.notes = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
  })  : name = Value(name),
        phone = Value(phone),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<Supplier> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? gstin,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (gstin != null) 'gstin': gstin,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  SuppliersCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String>? phone,
      Value<String?>? gstin,
      Value<String?>? notes,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt}) {
    return SuppliersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      gstin: gstin ?? this.gstin,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (gstin.present) {
      map['gstin'] = Variable<String>(gstin.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SuppliersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('gstin: $gstin, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $ProductsTable extends Products with TableInfo<$ProductsTable, Product> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 200),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _skuMeta = const VerificationMeta('sku');
  @override
  late final GeneratedColumn<String> sku = GeneratedColumn<String>(
      'sku', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _barcodeMeta =
      const VerificationMeta('barcode');
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
      'barcode', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
      'unit', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pcs'));
  static const VerificationMeta _buyPriceMeta =
      const VerificationMeta('buyPrice');
  @override
  late final GeneratedColumn<double> buyPrice = GeneratedColumn<double>(
      'buy_price', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _sellPriceMeta =
      const VerificationMeta('sellPrice');
  @override
  late final GeneratedColumn<double> sellPrice = GeneratedColumn<double>(
      'sell_price', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lowStockLevelMeta =
      const VerificationMeta('lowStockLevel');
  @override
  late final GeneratedColumn<int> lowStockLevel = GeneratedColumn<int>(
      'low_stock_level', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _stockQtyMeta =
      const VerificationMeta('stockQty');
  @override
  late final GeneratedColumn<int> stockQty = GeneratedColumn<int>(
      'stock_qty', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _supplierIdMeta =
      const VerificationMeta('supplierId');
  @override
  late final GeneratedColumn<int> supplierId = GeneratedColumn<int>(
      'supplier_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES supplier (id) ON DELETE SET NULL'));
  static const VerificationMeta _imagePathMeta =
      const VerificationMeta('imagePath');
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
      'image_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isFavouriteMeta =
      const VerificationMeta('isFavourite');
  @override
  late final GeneratedColumn<bool> isFavourite = GeneratedColumn<bool>(
      'is_favourite', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_favourite" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        sku,
        barcode,
        category,
        unit,
        buyPrice,
        sellPrice,
        lowStockLevel,
        stockQty,
        supplierId,
        imagePath,
        isFavourite,
        createdAt,
        updatedAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'product';
  @override
  VerificationContext validateIntegrity(Insertable<Product> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sku')) {
      context.handle(
          _skuMeta, sku.isAcceptableOrUnknown(data['sku']!, _skuMeta));
    }
    if (data.containsKey('barcode')) {
      context.handle(_barcodeMeta,
          barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta));
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('unit')) {
      context.handle(
          _unitMeta, unit.isAcceptableOrUnknown(data['unit']!, _unitMeta));
    }
    if (data.containsKey('buy_price')) {
      context.handle(_buyPriceMeta,
          buyPrice.isAcceptableOrUnknown(data['buy_price']!, _buyPriceMeta));
    }
    if (data.containsKey('sell_price')) {
      context.handle(_sellPriceMeta,
          sellPrice.isAcceptableOrUnknown(data['sell_price']!, _sellPriceMeta));
    }
    if (data.containsKey('low_stock_level')) {
      context.handle(
          _lowStockLevelMeta,
          lowStockLevel.isAcceptableOrUnknown(
              data['low_stock_level']!, _lowStockLevelMeta));
    }
    if (data.containsKey('stock_qty')) {
      context.handle(_stockQtyMeta,
          stockQty.isAcceptableOrUnknown(data['stock_qty']!, _stockQtyMeta));
    }
    if (data.containsKey('supplier_id')) {
      context.handle(
          _supplierIdMeta,
          supplierId.isAcceptableOrUnknown(
              data['supplier_id']!, _supplierIdMeta));
    }
    if (data.containsKey('image_path')) {
      context.handle(_imagePathMeta,
          imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta));
    }
    if (data.containsKey('is_favourite')) {
      context.handle(
          _isFavouriteMeta,
          isFavourite.isAcceptableOrUnknown(
              data['is_favourite']!, _isFavouriteMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Product map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Product(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      sku: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sku']),
      barcode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}barcode']),
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category']),
      unit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit'])!,
      buyPrice: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}buy_price'])!,
      sellPrice: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}sell_price'])!,
      lowStockLevel: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}low_stock_level'])!,
      stockQty: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}stock_qty'])!,
      supplierId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}supplier_id']),
      imagePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_path']),
      isFavourite: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_favourite'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $ProductsTable createAlias(String alias) {
    return $ProductsTable(attachedDatabase, alias);
  }
}

class Product extends DataClass implements Insertable<Product> {
  final int id;
  final String name;
  final String? sku;
  final String? barcode;
  final String? category;
  final String unit;
  final double buyPrice;
  final double sellPrice;
  final int lowStockLevel;

  /// Rebuildable cache of SUM(movement.qty_delta). Never authoritative.
  final int stockQty;

  /// Preferred supplier / vendor for this product.
  final int? supplierId;

  /// Path to a product photo on this device, or null.
  ///
  /// Nothing writes to it yet — the catalogue draws a tinted initial from the
  /// product's own category and name instead. The column is here because the
  /// alternative is a second migration later for a feature already planned,
  /// and an always-null column costs nothing in SQLite. Capture, storage and
  /// clean-up are a separate piece of work.
  ///
  /// A path rather than a URL: this app is offline by design, and a photo it
  /// cannot load without a network is a photo it cannot show. Readers must
  /// treat a non-null value as a file that may since have been deleted, moved
  /// by the OS, or restored onto a different device — always fall back.
  final String? imagePath;

  /// Pinned by the shopkeeper.
  ///
  /// Non-null with a default of false, so every existing row is simply "not
  /// favourited" and there is nothing to backfill. Toggled offline like
  /// everything else here; it is a local preference, not a synced one.
  final bool isFavourite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Product(
      {required this.id,
      required this.name,
      this.sku,
      this.barcode,
      this.category,
      required this.unit,
      required this.buyPrice,
      required this.sellPrice,
      required this.lowStockLevel,
      required this.stockQty,
      this.supplierId,
      this.imagePath,
      required this.isFavourite,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || sku != null) {
      map['sku'] = Variable<String>(sku);
    }
    if (!nullToAbsent || barcode != null) {
      map['barcode'] = Variable<String>(barcode);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['unit'] = Variable<String>(unit);
    map['buy_price'] = Variable<double>(buyPrice);
    map['sell_price'] = Variable<double>(sellPrice);
    map['low_stock_level'] = Variable<int>(lowStockLevel);
    map['stock_qty'] = Variable<int>(stockQty);
    if (!nullToAbsent || supplierId != null) {
      map['supplier_id'] = Variable<int>(supplierId);
    }
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    map['is_favourite'] = Variable<bool>(isFavourite);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  ProductsCompanion toCompanion(bool nullToAbsent) {
    return ProductsCompanion(
      id: Value(id),
      name: Value(name),
      sku: sku == null && nullToAbsent ? const Value.absent() : Value(sku),
      barcode: barcode == null && nullToAbsent
          ? const Value.absent()
          : Value(barcode),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      unit: Value(unit),
      buyPrice: Value(buyPrice),
      sellPrice: Value(sellPrice),
      lowStockLevel: Value(lowStockLevel),
      stockQty: Value(stockQty),
      supplierId: supplierId == null && nullToAbsent
          ? const Value.absent()
          : Value(supplierId),
      imagePath: imagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePath),
      isFavourite: Value(isFavourite),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Product.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Product(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sku: serializer.fromJson<String?>(json['sku']),
      barcode: serializer.fromJson<String?>(json['barcode']),
      category: serializer.fromJson<String?>(json['category']),
      unit: serializer.fromJson<String>(json['unit']),
      buyPrice: serializer.fromJson<double>(json['buyPrice']),
      sellPrice: serializer.fromJson<double>(json['sellPrice']),
      lowStockLevel: serializer.fromJson<int>(json['lowStockLevel']),
      stockQty: serializer.fromJson<int>(json['stockQty']),
      supplierId: serializer.fromJson<int?>(json['supplierId']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      isFavourite: serializer.fromJson<bool>(json['isFavourite']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'sku': serializer.toJson<String?>(sku),
      'barcode': serializer.toJson<String?>(barcode),
      'category': serializer.toJson<String?>(category),
      'unit': serializer.toJson<String>(unit),
      'buyPrice': serializer.toJson<double>(buyPrice),
      'sellPrice': serializer.toJson<double>(sellPrice),
      'lowStockLevel': serializer.toJson<int>(lowStockLevel),
      'stockQty': serializer.toJson<int>(stockQty),
      'supplierId': serializer.toJson<int?>(supplierId),
      'imagePath': serializer.toJson<String?>(imagePath),
      'isFavourite': serializer.toJson<bool>(isFavourite),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Product copyWith(
          {int? id,
          String? name,
          Value<String?> sku = const Value.absent(),
          Value<String?> barcode = const Value.absent(),
          Value<String?> category = const Value.absent(),
          String? unit,
          double? buyPrice,
          double? sellPrice,
          int? lowStockLevel,
          int? stockQty,
          Value<int?> supplierId = const Value.absent(),
          Value<String?> imagePath = const Value.absent(),
          bool? isFavourite,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        sku: sku.present ? sku.value : this.sku,
        barcode: barcode.present ? barcode.value : this.barcode,
        category: category.present ? category.value : this.category,
        unit: unit ?? this.unit,
        buyPrice: buyPrice ?? this.buyPrice,
        sellPrice: sellPrice ?? this.sellPrice,
        lowStockLevel: lowStockLevel ?? this.lowStockLevel,
        stockQty: stockQty ?? this.stockQty,
        supplierId: supplierId.present ? supplierId.value : this.supplierId,
        imagePath: imagePath.present ? imagePath.value : this.imagePath,
        isFavourite: isFavourite ?? this.isFavourite,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  Product copyWithCompanion(ProductsCompanion data) {
    return Product(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sku: data.sku.present ? data.sku.value : this.sku,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      category: data.category.present ? data.category.value : this.category,
      unit: data.unit.present ? data.unit.value : this.unit,
      buyPrice: data.buyPrice.present ? data.buyPrice.value : this.buyPrice,
      sellPrice: data.sellPrice.present ? data.sellPrice.value : this.sellPrice,
      lowStockLevel: data.lowStockLevel.present
          ? data.lowStockLevel.value
          : this.lowStockLevel,
      stockQty: data.stockQty.present ? data.stockQty.value : this.stockQty,
      supplierId:
          data.supplierId.present ? data.supplierId.value : this.supplierId,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      isFavourite:
          data.isFavourite.present ? data.isFavourite.value : this.isFavourite,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Product(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sku: $sku, ')
          ..write('barcode: $barcode, ')
          ..write('category: $category, ')
          ..write('unit: $unit, ')
          ..write('buyPrice: $buyPrice, ')
          ..write('sellPrice: $sellPrice, ')
          ..write('lowStockLevel: $lowStockLevel, ')
          ..write('stockQty: $stockQty, ')
          ..write('supplierId: $supplierId, ')
          ..write('imagePath: $imagePath, ')
          ..write('isFavourite: $isFavourite, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      sku,
      barcode,
      category,
      unit,
      buyPrice,
      sellPrice,
      lowStockLevel,
      stockQty,
      supplierId,
      imagePath,
      isFavourite,
      createdAt,
      updatedAt,
      deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Product &&
          other.id == this.id &&
          other.name == this.name &&
          other.sku == this.sku &&
          other.barcode == this.barcode &&
          other.category == this.category &&
          other.unit == this.unit &&
          other.buyPrice == this.buyPrice &&
          other.sellPrice == this.sellPrice &&
          other.lowStockLevel == this.lowStockLevel &&
          other.stockQty == this.stockQty &&
          other.supplierId == this.supplierId &&
          other.imagePath == this.imagePath &&
          other.isFavourite == this.isFavourite &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class ProductsCompanion extends UpdateCompanion<Product> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> sku;
  final Value<String?> barcode;
  final Value<String?> category;
  final Value<String> unit;
  final Value<double> buyPrice;
  final Value<double> sellPrice;
  final Value<int> lowStockLevel;
  final Value<int> stockQty;
  final Value<int?> supplierId;
  final Value<String?> imagePath;
  final Value<bool> isFavourite;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  const ProductsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sku = const Value.absent(),
    this.barcode = const Value.absent(),
    this.category = const Value.absent(),
    this.unit = const Value.absent(),
    this.buyPrice = const Value.absent(),
    this.sellPrice = const Value.absent(),
    this.lowStockLevel = const Value.absent(),
    this.stockQty = const Value.absent(),
    this.supplierId = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.isFavourite = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  ProductsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.sku = const Value.absent(),
    this.barcode = const Value.absent(),
    this.category = const Value.absent(),
    this.unit = const Value.absent(),
    this.buyPrice = const Value.absent(),
    this.sellPrice = const Value.absent(),
    this.lowStockLevel = const Value.absent(),
    this.stockQty = const Value.absent(),
    this.supplierId = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.isFavourite = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
  })  : name = Value(name),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<Product> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? sku,
    Expression<String>? barcode,
    Expression<String>? category,
    Expression<String>? unit,
    Expression<double>? buyPrice,
    Expression<double>? sellPrice,
    Expression<int>? lowStockLevel,
    Expression<int>? stockQty,
    Expression<int>? supplierId,
    Expression<String>? imagePath,
    Expression<bool>? isFavourite,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sku != null) 'sku': sku,
      if (barcode != null) 'barcode': barcode,
      if (category != null) 'category': category,
      if (unit != null) 'unit': unit,
      if (buyPrice != null) 'buy_price': buyPrice,
      if (sellPrice != null) 'sell_price': sellPrice,
      if (lowStockLevel != null) 'low_stock_level': lowStockLevel,
      if (stockQty != null) 'stock_qty': stockQty,
      if (supplierId != null) 'supplier_id': supplierId,
      if (imagePath != null) 'image_path': imagePath,
      if (isFavourite != null) 'is_favourite': isFavourite,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  ProductsCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String?>? sku,
      Value<String?>? barcode,
      Value<String?>? category,
      Value<String>? unit,
      Value<double>? buyPrice,
      Value<double>? sellPrice,
      Value<int>? lowStockLevel,
      Value<int>? stockQty,
      Value<int?>? supplierId,
      Value<String?>? imagePath,
      Value<bool>? isFavourite,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt}) {
    return ProductsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      buyPrice: buyPrice ?? this.buyPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      lowStockLevel: lowStockLevel ?? this.lowStockLevel,
      stockQty: stockQty ?? this.stockQty,
      supplierId: supplierId ?? this.supplierId,
      imagePath: imagePath ?? this.imagePath,
      isFavourite: isFavourite ?? this.isFavourite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sku.present) {
      map['sku'] = Variable<String>(sku.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (buyPrice.present) {
      map['buy_price'] = Variable<double>(buyPrice.value);
    }
    if (sellPrice.present) {
      map['sell_price'] = Variable<double>(sellPrice.value);
    }
    if (lowStockLevel.present) {
      map['low_stock_level'] = Variable<int>(lowStockLevel.value);
    }
    if (stockQty.present) {
      map['stock_qty'] = Variable<int>(stockQty.value);
    }
    if (supplierId.present) {
      map['supplier_id'] = Variable<int>(supplierId.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (isFavourite.present) {
      map['is_favourite'] = Variable<bool>(isFavourite.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sku: $sku, ')
          ..write('barcode: $barcode, ')
          ..write('category: $category, ')
          ..write('unit: $unit, ')
          ..write('buyPrice: $buyPrice, ')
          ..write('sellPrice: $sellPrice, ')
          ..write('lowStockLevel: $lowStockLevel, ')
          ..write('stockQty: $stockQty, ')
          ..write('supplierId: $supplierId, ')
          ..write('imagePath: $imagePath, ')
          ..write('isFavourite: $isFavourite, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $LocationsTable extends Locations
    with TableInfo<$LocationsTable, Location> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 100),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isDefaultMeta =
      const VerificationMeta('isDefault');
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
      'is_default', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_default" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, note, isDefault, createdAt, updatedAt, deletedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'location';
  @override
  VerificationContext validateIntegrity(Insertable<Location> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('is_default')) {
      context.handle(_isDefaultMeta,
          isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Location map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Location(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      isDefault: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_default'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $LocationsTable createAlias(String alias) {
    return $LocationsTable(attachedDatabase, alias);
  }
}

class Location extends DataClass implements Insertable<Location> {
  final int id;
  final String name;
  final String? note;

  /// Pre-selected for new movements. Exactly one row has this set; the
  /// migration gives it to the location holding the existing stock.
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Location(
      {required this.id,
      required this.name,
      this.note,
      required this.isDefault,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['is_default'] = Variable<bool>(isDefault);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  LocationsCompanion toCompanion(bool nullToAbsent) {
    return LocationsCompanion(
      id: Value(id),
      name: Value(name),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      isDefault: Value(isDefault),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Location.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Location(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      note: serializer.fromJson<String?>(json['note']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'note': serializer.toJson<String?>(note),
      'isDefault': serializer.toJson<bool>(isDefault),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Location copyWith(
          {int? id,
          String? name,
          Value<String?> note = const Value.absent(),
          bool? isDefault,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      Location(
        id: id ?? this.id,
        name: name ?? this.name,
        note: note.present ? note.value : this.note,
        isDefault: isDefault ?? this.isDefault,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  Location copyWithCompanion(LocationsCompanion data) {
    return Location(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      note: data.note.present ? data.note.value : this.note,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Location(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('note: $note, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, note, isDefault, createdAt, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Location &&
          other.id == this.id &&
          other.name == this.name &&
          other.note == this.note &&
          other.isDefault == this.isDefault &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class LocationsCompanion extends UpdateCompanion<Location> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> note;
  final Value<bool> isDefault;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  const LocationsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.note = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  LocationsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.note = const Value.absent(),
    this.isDefault = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
  })  : name = Value(name),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<Location> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? note,
    Expression<bool>? isDefault,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (note != null) 'note': note,
      if (isDefault != null) 'is_default': isDefault,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  LocationsCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String?>? note,
      Value<bool>? isDefault,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt}) {
    return LocationsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      note: note ?? this.note,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocationsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('note: $note, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $MovementsTable extends Movements
    with TableInfo<$MovementsTable, Movement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MovementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _productIdMeta =
      const VerificationMeta('productId');
  @override
  late final GeneratedColumn<int> productId = GeneratedColumn<int>(
      'product_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES product (id) ON DELETE CASCADE'));
  static const VerificationMeta _qtyDeltaMeta =
      const VerificationMeta('qtyDelta');
  @override
  late final GeneratedColumn<int> qtyDelta = GeneratedColumn<int>(
      'qty_delta', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
      'reason', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _auditSessionIdMeta =
      const VerificationMeta('auditSessionId');
  @override
  late final GeneratedColumn<int> auditSessionId = GeneratedColumn<int>(
      'audit_session_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _batchIdMeta =
      const VerificationMeta('batchId');
  @override
  late final GeneratedColumn<int> batchId = GeneratedColumn<int>(
      'batch_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _locationIdMeta =
      const VerificationMeta('locationId');
  @override
  late final GeneratedColumn<int> locationId = GeneratedColumn<int>(
      'location_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES location (id) ON DELETE SET NULL'));
  static const VerificationMeta _transferRefMeta =
      const VerificationMeta('transferRef');
  @override
  late final GeneratedColumn<String> transferRef = GeneratedColumn<String>(
      'transfer_ref', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _supplierIdMeta =
      const VerificationMeta('supplierId');
  @override
  late final GeneratedColumn<int> supplierId = GeneratedColumn<int>(
      'supplier_id', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES supplier (id) ON DELETE SET NULL'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        productId,
        qtyDelta,
        reason,
        note,
        auditSessionId,
        batchId,
        locationId,
        transferRef,
        supplierId,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'movement';
  @override
  VerificationContext validateIntegrity(Insertable<Movement> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('product_id')) {
      context.handle(_productIdMeta,
          productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta));
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('qty_delta')) {
      context.handle(_qtyDeltaMeta,
          qtyDelta.isAcceptableOrUnknown(data['qty_delta']!, _qtyDeltaMeta));
    } else if (isInserting) {
      context.missing(_qtyDeltaMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(_reasonMeta,
          reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta));
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('audit_session_id')) {
      context.handle(
          _auditSessionIdMeta,
          auditSessionId.isAcceptableOrUnknown(
              data['audit_session_id']!, _auditSessionIdMeta));
    }
    if (data.containsKey('batch_id')) {
      context.handle(_batchIdMeta,
          batchId.isAcceptableOrUnknown(data['batch_id']!, _batchIdMeta));
    }
    if (data.containsKey('location_id')) {
      context.handle(
          _locationIdMeta,
          locationId.isAcceptableOrUnknown(
              data['location_id']!, _locationIdMeta));
    }
    if (data.containsKey('transfer_ref')) {
      context.handle(
          _transferRefMeta,
          transferRef.isAcceptableOrUnknown(
              data['transfer_ref']!, _transferRefMeta));
    }
    if (data.containsKey('supplier_id')) {
      context.handle(
          _supplierIdMeta,
          supplierId.isAcceptableOrUnknown(
              data['supplier_id']!, _supplierIdMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Movement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Movement(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      productId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}product_id'])!,
      qtyDelta: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}qty_delta'])!,
      reason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reason'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      auditSessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}audit_session_id']),
      batchId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}batch_id']),
      locationId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}location_id']),
      transferRef: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}transfer_ref']),
      supplierId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}supplier_id']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $MovementsTable createAlias(String alias) {
    return $MovementsTable(attachedDatabase, alias);
  }
}

class Movement extends DataClass implements Insertable<Movement> {
  final int id;
  final int productId;
  final int qtyDelta;
  final String reason;
  final String? note;
  final int? auditSessionId;
  final int? batchId;

  /// Where this movement happened.
  ///
  /// Nullable only so the v6 migration can add the column before backfilling
  /// it; every row written by the app carries one. Stock at a location is
  /// SUM(qty_delta) filtered by it, exactly as product stock is SUM over all
  /// locations — so the existing invariant is unchanged, just partitioned.
  final int? locationId;

  /// Links the two halves of a transfer.
  ///
  /// A transfer is -n at the source and +n at the destination, written in one
  /// transaction. Odoo models this as a single move with a source and a
  /// destination; with a signed-delta ledger the equivalent is a matched
  /// pair, and this reference is what makes the pair recognisable — so a
  /// transfer can be shown as one event and never half-applied.
  final String? transferRef;
  final int? supplierId;
  final DateTime createdAt;
  const Movement(
      {required this.id,
      required this.productId,
      required this.qtyDelta,
      required this.reason,
      this.note,
      this.auditSessionId,
      this.batchId,
      this.locationId,
      this.transferRef,
      this.supplierId,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['product_id'] = Variable<int>(productId);
    map['qty_delta'] = Variable<int>(qtyDelta);
    map['reason'] = Variable<String>(reason);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || auditSessionId != null) {
      map['audit_session_id'] = Variable<int>(auditSessionId);
    }
    if (!nullToAbsent || batchId != null) {
      map['batch_id'] = Variable<int>(batchId);
    }
    if (!nullToAbsent || locationId != null) {
      map['location_id'] = Variable<int>(locationId);
    }
    if (!nullToAbsent || transferRef != null) {
      map['transfer_ref'] = Variable<String>(transferRef);
    }
    if (!nullToAbsent || supplierId != null) {
      map['supplier_id'] = Variable<int>(supplierId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MovementsCompanion toCompanion(bool nullToAbsent) {
    return MovementsCompanion(
      id: Value(id),
      productId: Value(productId),
      qtyDelta: Value(qtyDelta),
      reason: Value(reason),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      auditSessionId: auditSessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(auditSessionId),
      batchId: batchId == null && nullToAbsent
          ? const Value.absent()
          : Value(batchId),
      locationId: locationId == null && nullToAbsent
          ? const Value.absent()
          : Value(locationId),
      transferRef: transferRef == null && nullToAbsent
          ? const Value.absent()
          : Value(transferRef),
      supplierId: supplierId == null && nullToAbsent
          ? const Value.absent()
          : Value(supplierId),
      createdAt: Value(createdAt),
    );
  }

  factory Movement.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Movement(
      id: serializer.fromJson<int>(json['id']),
      productId: serializer.fromJson<int>(json['productId']),
      qtyDelta: serializer.fromJson<int>(json['qtyDelta']),
      reason: serializer.fromJson<String>(json['reason']),
      note: serializer.fromJson<String?>(json['note']),
      auditSessionId: serializer.fromJson<int?>(json['auditSessionId']),
      batchId: serializer.fromJson<int?>(json['batchId']),
      locationId: serializer.fromJson<int?>(json['locationId']),
      transferRef: serializer.fromJson<String?>(json['transferRef']),
      supplierId: serializer.fromJson<int?>(json['supplierId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'productId': serializer.toJson<int>(productId),
      'qtyDelta': serializer.toJson<int>(qtyDelta),
      'reason': serializer.toJson<String>(reason),
      'note': serializer.toJson<String?>(note),
      'auditSessionId': serializer.toJson<int?>(auditSessionId),
      'batchId': serializer.toJson<int?>(batchId),
      'locationId': serializer.toJson<int?>(locationId),
      'transferRef': serializer.toJson<String?>(transferRef),
      'supplierId': serializer.toJson<int?>(supplierId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Movement copyWith(
          {int? id,
          int? productId,
          int? qtyDelta,
          String? reason,
          Value<String?> note = const Value.absent(),
          Value<int?> auditSessionId = const Value.absent(),
          Value<int?> batchId = const Value.absent(),
          Value<int?> locationId = const Value.absent(),
          Value<String?> transferRef = const Value.absent(),
          Value<int?> supplierId = const Value.absent(),
          DateTime? createdAt}) =>
      Movement(
        id: id ?? this.id,
        productId: productId ?? this.productId,
        qtyDelta: qtyDelta ?? this.qtyDelta,
        reason: reason ?? this.reason,
        note: note.present ? note.value : this.note,
        auditSessionId:
            auditSessionId.present ? auditSessionId.value : this.auditSessionId,
        batchId: batchId.present ? batchId.value : this.batchId,
        locationId: locationId.present ? locationId.value : this.locationId,
        transferRef: transferRef.present ? transferRef.value : this.transferRef,
        supplierId: supplierId.present ? supplierId.value : this.supplierId,
        createdAt: createdAt ?? this.createdAt,
      );
  Movement copyWithCompanion(MovementsCompanion data) {
    return Movement(
      id: data.id.present ? data.id.value : this.id,
      productId: data.productId.present ? data.productId.value : this.productId,
      qtyDelta: data.qtyDelta.present ? data.qtyDelta.value : this.qtyDelta,
      reason: data.reason.present ? data.reason.value : this.reason,
      note: data.note.present ? data.note.value : this.note,
      auditSessionId: data.auditSessionId.present
          ? data.auditSessionId.value
          : this.auditSessionId,
      batchId: data.batchId.present ? data.batchId.value : this.batchId,
      locationId:
          data.locationId.present ? data.locationId.value : this.locationId,
      transferRef:
          data.transferRef.present ? data.transferRef.value : this.transferRef,
      supplierId:
          data.supplierId.present ? data.supplierId.value : this.supplierId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Movement(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('qtyDelta: $qtyDelta, ')
          ..write('reason: $reason, ')
          ..write('note: $note, ')
          ..write('auditSessionId: $auditSessionId, ')
          ..write('batchId: $batchId, ')
          ..write('locationId: $locationId, ')
          ..write('transferRef: $transferRef, ')
          ..write('supplierId: $supplierId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, productId, qtyDelta, reason, note,
      auditSessionId, batchId, locationId, transferRef, supplierId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Movement &&
          other.id == this.id &&
          other.productId == this.productId &&
          other.qtyDelta == this.qtyDelta &&
          other.reason == this.reason &&
          other.note == this.note &&
          other.auditSessionId == this.auditSessionId &&
          other.batchId == this.batchId &&
          other.locationId == this.locationId &&
          other.transferRef == this.transferRef &&
          other.supplierId == this.supplierId &&
          other.createdAt == this.createdAt);
}

class MovementsCompanion extends UpdateCompanion<Movement> {
  final Value<int> id;
  final Value<int> productId;
  final Value<int> qtyDelta;
  final Value<String> reason;
  final Value<String?> note;
  final Value<int?> auditSessionId;
  final Value<int?> batchId;
  final Value<int?> locationId;
  final Value<String?> transferRef;
  final Value<int?> supplierId;
  final Value<DateTime> createdAt;
  const MovementsCompanion({
    this.id = const Value.absent(),
    this.productId = const Value.absent(),
    this.qtyDelta = const Value.absent(),
    this.reason = const Value.absent(),
    this.note = const Value.absent(),
    this.auditSessionId = const Value.absent(),
    this.batchId = const Value.absent(),
    this.locationId = const Value.absent(),
    this.transferRef = const Value.absent(),
    this.supplierId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  MovementsCompanion.insert({
    this.id = const Value.absent(),
    required int productId,
    required int qtyDelta,
    required String reason,
    this.note = const Value.absent(),
    this.auditSessionId = const Value.absent(),
    this.batchId = const Value.absent(),
    this.locationId = const Value.absent(),
    this.transferRef = const Value.absent(),
    this.supplierId = const Value.absent(),
    required DateTime createdAt,
  })  : productId = Value(productId),
        qtyDelta = Value(qtyDelta),
        reason = Value(reason),
        createdAt = Value(createdAt);
  static Insertable<Movement> custom({
    Expression<int>? id,
    Expression<int>? productId,
    Expression<int>? qtyDelta,
    Expression<String>? reason,
    Expression<String>? note,
    Expression<int>? auditSessionId,
    Expression<int>? batchId,
    Expression<int>? locationId,
    Expression<String>? transferRef,
    Expression<int>? supplierId,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      if (qtyDelta != null) 'qty_delta': qtyDelta,
      if (reason != null) 'reason': reason,
      if (note != null) 'note': note,
      if (auditSessionId != null) 'audit_session_id': auditSessionId,
      if (batchId != null) 'batch_id': batchId,
      if (locationId != null) 'location_id': locationId,
      if (transferRef != null) 'transfer_ref': transferRef,
      if (supplierId != null) 'supplier_id': supplierId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  MovementsCompanion copyWith(
      {Value<int>? id,
      Value<int>? productId,
      Value<int>? qtyDelta,
      Value<String>? reason,
      Value<String?>? note,
      Value<int?>? auditSessionId,
      Value<int?>? batchId,
      Value<int?>? locationId,
      Value<String?>? transferRef,
      Value<int?>? supplierId,
      Value<DateTime>? createdAt}) {
    return MovementsCompanion(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      qtyDelta: qtyDelta ?? this.qtyDelta,
      reason: reason ?? this.reason,
      note: note ?? this.note,
      auditSessionId: auditSessionId ?? this.auditSessionId,
      batchId: batchId ?? this.batchId,
      locationId: locationId ?? this.locationId,
      transferRef: transferRef ?? this.transferRef,
      supplierId: supplierId ?? this.supplierId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<int>(productId.value);
    }
    if (qtyDelta.present) {
      map['qty_delta'] = Variable<int>(qtyDelta.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (auditSessionId.present) {
      map['audit_session_id'] = Variable<int>(auditSessionId.value);
    }
    if (batchId.present) {
      map['batch_id'] = Variable<int>(batchId.value);
    }
    if (locationId.present) {
      map['location_id'] = Variable<int>(locationId.value);
    }
    if (transferRef.present) {
      map['transfer_ref'] = Variable<String>(transferRef.value);
    }
    if (supplierId.present) {
      map['supplier_id'] = Variable<int>(supplierId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MovementsCompanion(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('qtyDelta: $qtyDelta, ')
          ..write('reason: $reason, ')
          ..write('note: $note, ')
          ..write('auditSessionId: $auditSessionId, ')
          ..write('batchId: $batchId, ')
          ..write('locationId: $locationId, ')
          ..write('transferRef: $transferRef, ')
          ..write('supplierId: $supplierId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'setting';
  @override
  VerificationContext validateIntegrity(Insertable<Setting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory Setting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) => Setting(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StockAuditSessionsTable extends StockAuditSessions
    with TableInfo<$StockAuditSessionsTable, StockAuditSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockAuditSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 100),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('in_progress'));
  static const VerificationMeta _auditModeMeta =
      const VerificationMeta('auditMode');
  @override
  late final GeneratedColumn<String> auditMode = GeneratedColumn<String>(
      'audit_mode', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('transparent'));
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
      'started_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
      'completed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _totalItemsCountedMeta =
      const VerificationMeta('totalItemsCounted');
  @override
  late final GeneratedColumn<int> totalItemsCounted = GeneratedColumn<int>(
      'total_items_counted', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _totalDiscrepanciesMeta =
      const VerificationMeta('totalDiscrepancies');
  @override
  late final GeneratedColumn<int> totalDiscrepancies = GeneratedColumn<int>(
      'total_discrepancies', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _netDiscrepancyValueMeta =
      const VerificationMeta('netDiscrepancyValue');
  @override
  late final GeneratedColumn<double> netDiscrepancyValue =
      GeneratedColumn<double>('net_discrepancy_value', aliasedName, false,
          type: DriftSqlType.double,
          requiredDuringInsert: false,
          defaultValue: const Constant(0));
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        status,
        auditMode,
        startedAt,
        completedAt,
        totalItemsCounted,
        totalDiscrepancies,
        netDiscrepancyValue,
        notes
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_audit_session';
  @override
  VerificationContext validateIntegrity(Insertable<StockAuditSession> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('audit_mode')) {
      context.handle(_auditModeMeta,
          auditMode.isAcceptableOrUnknown(data['audit_mode']!, _auditModeMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    }
    if (data.containsKey('total_items_counted')) {
      context.handle(
          _totalItemsCountedMeta,
          totalItemsCounted.isAcceptableOrUnknown(
              data['total_items_counted']!, _totalItemsCountedMeta));
    }
    if (data.containsKey('total_discrepancies')) {
      context.handle(
          _totalDiscrepanciesMeta,
          totalDiscrepancies.isAcceptableOrUnknown(
              data['total_discrepancies']!, _totalDiscrepanciesMeta));
    }
    if (data.containsKey('net_discrepancy_value')) {
      context.handle(
          _netDiscrepancyValueMeta,
          netDiscrepancyValue.isAcceptableOrUnknown(
              data['net_discrepancy_value']!, _netDiscrepancyValueMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StockAuditSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockAuditSession(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      auditMode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}audit_mode'])!,
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}started_at'])!,
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}completed_at']),
      totalItemsCounted: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}total_items_counted'])!,
      totalDiscrepancies: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}total_discrepancies'])!,
      netDiscrepancyValue: attachedDatabase.typeMapping.read(
          DriftSqlType.double,
          data['${effectivePrefix}net_discrepancy_value'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
    );
  }

  @override
  $StockAuditSessionsTable createAlias(String alias) {
    return $StockAuditSessionsTable(attachedDatabase, alias);
  }
}

class StockAuditSession extends DataClass
    implements Insertable<StockAuditSession> {
  final int id;
  final String name;
  final String status;
  final String auditMode;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int totalItemsCounted;
  final int totalDiscrepancies;
  final double netDiscrepancyValue;
  final String? notes;
  const StockAuditSession(
      {required this.id,
      required this.name,
      required this.status,
      required this.auditMode,
      required this.startedAt,
      this.completedAt,
      required this.totalItemsCounted,
      required this.totalDiscrepancies,
      required this.netDiscrepancyValue,
      this.notes});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['status'] = Variable<String>(status);
    map['audit_mode'] = Variable<String>(auditMode);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['total_items_counted'] = Variable<int>(totalItemsCounted);
    map['total_discrepancies'] = Variable<int>(totalDiscrepancies);
    map['net_discrepancy_value'] = Variable<double>(netDiscrepancyValue);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  StockAuditSessionsCompanion toCompanion(bool nullToAbsent) {
    return StockAuditSessionsCompanion(
      id: Value(id),
      name: Value(name),
      status: Value(status),
      auditMode: Value(auditMode),
      startedAt: Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      totalItemsCounted: Value(totalItemsCounted),
      totalDiscrepancies: Value(totalDiscrepancies),
      netDiscrepancyValue: Value(netDiscrepancyValue),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
    );
  }

  factory StockAuditSession.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockAuditSession(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      status: serializer.fromJson<String>(json['status']),
      auditMode: serializer.fromJson<String>(json['auditMode']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      totalItemsCounted: serializer.fromJson<int>(json['totalItemsCounted']),
      totalDiscrepancies: serializer.fromJson<int>(json['totalDiscrepancies']),
      netDiscrepancyValue:
          serializer.fromJson<double>(json['netDiscrepancyValue']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'status': serializer.toJson<String>(status),
      'auditMode': serializer.toJson<String>(auditMode),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'totalItemsCounted': serializer.toJson<int>(totalItemsCounted),
      'totalDiscrepancies': serializer.toJson<int>(totalDiscrepancies),
      'netDiscrepancyValue': serializer.toJson<double>(netDiscrepancyValue),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  StockAuditSession copyWith(
          {int? id,
          String? name,
          String? status,
          String? auditMode,
          DateTime? startedAt,
          Value<DateTime?> completedAt = const Value.absent(),
          int? totalItemsCounted,
          int? totalDiscrepancies,
          double? netDiscrepancyValue,
          Value<String?> notes = const Value.absent()}) =>
      StockAuditSession(
        id: id ?? this.id,
        name: name ?? this.name,
        status: status ?? this.status,
        auditMode: auditMode ?? this.auditMode,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt.present ? completedAt.value : this.completedAt,
        totalItemsCounted: totalItemsCounted ?? this.totalItemsCounted,
        totalDiscrepancies: totalDiscrepancies ?? this.totalDiscrepancies,
        netDiscrepancyValue: netDiscrepancyValue ?? this.netDiscrepancyValue,
        notes: notes.present ? notes.value : this.notes,
      );
  StockAuditSession copyWithCompanion(StockAuditSessionsCompanion data) {
    return StockAuditSession(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      status: data.status.present ? data.status.value : this.status,
      auditMode: data.auditMode.present ? data.auditMode.value : this.auditMode,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
      totalItemsCounted: data.totalItemsCounted.present
          ? data.totalItemsCounted.value
          : this.totalItemsCounted,
      totalDiscrepancies: data.totalDiscrepancies.present
          ? data.totalDiscrepancies.value
          : this.totalDiscrepancies,
      netDiscrepancyValue: data.netDiscrepancyValue.present
          ? data.netDiscrepancyValue.value
          : this.netDiscrepancyValue,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockAuditSession(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('auditMode: $auditMode, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('totalItemsCounted: $totalItemsCounted, ')
          ..write('totalDiscrepancies: $totalDiscrepancies, ')
          ..write('netDiscrepancyValue: $netDiscrepancyValue, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      status,
      auditMode,
      startedAt,
      completedAt,
      totalItemsCounted,
      totalDiscrepancies,
      netDiscrepancyValue,
      notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockAuditSession &&
          other.id == this.id &&
          other.name == this.name &&
          other.status == this.status &&
          other.auditMode == this.auditMode &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.totalItemsCounted == this.totalItemsCounted &&
          other.totalDiscrepancies == this.totalDiscrepancies &&
          other.netDiscrepancyValue == this.netDiscrepancyValue &&
          other.notes == this.notes);
}

class StockAuditSessionsCompanion extends UpdateCompanion<StockAuditSession> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> status;
  final Value<String> auditMode;
  final Value<DateTime> startedAt;
  final Value<DateTime?> completedAt;
  final Value<int> totalItemsCounted;
  final Value<int> totalDiscrepancies;
  final Value<double> netDiscrepancyValue;
  final Value<String?> notes;
  const StockAuditSessionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.status = const Value.absent(),
    this.auditMode = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.totalItemsCounted = const Value.absent(),
    this.totalDiscrepancies = const Value.absent(),
    this.netDiscrepancyValue = const Value.absent(),
    this.notes = const Value.absent(),
  });
  StockAuditSessionsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.status = const Value.absent(),
    this.auditMode = const Value.absent(),
    required DateTime startedAt,
    this.completedAt = const Value.absent(),
    this.totalItemsCounted = const Value.absent(),
    this.totalDiscrepancies = const Value.absent(),
    this.netDiscrepancyValue = const Value.absent(),
    this.notes = const Value.absent(),
  })  : name = Value(name),
        startedAt = Value(startedAt);
  static Insertable<StockAuditSession> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? status,
    Expression<String>? auditMode,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
    Expression<int>? totalItemsCounted,
    Expression<int>? totalDiscrepancies,
    Expression<double>? netDiscrepancyValue,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (status != null) 'status': status,
      if (auditMode != null) 'audit_mode': auditMode,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (totalItemsCounted != null) 'total_items_counted': totalItemsCounted,
      if (totalDiscrepancies != null) 'total_discrepancies': totalDiscrepancies,
      if (netDiscrepancyValue != null)
        'net_discrepancy_value': netDiscrepancyValue,
      if (notes != null) 'notes': notes,
    });
  }

  StockAuditSessionsCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String>? status,
      Value<String>? auditMode,
      Value<DateTime>? startedAt,
      Value<DateTime?>? completedAt,
      Value<int>? totalItemsCounted,
      Value<int>? totalDiscrepancies,
      Value<double>? netDiscrepancyValue,
      Value<String?>? notes}) {
    return StockAuditSessionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      auditMode: auditMode ?? this.auditMode,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      totalItemsCounted: totalItemsCounted ?? this.totalItemsCounted,
      totalDiscrepancies: totalDiscrepancies ?? this.totalDiscrepancies,
      netDiscrepancyValue: netDiscrepancyValue ?? this.netDiscrepancyValue,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (auditMode.present) {
      map['audit_mode'] = Variable<String>(auditMode.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (totalItemsCounted.present) {
      map['total_items_counted'] = Variable<int>(totalItemsCounted.value);
    }
    if (totalDiscrepancies.present) {
      map['total_discrepancies'] = Variable<int>(totalDiscrepancies.value);
    }
    if (netDiscrepancyValue.present) {
      map['net_discrepancy_value'] =
          Variable<double>(netDiscrepancyValue.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockAuditSessionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('auditMode: $auditMode, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('totalItemsCounted: $totalItemsCounted, ')
          ..write('totalDiscrepancies: $totalDiscrepancies, ')
          ..write('netDiscrepancyValue: $netDiscrepancyValue, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $StockAuditItemsTable extends StockAuditItems
    with TableInfo<$StockAuditItemsTable, StockAuditItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StockAuditItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
      'session_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES stock_audit_session (id) ON DELETE CASCADE'));
  static const VerificationMeta _productIdMeta =
      const VerificationMeta('productId');
  @override
  late final GeneratedColumn<int> productId = GeneratedColumn<int>(
      'product_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES product (id) ON DELETE CASCADE'));
  static const VerificationMeta _expectedQtyMeta =
      const VerificationMeta('expectedQty');
  @override
  late final GeneratedColumn<int> expectedQty = GeneratedColumn<int>(
      'expected_qty', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _countedQtyMeta =
      const VerificationMeta('countedQty');
  @override
  late final GeneratedColumn<int> countedQty = GeneratedColumn<int>(
      'counted_qty', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _differenceMeta =
      const VerificationMeta('difference');
  @override
  late final GeneratedColumn<int> difference = GeneratedColumn<int>(
      'difference', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _isReconciledMeta =
      const VerificationMeta('isReconciled');
  @override
  late final GeneratedColumn<bool> isReconciled = GeneratedColumn<bool>(
      'is_reconciled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_reconciled" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _reconciledAtMeta =
      const VerificationMeta('reconciledAt');
  @override
  late final GeneratedColumn<DateTime> reconciledAt = GeneratedColumn<DateTime>(
      'reconciled_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sessionId,
        productId,
        expectedQty,
        countedQty,
        difference,
        isReconciled,
        reconciledAt,
        notes,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stock_audit_item';
  @override
  VerificationContext validateIntegrity(Insertable<StockAuditItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(_productIdMeta,
          productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta));
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('expected_qty')) {
      context.handle(
          _expectedQtyMeta,
          expectedQty.isAcceptableOrUnknown(
              data['expected_qty']!, _expectedQtyMeta));
    } else if (isInserting) {
      context.missing(_expectedQtyMeta);
    }
    if (data.containsKey('counted_qty')) {
      context.handle(
          _countedQtyMeta,
          countedQty.isAcceptableOrUnknown(
              data['counted_qty']!, _countedQtyMeta));
    } else if (isInserting) {
      context.missing(_countedQtyMeta);
    }
    if (data.containsKey('difference')) {
      context.handle(
          _differenceMeta,
          difference.isAcceptableOrUnknown(
              data['difference']!, _differenceMeta));
    } else if (isInserting) {
      context.missing(_differenceMeta);
    }
    if (data.containsKey('is_reconciled')) {
      context.handle(
          _isReconciledMeta,
          isReconciled.isAcceptableOrUnknown(
              data['is_reconciled']!, _isReconciledMeta));
    }
    if (data.containsKey('reconciled_at')) {
      context.handle(
          _reconciledAtMeta,
          reconciledAt.isAcceptableOrUnknown(
              data['reconciled_at']!, _reconciledAtMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StockAuditItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StockAuditItem(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}session_id'])!,
      productId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}product_id'])!,
      expectedQty: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}expected_qty'])!,
      countedQty: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}counted_qty'])!,
      difference: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}difference'])!,
      isReconciled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_reconciled'])!,
      reconciledAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}reconciled_at']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $StockAuditItemsTable createAlias(String alias) {
    return $StockAuditItemsTable(attachedDatabase, alias);
  }
}

class StockAuditItem extends DataClass implements Insertable<StockAuditItem> {
  final int id;
  final int sessionId;
  final int productId;
  final int expectedQty;
  final int countedQty;
  final int difference;
  final bool isReconciled;
  final DateTime? reconciledAt;
  final String? notes;
  final DateTime updatedAt;
  const StockAuditItem(
      {required this.id,
      required this.sessionId,
      required this.productId,
      required this.expectedQty,
      required this.countedQty,
      required this.difference,
      required this.isReconciled,
      this.reconciledAt,
      this.notes,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<int>(sessionId);
    map['product_id'] = Variable<int>(productId);
    map['expected_qty'] = Variable<int>(expectedQty);
    map['counted_qty'] = Variable<int>(countedQty);
    map['difference'] = Variable<int>(difference);
    map['is_reconciled'] = Variable<bool>(isReconciled);
    if (!nullToAbsent || reconciledAt != null) {
      map['reconciled_at'] = Variable<DateTime>(reconciledAt);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StockAuditItemsCompanion toCompanion(bool nullToAbsent) {
    return StockAuditItemsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      productId: Value(productId),
      expectedQty: Value(expectedQty),
      countedQty: Value(countedQty),
      difference: Value(difference),
      isReconciled: Value(isReconciled),
      reconciledAt: reconciledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(reconciledAt),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      updatedAt: Value(updatedAt),
    );
  }

  factory StockAuditItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StockAuditItem(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      productId: serializer.fromJson<int>(json['productId']),
      expectedQty: serializer.fromJson<int>(json['expectedQty']),
      countedQty: serializer.fromJson<int>(json['countedQty']),
      difference: serializer.fromJson<int>(json['difference']),
      isReconciled: serializer.fromJson<bool>(json['isReconciled']),
      reconciledAt: serializer.fromJson<DateTime?>(json['reconciledAt']),
      notes: serializer.fromJson<String?>(json['notes']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int>(sessionId),
      'productId': serializer.toJson<int>(productId),
      'expectedQty': serializer.toJson<int>(expectedQty),
      'countedQty': serializer.toJson<int>(countedQty),
      'difference': serializer.toJson<int>(difference),
      'isReconciled': serializer.toJson<bool>(isReconciled),
      'reconciledAt': serializer.toJson<DateTime?>(reconciledAt),
      'notes': serializer.toJson<String?>(notes),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StockAuditItem copyWith(
          {int? id,
          int? sessionId,
          int? productId,
          int? expectedQty,
          int? countedQty,
          int? difference,
          bool? isReconciled,
          Value<DateTime?> reconciledAt = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          DateTime? updatedAt}) =>
      StockAuditItem(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        productId: productId ?? this.productId,
        expectedQty: expectedQty ?? this.expectedQty,
        countedQty: countedQty ?? this.countedQty,
        difference: difference ?? this.difference,
        isReconciled: isReconciled ?? this.isReconciled,
        reconciledAt:
            reconciledAt.present ? reconciledAt.value : this.reconciledAt,
        notes: notes.present ? notes.value : this.notes,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  StockAuditItem copyWithCompanion(StockAuditItemsCompanion data) {
    return StockAuditItem(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      productId: data.productId.present ? data.productId.value : this.productId,
      expectedQty:
          data.expectedQty.present ? data.expectedQty.value : this.expectedQty,
      countedQty:
          data.countedQty.present ? data.countedQty.value : this.countedQty,
      difference:
          data.difference.present ? data.difference.value : this.difference,
      isReconciled: data.isReconciled.present
          ? data.isReconciled.value
          : this.isReconciled,
      reconciledAt: data.reconciledAt.present
          ? data.reconciledAt.value
          : this.reconciledAt,
      notes: data.notes.present ? data.notes.value : this.notes,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StockAuditItem(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('productId: $productId, ')
          ..write('expectedQty: $expectedQty, ')
          ..write('countedQty: $countedQty, ')
          ..write('difference: $difference, ')
          ..write('isReconciled: $isReconciled, ')
          ..write('reconciledAt: $reconciledAt, ')
          ..write('notes: $notes, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, productId, expectedQty,
      countedQty, difference, isReconciled, reconciledAt, notes, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockAuditItem &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.productId == this.productId &&
          other.expectedQty == this.expectedQty &&
          other.countedQty == this.countedQty &&
          other.difference == this.difference &&
          other.isReconciled == this.isReconciled &&
          other.reconciledAt == this.reconciledAt &&
          other.notes == this.notes &&
          other.updatedAt == this.updatedAt);
}

class StockAuditItemsCompanion extends UpdateCompanion<StockAuditItem> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<int> productId;
  final Value<int> expectedQty;
  final Value<int> countedQty;
  final Value<int> difference;
  final Value<bool> isReconciled;
  final Value<DateTime?> reconciledAt;
  final Value<String?> notes;
  final Value<DateTime> updatedAt;
  const StockAuditItemsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.productId = const Value.absent(),
    this.expectedQty = const Value.absent(),
    this.countedQty = const Value.absent(),
    this.difference = const Value.absent(),
    this.isReconciled = const Value.absent(),
    this.reconciledAt = const Value.absent(),
    this.notes = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  StockAuditItemsCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    required int productId,
    required int expectedQty,
    required int countedQty,
    required int difference,
    this.isReconciled = const Value.absent(),
    this.reconciledAt = const Value.absent(),
    this.notes = const Value.absent(),
    required DateTime updatedAt,
  })  : sessionId = Value(sessionId),
        productId = Value(productId),
        expectedQty = Value(expectedQty),
        countedQty = Value(countedQty),
        difference = Value(difference),
        updatedAt = Value(updatedAt);
  static Insertable<StockAuditItem> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<int>? productId,
    Expression<int>? expectedQty,
    Expression<int>? countedQty,
    Expression<int>? difference,
    Expression<bool>? isReconciled,
    Expression<DateTime>? reconciledAt,
    Expression<String>? notes,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (productId != null) 'product_id': productId,
      if (expectedQty != null) 'expected_qty': expectedQty,
      if (countedQty != null) 'counted_qty': countedQty,
      if (difference != null) 'difference': difference,
      if (isReconciled != null) 'is_reconciled': isReconciled,
      if (reconciledAt != null) 'reconciled_at': reconciledAt,
      if (notes != null) 'notes': notes,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  StockAuditItemsCompanion copyWith(
      {Value<int>? id,
      Value<int>? sessionId,
      Value<int>? productId,
      Value<int>? expectedQty,
      Value<int>? countedQty,
      Value<int>? difference,
      Value<bool>? isReconciled,
      Value<DateTime?>? reconciledAt,
      Value<String?>? notes,
      Value<DateTime>? updatedAt}) {
    return StockAuditItemsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      productId: productId ?? this.productId,
      expectedQty: expectedQty ?? this.expectedQty,
      countedQty: countedQty ?? this.countedQty,
      difference: difference ?? this.difference,
      isReconciled: isReconciled ?? this.isReconciled,
      reconciledAt: reconciledAt ?? this.reconciledAt,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<int>(productId.value);
    }
    if (expectedQty.present) {
      map['expected_qty'] = Variable<int>(expectedQty.value);
    }
    if (countedQty.present) {
      map['counted_qty'] = Variable<int>(countedQty.value);
    }
    if (difference.present) {
      map['difference'] = Variable<int>(difference.value);
    }
    if (isReconciled.present) {
      map['is_reconciled'] = Variable<bool>(isReconciled.value);
    }
    if (reconciledAt.present) {
      map['reconciled_at'] = Variable<DateTime>(reconciledAt.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StockAuditItemsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('productId: $productId, ')
          ..write('expectedQty: $expectedQty, ')
          ..write('countedQty: $countedQty, ')
          ..write('difference: $difference, ')
          ..write('isReconciled: $isReconciled, ')
          ..write('reconciledAt: $reconciledAt, ')
          ..write('notes: $notes, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $BatchesTable extends Batches
    with TableInfo<$BatchesTable, ProductBatch> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _productIdMeta =
      const VerificationMeta('productId');
  @override
  late final GeneratedColumn<int> productId = GeneratedColumn<int>(
      'product_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES product (id) ON DELETE CASCADE'));
  static const VerificationMeta _batchNumberMeta =
      const VerificationMeta('batchNumber');
  @override
  late final GeneratedColumn<String> batchNumber = GeneratedColumn<String>(
      'batch_number', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 100),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _expiryDateMeta =
      const VerificationMeta('expiryDate');
  @override
  late final GeneratedColumn<DateTime> expiryDate = GeneratedColumn<DateTime>(
      'expiry_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _stockQtyMeta =
      const VerificationMeta('stockQty');
  @override
  late final GeneratedColumn<int> stockQty = GeneratedColumn<int>(
      'stock_qty', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        productId,
        batchNumber,
        expiryDate,
        stockQty,
        createdAt,
        updatedAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'batch';
  @override
  VerificationContext validateIntegrity(Insertable<ProductBatch> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('product_id')) {
      context.handle(_productIdMeta,
          productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta));
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('batch_number')) {
      context.handle(
          _batchNumberMeta,
          batchNumber.isAcceptableOrUnknown(
              data['batch_number']!, _batchNumberMeta));
    } else if (isInserting) {
      context.missing(_batchNumberMeta);
    }
    if (data.containsKey('expiry_date')) {
      context.handle(
          _expiryDateMeta,
          expiryDate.isAcceptableOrUnknown(
              data['expiry_date']!, _expiryDateMeta));
    }
    if (data.containsKey('stock_qty')) {
      context.handle(_stockQtyMeta,
          stockQty.isAcceptableOrUnknown(data['stock_qty']!, _stockQtyMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProductBatch map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProductBatch(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      productId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}product_id'])!,
      batchNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}batch_number'])!,
      expiryDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}expiry_date']),
      stockQty: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}stock_qty'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $BatchesTable createAlias(String alias) {
    return $BatchesTable(attachedDatabase, alias);
  }
}

class ProductBatch extends DataClass implements Insertable<ProductBatch> {
  final int id;
  final int productId;
  final String batchNumber;
  final DateTime? expiryDate;

  /// Rebuildable cache of the batch's ledger total. Never authoritative.
  final int stockQty;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Soft delete, as everywhere else. Hard-deleting a batch orphaned the
  /// `batch_id` on movements that are, by design, never deleted.
  final DateTime? deletedAt;
  const ProductBatch(
      {required this.id,
      required this.productId,
      required this.batchNumber,
      this.expiryDate,
      required this.stockQty,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['product_id'] = Variable<int>(productId);
    map['batch_number'] = Variable<String>(batchNumber);
    if (!nullToAbsent || expiryDate != null) {
      map['expiry_date'] = Variable<DateTime>(expiryDate);
    }
    map['stock_qty'] = Variable<int>(stockQty);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  BatchesCompanion toCompanion(bool nullToAbsent) {
    return BatchesCompanion(
      id: Value(id),
      productId: Value(productId),
      batchNumber: Value(batchNumber),
      expiryDate: expiryDate == null && nullToAbsent
          ? const Value.absent()
          : Value(expiryDate),
      stockQty: Value(stockQty),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory ProductBatch.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProductBatch(
      id: serializer.fromJson<int>(json['id']),
      productId: serializer.fromJson<int>(json['productId']),
      batchNumber: serializer.fromJson<String>(json['batchNumber']),
      expiryDate: serializer.fromJson<DateTime?>(json['expiryDate']),
      stockQty: serializer.fromJson<int>(json['stockQty']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'productId': serializer.toJson<int>(productId),
      'batchNumber': serializer.toJson<String>(batchNumber),
      'expiryDate': serializer.toJson<DateTime?>(expiryDate),
      'stockQty': serializer.toJson<int>(stockQty),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  ProductBatch copyWith(
          {int? id,
          int? productId,
          String? batchNumber,
          Value<DateTime?> expiryDate = const Value.absent(),
          int? stockQty,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      ProductBatch(
        id: id ?? this.id,
        productId: productId ?? this.productId,
        batchNumber: batchNumber ?? this.batchNumber,
        expiryDate: expiryDate.present ? expiryDate.value : this.expiryDate,
        stockQty: stockQty ?? this.stockQty,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  ProductBatch copyWithCompanion(BatchesCompanion data) {
    return ProductBatch(
      id: data.id.present ? data.id.value : this.id,
      productId: data.productId.present ? data.productId.value : this.productId,
      batchNumber:
          data.batchNumber.present ? data.batchNumber.value : this.batchNumber,
      expiryDate:
          data.expiryDate.present ? data.expiryDate.value : this.expiryDate,
      stockQty: data.stockQty.present ? data.stockQty.value : this.stockQty,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProductBatch(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('batchNumber: $batchNumber, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('stockQty: $stockQty, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, productId, batchNumber, expiryDate,
      stockQty, createdAt, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductBatch &&
          other.id == this.id &&
          other.productId == this.productId &&
          other.batchNumber == this.batchNumber &&
          other.expiryDate == this.expiryDate &&
          other.stockQty == this.stockQty &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class BatchesCompanion extends UpdateCompanion<ProductBatch> {
  final Value<int> id;
  final Value<int> productId;
  final Value<String> batchNumber;
  final Value<DateTime?> expiryDate;
  final Value<int> stockQty;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  const BatchesCompanion({
    this.id = const Value.absent(),
    this.productId = const Value.absent(),
    this.batchNumber = const Value.absent(),
    this.expiryDate = const Value.absent(),
    this.stockQty = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  BatchesCompanion.insert({
    this.id = const Value.absent(),
    required int productId,
    required String batchNumber,
    this.expiryDate = const Value.absent(),
    this.stockQty = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
  })  : productId = Value(productId),
        batchNumber = Value(batchNumber),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<ProductBatch> custom({
    Expression<int>? id,
    Expression<int>? productId,
    Expression<String>? batchNumber,
    Expression<DateTime>? expiryDate,
    Expression<int>? stockQty,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      if (batchNumber != null) 'batch_number': batchNumber,
      if (expiryDate != null) 'expiry_date': expiryDate,
      if (stockQty != null) 'stock_qty': stockQty,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  BatchesCompanion copyWith(
      {Value<int>? id,
      Value<int>? productId,
      Value<String>? batchNumber,
      Value<DateTime?>? expiryDate,
      Value<int>? stockQty,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt}) {
    return BatchesCompanion(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      batchNumber: batchNumber ?? this.batchNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      stockQty: stockQty ?? this.stockQty,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<int>(productId.value);
    }
    if (batchNumber.present) {
      map['batch_number'] = Variable<String>(batchNumber.value);
    }
    if (expiryDate.present) {
      map['expiry_date'] = Variable<DateTime>(expiryDate.value);
    }
    if (stockQty.present) {
      map['stock_qty'] = Variable<int>(stockQty.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BatchesCompanion(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('batchNumber: $batchNumber, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('stockQty: $stockQty, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SuppliersTable suppliers = $SuppliersTable(this);
  late final $ProductsTable products = $ProductsTable(this);
  late final $LocationsTable locations = $LocationsTable(this);
  late final $MovementsTable movements = $MovementsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $StockAuditSessionsTable stockAuditSessions =
      $StockAuditSessionsTable(this);
  late final $StockAuditItemsTable stockAuditItems =
      $StockAuditItemsTable(this);
  late final $BatchesTable batches = $BatchesTable(this);
  late final Index idxProductBarcodeLive = Index('idx_product_barcode_live',
      'CREATE UNIQUE INDEX idx_product_barcode_live ON product (barcode) WHERE barcode IS NOT NULL AND deleted_at IS NULL');
  late final Index idxProductNameLive = Index('idx_product_name_live',
      'CREATE INDEX idx_product_name_live ON product (name) WHERE deleted_at IS NULL');
  late final Index idxMovementProduct = Index('idx_movement_product',
      'CREATE INDEX idx_movement_product ON movement (product_id)');
  late final Index idxMovementCreated = Index('idx_movement_created',
      'CREATE INDEX idx_movement_created ON movement (created_at)');
  late final Index idxMovementBatch = Index('idx_movement_batch',
      'CREATE INDEX idx_movement_batch ON movement (batch_id)');
  late final Index idxMovementLocation = Index('idx_movement_location',
      'CREATE INDEX idx_movement_location ON movement (location_id, product_id)');
  late final Index idxAuditItemSession = Index('idx_audit_item_session',
      'CREATE INDEX idx_audit_item_session ON stock_audit_item (session_id)');
  late final ProductDao productDao = ProductDao(this as AppDatabase);
  late final MovementDao movementDao = MovementDao(this as AppDatabase);
  late final SettingDao settingDao = SettingDao(this as AppDatabase);
  late final AuditDao auditDao = AuditDao(this as AppDatabase);
  late final BatchDao batchDao = BatchDao(this as AppDatabase);
  late final SupplierDao supplierDao = SupplierDao(this as AppDatabase);
  late final LocationDao locationDao = LocationDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        suppliers,
        products,
        locations,
        movements,
        settings,
        stockAuditSessions,
        stockAuditItems,
        batches,
        idxProductBarcodeLive,
        idxProductNameLive,
        idxMovementProduct,
        idxMovementCreated,
        idxMovementBatch,
        idxMovementLocation,
        idxAuditItemSession
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('supplier',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('product', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('product',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('movement', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('location',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('movement', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('supplier',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('movement', kind: UpdateKind.update),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('stock_audit_session',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('stock_audit_item', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('product',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('stock_audit_item', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('product',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('batch', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$SuppliersTableCreateCompanionBuilder = SuppliersCompanion Function({
  Value<int> id,
  required String name,
  required String phone,
  Value<String?> gstin,
  Value<String?> notes,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
});
typedef $$SuppliersTableUpdateCompanionBuilder = SuppliersCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> phone,
  Value<String?> gstin,
  Value<String?> notes,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
});

final class $$SuppliersTableReferences
    extends BaseReferences<_$AppDatabase, $SuppliersTable, Supplier> {
  $$SuppliersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ProductsTable, List<Product>> _productsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.products,
          aliasName: 'supplier__id__product__supplier_id');

  $$ProductsTableProcessedTableManager get productsRefs {
    final manager = $$ProductsTableTableManager($_db, $_db.products)
        .filter((f) => f.supplierId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_productsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$MovementsTable, List<Movement>>
      _movementsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.movements,
              aliasName: 'supplier__id__movement__supplier_id');

  $$MovementsTableProcessedTableManager get movementsRefs {
    final manager = $$MovementsTableTableManager($_db, $_db.movements)
        .filter((f) => f.supplierId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_movementsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$SuppliersTableFilterComposer
    extends Composer<_$AppDatabase, $SuppliersTable> {
  $$SuppliersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get gstin => $composableBuilder(
      column: $table.gstin, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> productsRefs(
      Expression<bool> Function($$ProductsTableFilterComposer f) f) {
    final $$ProductsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.products,
        getReferencedColumn: (t) => t.supplierId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductsTableFilterComposer(
              $db: $db,
              $table: $db.products,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> movementsRefs(
      Expression<bool> Function($$MovementsTableFilterComposer f) f) {
    final $$MovementsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.movements,
        getReferencedColumn: (t) => t.supplierId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MovementsTableFilterComposer(
              $db: $db,
              $table: $db.movements,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SuppliersTableOrderingComposer
    extends Composer<_$AppDatabase, $SuppliersTable> {
  $$SuppliersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get gstin => $composableBuilder(
      column: $table.gstin, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$SuppliersTableAnnotationComposer
    extends Composer<_$AppDatabase, $SuppliersTable> {
  $$SuppliersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get gstin =>
      $composableBuilder(column: $table.gstin, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> productsRefs<T extends Object>(
      Expression<T> Function($$ProductsTableAnnotationComposer a) f) {
    final $$ProductsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.products,
        getReferencedColumn: (t) => t.supplierId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductsTableAnnotationComposer(
              $db: $db,
              $table: $db.products,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> movementsRefs<T extends Object>(
      Expression<T> Function($$MovementsTableAnnotationComposer a) f) {
    final $$MovementsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.movements,
        getReferencedColumn: (t) => t.supplierId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MovementsTableAnnotationComposer(
              $db: $db,
              $table: $db.movements,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SuppliersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SuppliersTable,
    Supplier,
    $$SuppliersTableFilterComposer,
    $$SuppliersTableOrderingComposer,
    $$SuppliersTableAnnotationComposer,
    $$SuppliersTableCreateCompanionBuilder,
    $$SuppliersTableUpdateCompanionBuilder,
    (Supplier, $$SuppliersTableReferences),
    Supplier,
    PrefetchHooks Function({bool productsRefs, bool movementsRefs})> {
  $$SuppliersTableTableManager(_$AppDatabase db, $SuppliersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SuppliersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SuppliersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SuppliersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> phone = const Value.absent(),
            Value<String?> gstin = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
          }) =>
              SuppliersCompanion(
            id: id,
            name: name,
            phone: phone,
            gstin: gstin,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            required String phone,
            Value<String?> gstin = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
          }) =>
              SuppliersCompanion.insert(
            id: id,
            name: name,
            phone: phone,
            gstin: gstin,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SuppliersTable, Supplier>(table),
                    $$SuppliersTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {productsRefs = false, movementsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (productsRefs) db.products,
                if (movementsRefs) db.movements
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (productsRefs)
                    await $_getPrefetchedData<Supplier, $SuppliersTable,
                            Product>(
                        currentTable: table,
                        referencedTable:
                            $$SuppliersTableReferences._productsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SuppliersTableReferences(db, table, p0)
                                .productsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.supplierId == item.id),
                        typedResults: items),
                  if (movementsRefs)
                    await $_getPrefetchedData<Supplier, $SuppliersTable,
                            Movement>(
                        currentTable: table,
                        referencedTable:
                            $$SuppliersTableReferences._movementsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SuppliersTableReferences(db, table, p0)
                                .movementsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.supplierId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$SuppliersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SuppliersTable,
    Supplier,
    $$SuppliersTableFilterComposer,
    $$SuppliersTableOrderingComposer,
    $$SuppliersTableAnnotationComposer,
    $$SuppliersTableCreateCompanionBuilder,
    $$SuppliersTableUpdateCompanionBuilder,
    (Supplier, $$SuppliersTableReferences),
    Supplier,
    PrefetchHooks Function({bool productsRefs, bool movementsRefs})>;
typedef $$ProductsTableCreateCompanionBuilder = ProductsCompanion Function({
  Value<int> id,
  required String name,
  Value<String?> sku,
  Value<String?> barcode,
  Value<String?> category,
  Value<String> unit,
  Value<double> buyPrice,
  Value<double> sellPrice,
  Value<int> lowStockLevel,
  Value<int> stockQty,
  Value<int?> supplierId,
  Value<String?> imagePath,
  Value<bool> isFavourite,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
});
typedef $$ProductsTableUpdateCompanionBuilder = ProductsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String?> sku,
  Value<String?> barcode,
  Value<String?> category,
  Value<String> unit,
  Value<double> buyPrice,
  Value<double> sellPrice,
  Value<int> lowStockLevel,
  Value<int> stockQty,
  Value<int?> supplierId,
  Value<String?> imagePath,
  Value<bool> isFavourite,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
});

final class $$ProductsTableReferences
    extends BaseReferences<_$AppDatabase, $ProductsTable, Product> {
  $$ProductsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SuppliersTable _supplierIdTable(_$AppDatabase db) =>
      db.suppliers.createAlias('product__supplier_id__supplier__id');

  $$SuppliersTableProcessedTableManager? get supplierId {
    final $_column = $_itemColumn<int>('supplier_id');
    if ($_column == null) return null;
    final manager = $$SuppliersTableTableManager($_db, $_db.suppliers)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_supplierIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$MovementsTable, List<Movement>>
      _movementsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.movements,
              aliasName: 'product__id__movement__product_id');

  $$MovementsTableProcessedTableManager get movementsRefs {
    final manager = $$MovementsTableTableManager($_db, $_db.movements)
        .filter((f) => f.productId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_movementsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$StockAuditItemsTable, List<StockAuditItem>>
      _stockAuditItemsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.stockAuditItems,
              aliasName: 'product__id__stock_audit_item__product_id');

  $$StockAuditItemsTableProcessedTableManager get stockAuditItemsRefs {
    final manager =
        $$StockAuditItemsTableTableManager($_db, $_db.stockAuditItems)
            .filter((f) => f.productId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_stockAuditItemsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$BatchesTable, List<ProductBatch>>
      _batchesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.batches,
              aliasName: 'product__id__batch__product_id');

  $$BatchesTableProcessedTableManager get batchesRefs {
    final manager = $$BatchesTableTableManager($_db, $_db.batches)
        .filter((f) => f.productId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_batchesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ProductsTableFilterComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sku => $composableBuilder(
      column: $table.sku, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get barcode => $composableBuilder(
      column: $table.barcode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get buyPrice => $composableBuilder(
      column: $table.buyPrice, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get sellPrice => $composableBuilder(
      column: $table.sellPrice, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lowStockLevel => $composableBuilder(
      column: $table.lowStockLevel, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get stockQty => $composableBuilder(
      column: $table.stockQty, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imagePath => $composableBuilder(
      column: $table.imagePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isFavourite => $composableBuilder(
      column: $table.isFavourite, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  $$SuppliersTableFilterComposer get supplierId {
    final $$SuppliersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.supplierId,
        referencedTable: $db.suppliers,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SuppliersTableFilterComposer(
              $db: $db,
              $table: $db.suppliers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> movementsRefs(
      Expression<bool> Function($$MovementsTableFilterComposer f) f) {
    final $$MovementsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.movements,
        getReferencedColumn: (t) => t.productId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MovementsTableFilterComposer(
              $db: $db,
              $table: $db.movements,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> stockAuditItemsRefs(
      Expression<bool> Function($$StockAuditItemsTableFilterComposer f) f) {
    final $$StockAuditItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.stockAuditItems,
        getReferencedColumn: (t) => t.productId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StockAuditItemsTableFilterComposer(
              $db: $db,
              $table: $db.stockAuditItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> batchesRefs(
      Expression<bool> Function($$BatchesTableFilterComposer f) f) {
    final $$BatchesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.batches,
        getReferencedColumn: (t) => t.productId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BatchesTableFilterComposer(
              $db: $db,
              $table: $db.batches,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ProductsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sku => $composableBuilder(
      column: $table.sku, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get barcode => $composableBuilder(
      column: $table.barcode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get buyPrice => $composableBuilder(
      column: $table.buyPrice, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get sellPrice => $composableBuilder(
      column: $table.sellPrice, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lowStockLevel => $composableBuilder(
      column: $table.lowStockLevel,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get stockQty => $composableBuilder(
      column: $table.stockQty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imagePath => $composableBuilder(
      column: $table.imagePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isFavourite => $composableBuilder(
      column: $table.isFavourite, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  $$SuppliersTableOrderingComposer get supplierId {
    final $$SuppliersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.supplierId,
        referencedTable: $db.suppliers,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SuppliersTableOrderingComposer(
              $db: $db,
              $table: $db.suppliers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ProductsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get sku =>
      $composableBuilder(column: $table.sku, builder: (column) => column);

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<double> get buyPrice =>
      $composableBuilder(column: $table.buyPrice, builder: (column) => column);

  GeneratedColumn<double> get sellPrice =>
      $composableBuilder(column: $table.sellPrice, builder: (column) => column);

  GeneratedColumn<int> get lowStockLevel => $composableBuilder(
      column: $table.lowStockLevel, builder: (column) => column);

  GeneratedColumn<int> get stockQty =>
      $composableBuilder(column: $table.stockQty, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<bool> get isFavourite => $composableBuilder(
      column: $table.isFavourite, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$SuppliersTableAnnotationComposer get supplierId {
    final $$SuppliersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.supplierId,
        referencedTable: $db.suppliers,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SuppliersTableAnnotationComposer(
              $db: $db,
              $table: $db.suppliers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> movementsRefs<T extends Object>(
      Expression<T> Function($$MovementsTableAnnotationComposer a) f) {
    final $$MovementsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.movements,
        getReferencedColumn: (t) => t.productId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MovementsTableAnnotationComposer(
              $db: $db,
              $table: $db.movements,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> stockAuditItemsRefs<T extends Object>(
      Expression<T> Function($$StockAuditItemsTableAnnotationComposer a) f) {
    final $$StockAuditItemsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.stockAuditItems,
        getReferencedColumn: (t) => t.productId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StockAuditItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.stockAuditItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> batchesRefs<T extends Object>(
      Expression<T> Function($$BatchesTableAnnotationComposer a) f) {
    final $$BatchesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.batches,
        getReferencedColumn: (t) => t.productId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BatchesTableAnnotationComposer(
              $db: $db,
              $table: $db.batches,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ProductsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProductsTable,
    Product,
    $$ProductsTableFilterComposer,
    $$ProductsTableOrderingComposer,
    $$ProductsTableAnnotationComposer,
    $$ProductsTableCreateCompanionBuilder,
    $$ProductsTableUpdateCompanionBuilder,
    (Product, $$ProductsTableReferences),
    Product,
    PrefetchHooks Function(
        {bool supplierId,
        bool movementsRefs,
        bool stockAuditItemsRefs,
        bool batchesRefs})> {
  $$ProductsTableTableManager(_$AppDatabase db, $ProductsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> sku = const Value.absent(),
            Value<String?> barcode = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<String> unit = const Value.absent(),
            Value<double> buyPrice = const Value.absent(),
            Value<double> sellPrice = const Value.absent(),
            Value<int> lowStockLevel = const Value.absent(),
            Value<int> stockQty = const Value.absent(),
            Value<int?> supplierId = const Value.absent(),
            Value<String?> imagePath = const Value.absent(),
            Value<bool> isFavourite = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
          }) =>
              ProductsCompanion(
            id: id,
            name: name,
            sku: sku,
            barcode: barcode,
            category: category,
            unit: unit,
            buyPrice: buyPrice,
            sellPrice: sellPrice,
            lowStockLevel: lowStockLevel,
            stockQty: stockQty,
            supplierId: supplierId,
            imagePath: imagePath,
            isFavourite: isFavourite,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<String?> sku = const Value.absent(),
            Value<String?> barcode = const Value.absent(),
            Value<String?> category = const Value.absent(),
            Value<String> unit = const Value.absent(),
            Value<double> buyPrice = const Value.absent(),
            Value<double> sellPrice = const Value.absent(),
            Value<int> lowStockLevel = const Value.absent(),
            Value<int> stockQty = const Value.absent(),
            Value<int?> supplierId = const Value.absent(),
            Value<String?> imagePath = const Value.absent(),
            Value<bool> isFavourite = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
          }) =>
              ProductsCompanion.insert(
            id: id,
            name: name,
            sku: sku,
            barcode: barcode,
            category: category,
            unit: unit,
            buyPrice: buyPrice,
            sellPrice: sellPrice,
            lowStockLevel: lowStockLevel,
            stockQty: stockQty,
            supplierId: supplierId,
            imagePath: imagePath,
            isFavourite: isFavourite,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ProductsTable, Product>(table),
                    $$ProductsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {supplierId = false,
              movementsRefs = false,
              stockAuditItemsRefs = false,
              batchesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (movementsRefs) db.movements,
                if (stockAuditItemsRefs) db.stockAuditItems,
                if (batchesRefs) db.batches
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (supplierId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.supplierId,
                    referencedTable:
                        $$ProductsTableReferences._supplierIdTable(db),
                    referencedColumn:
                        $$ProductsTableReferences._supplierIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (movementsRefs)
                    await $_getPrefetchedData<Product, $ProductsTable,
                            Movement>(
                        currentTable: table,
                        referencedTable:
                            $$ProductsTableReferences._movementsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProductsTableReferences(db, table, p0)
                                .movementsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.productId == item.id),
                        typedResults: items),
                  if (stockAuditItemsRefs)
                    await $_getPrefetchedData<Product, $ProductsTable,
                            StockAuditItem>(
                        currentTable: table,
                        referencedTable: $$ProductsTableReferences
                            ._stockAuditItemsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProductsTableReferences(db, table, p0)
                                .stockAuditItemsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.productId == item.id),
                        typedResults: items),
                  if (batchesRefs)
                    await $_getPrefetchedData<Product, $ProductsTable,
                            ProductBatch>(
                        currentTable: table,
                        referencedTable:
                            $$ProductsTableReferences._batchesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProductsTableReferences(db, table, p0)
                                .batchesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.productId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ProductsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProductsTable,
    Product,
    $$ProductsTableFilterComposer,
    $$ProductsTableOrderingComposer,
    $$ProductsTableAnnotationComposer,
    $$ProductsTableCreateCompanionBuilder,
    $$ProductsTableUpdateCompanionBuilder,
    (Product, $$ProductsTableReferences),
    Product,
    PrefetchHooks Function(
        {bool supplierId,
        bool movementsRefs,
        bool stockAuditItemsRefs,
        bool batchesRefs})>;
typedef $$LocationsTableCreateCompanionBuilder = LocationsCompanion Function({
  Value<int> id,
  required String name,
  Value<String?> note,
  Value<bool> isDefault,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
});
typedef $$LocationsTableUpdateCompanionBuilder = LocationsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String?> note,
  Value<bool> isDefault,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
});

final class $$LocationsTableReferences
    extends BaseReferences<_$AppDatabase, $LocationsTable, Location> {
  $$LocationsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MovementsTable, List<Movement>>
      _movementsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.movements,
              aliasName: 'location__id__movement__location_id');

  $$MovementsTableProcessedTableManager get movementsRefs {
    final manager = $$MovementsTableTableManager($_db, $_db.movements)
        .filter((f) => f.locationId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_movementsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$LocationsTableFilterComposer
    extends Composer<_$AppDatabase, $LocationsTable> {
  $$LocationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDefault => $composableBuilder(
      column: $table.isDefault, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> movementsRefs(
      Expression<bool> Function($$MovementsTableFilterComposer f) f) {
    final $$MovementsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.movements,
        getReferencedColumn: (t) => t.locationId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MovementsTableFilterComposer(
              $db: $db,
              $table: $db.movements,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$LocationsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocationsTable> {
  $$LocationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDefault => $composableBuilder(
      column: $table.isDefault, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocationsTable> {
  $$LocationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> movementsRefs<T extends Object>(
      Expression<T> Function($$MovementsTableAnnotationComposer a) f) {
    final $$MovementsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.movements,
        getReferencedColumn: (t) => t.locationId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MovementsTableAnnotationComposer(
              $db: $db,
              $table: $db.movements,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$LocationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocationsTable,
    Location,
    $$LocationsTableFilterComposer,
    $$LocationsTableOrderingComposer,
    $$LocationsTableAnnotationComposer,
    $$LocationsTableCreateCompanionBuilder,
    $$LocationsTableUpdateCompanionBuilder,
    (Location, $$LocationsTableReferences),
    Location,
    PrefetchHooks Function({bool movementsRefs})> {
  $$LocationsTableTableManager(_$AppDatabase db, $LocationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<bool> isDefault = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
          }) =>
              LocationsCompanion(
            id: id,
            name: name,
            note: note,
            isDefault: isDefault,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<String?> note = const Value.absent(),
            Value<bool> isDefault = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
          }) =>
              LocationsCompanion.insert(
            id: id,
            name: name,
            note: note,
            isDefault: isDefault,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$LocationsTable, Location>(table),
                    $$LocationsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({movementsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (movementsRefs) db.movements],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (movementsRefs)
                    await $_getPrefetchedData<Location, $LocationsTable,
                            Movement>(
                        currentTable: table,
                        referencedTable:
                            $$LocationsTableReferences._movementsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$LocationsTableReferences(db, table, p0)
                                .movementsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.locationId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$LocationsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocationsTable,
    Location,
    $$LocationsTableFilterComposer,
    $$LocationsTableOrderingComposer,
    $$LocationsTableAnnotationComposer,
    $$LocationsTableCreateCompanionBuilder,
    $$LocationsTableUpdateCompanionBuilder,
    (Location, $$LocationsTableReferences),
    Location,
    PrefetchHooks Function({bool movementsRefs})>;
typedef $$MovementsTableCreateCompanionBuilder = MovementsCompanion Function({
  Value<int> id,
  required int productId,
  required int qtyDelta,
  required String reason,
  Value<String?> note,
  Value<int?> auditSessionId,
  Value<int?> batchId,
  Value<int?> locationId,
  Value<String?> transferRef,
  Value<int?> supplierId,
  required DateTime createdAt,
});
typedef $$MovementsTableUpdateCompanionBuilder = MovementsCompanion Function({
  Value<int> id,
  Value<int> productId,
  Value<int> qtyDelta,
  Value<String> reason,
  Value<String?> note,
  Value<int?> auditSessionId,
  Value<int?> batchId,
  Value<int?> locationId,
  Value<String?> transferRef,
  Value<int?> supplierId,
  Value<DateTime> createdAt,
});

final class $$MovementsTableReferences
    extends BaseReferences<_$AppDatabase, $MovementsTable, Movement> {
  $$MovementsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProductsTable _productIdTable(_$AppDatabase db) =>
      db.products.createAlias('movement__product_id__product__id');

  $$ProductsTableProcessedTableManager get productId {
    final $_column = $_itemColumn<int>('product_id')!;

    final manager = $$ProductsTableTableManager($_db, $_db.products)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $LocationsTable _locationIdTable(_$AppDatabase db) =>
      db.locations.createAlias('movement__location_id__location__id');

  $$LocationsTableProcessedTableManager? get locationId {
    final $_column = $_itemColumn<int>('location_id');
    if ($_column == null) return null;
    final manager = $$LocationsTableTableManager($_db, $_db.locations)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_locationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $SuppliersTable _supplierIdTable(_$AppDatabase db) =>
      db.suppliers.createAlias('movement__supplier_id__supplier__id');

  $$SuppliersTableProcessedTableManager? get supplierId {
    final $_column = $_itemColumn<int>('supplier_id');
    if ($_column == null) return null;
    final manager = $$SuppliersTableTableManager($_db, $_db.suppliers)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_supplierIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$MovementsTableFilterComposer
    extends Composer<_$AppDatabase, $MovementsTable> {
  $$MovementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get qtyDelta => $composableBuilder(
      column: $table.qtyDelta, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get auditSessionId => $composableBuilder(
      column: $table.auditSessionId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get batchId => $composableBuilder(
      column: $table.batchId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get transferRef => $composableBuilder(
      column: $table.transferRef, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$ProductsTableFilterComposer get productId {
    final $$ProductsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productId,
        referencedTable: $db.products,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductsTableFilterComposer(
              $db: $db,
              $table: $db.products,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$LocationsTableFilterComposer get locationId {
    final $$LocationsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.locationId,
        referencedTable: $db.locations,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$LocationsTableFilterComposer(
              $db: $db,
              $table: $db.locations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SuppliersTableFilterComposer get supplierId {
    final $$SuppliersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.supplierId,
        referencedTable: $db.suppliers,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SuppliersTableFilterComposer(
              $db: $db,
              $table: $db.suppliers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MovementsTableOrderingComposer
    extends Composer<_$AppDatabase, $MovementsTable> {
  $$MovementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get qtyDelta => $composableBuilder(
      column: $table.qtyDelta, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reason => $composableBuilder(
      column: $table.reason, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get auditSessionId => $composableBuilder(
      column: $table.auditSessionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get batchId => $composableBuilder(
      column: $table.batchId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get transferRef => $composableBuilder(
      column: $table.transferRef, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$ProductsTableOrderingComposer get productId {
    final $$ProductsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productId,
        referencedTable: $db.products,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductsTableOrderingComposer(
              $db: $db,
              $table: $db.products,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$LocationsTableOrderingComposer get locationId {
    final $$LocationsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.locationId,
        referencedTable: $db.locations,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$LocationsTableOrderingComposer(
              $db: $db,
              $table: $db.locations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SuppliersTableOrderingComposer get supplierId {
    final $$SuppliersTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.supplierId,
        referencedTable: $db.suppliers,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SuppliersTableOrderingComposer(
              $db: $db,
              $table: $db.suppliers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MovementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MovementsTable> {
  $$MovementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get qtyDelta =>
      $composableBuilder(column: $table.qtyDelta, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get auditSessionId => $composableBuilder(
      column: $table.auditSessionId, builder: (column) => column);

  GeneratedColumn<int> get batchId =>
      $composableBuilder(column: $table.batchId, builder: (column) => column);

  GeneratedColumn<String> get transferRef => $composableBuilder(
      column: $table.transferRef, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ProductsTableAnnotationComposer get productId {
    final $$ProductsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productId,
        referencedTable: $db.products,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductsTableAnnotationComposer(
              $db: $db,
              $table: $db.products,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$LocationsTableAnnotationComposer get locationId {
    final $$LocationsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.locationId,
        referencedTable: $db.locations,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$LocationsTableAnnotationComposer(
              $db: $db,
              $table: $db.locations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$SuppliersTableAnnotationComposer get supplierId {
    final $$SuppliersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.supplierId,
        referencedTable: $db.suppliers,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SuppliersTableAnnotationComposer(
              $db: $db,
              $table: $db.suppliers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MovementsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MovementsTable,
    Movement,
    $$MovementsTableFilterComposer,
    $$MovementsTableOrderingComposer,
    $$MovementsTableAnnotationComposer,
    $$MovementsTableCreateCompanionBuilder,
    $$MovementsTableUpdateCompanionBuilder,
    (Movement, $$MovementsTableReferences),
    Movement,
    PrefetchHooks Function(
        {bool productId, bool locationId, bool supplierId})> {
  $$MovementsTableTableManager(_$AppDatabase db, $MovementsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MovementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MovementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MovementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> productId = const Value.absent(),
            Value<int> qtyDelta = const Value.absent(),
            Value<String> reason = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<int?> auditSessionId = const Value.absent(),
            Value<int?> batchId = const Value.absent(),
            Value<int?> locationId = const Value.absent(),
            Value<String?> transferRef = const Value.absent(),
            Value<int?> supplierId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              MovementsCompanion(
            id: id,
            productId: productId,
            qtyDelta: qtyDelta,
            reason: reason,
            note: note,
            auditSessionId: auditSessionId,
            batchId: batchId,
            locationId: locationId,
            transferRef: transferRef,
            supplierId: supplierId,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int productId,
            required int qtyDelta,
            required String reason,
            Value<String?> note = const Value.absent(),
            Value<int?> auditSessionId = const Value.absent(),
            Value<int?> batchId = const Value.absent(),
            Value<int?> locationId = const Value.absent(),
            Value<String?> transferRef = const Value.absent(),
            Value<int?> supplierId = const Value.absent(),
            required DateTime createdAt,
          }) =>
              MovementsCompanion.insert(
            id: id,
            productId: productId,
            qtyDelta: qtyDelta,
            reason: reason,
            note: note,
            auditSessionId: auditSessionId,
            batchId: batchId,
            locationId: locationId,
            transferRef: transferRef,
            supplierId: supplierId,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$MovementsTable, Movement>(table),
                    $$MovementsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {productId = false, locationId = false, supplierId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (productId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.productId,
                    referencedTable:
                        $$MovementsTableReferences._productIdTable(db),
                    referencedColumn:
                        $$MovementsTableReferences._productIdTable(db).id,
                  ) as T;
                }
                if (locationId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.locationId,
                    referencedTable:
                        $$MovementsTableReferences._locationIdTable(db),
                    referencedColumn:
                        $$MovementsTableReferences._locationIdTable(db).id,
                  ) as T;
                }
                if (supplierId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.supplierId,
                    referencedTable:
                        $$MovementsTableReferences._supplierIdTable(db),
                    referencedColumn:
                        $$MovementsTableReferences._supplierIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$MovementsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MovementsTable,
    Movement,
    $$MovementsTableFilterComposer,
    $$MovementsTableOrderingComposer,
    $$MovementsTableAnnotationComposer,
    $$MovementsTableCreateCompanionBuilder,
    $$MovementsTableUpdateCompanionBuilder,
    (Movement, $$MovementsTableReferences),
    Movement,
    PrefetchHooks Function({bool productId, bool locationId, bool supplierId})>;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()> {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SettingsTable, Setting>(table),
                    BaseReferences<_$AppDatabase, $SettingsTable, Setting>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()>;
typedef $$StockAuditSessionsTableCreateCompanionBuilder
    = StockAuditSessionsCompanion Function({
  Value<int> id,
  required String name,
  Value<String> status,
  Value<String> auditMode,
  required DateTime startedAt,
  Value<DateTime?> completedAt,
  Value<int> totalItemsCounted,
  Value<int> totalDiscrepancies,
  Value<double> netDiscrepancyValue,
  Value<String?> notes,
});
typedef $$StockAuditSessionsTableUpdateCompanionBuilder
    = StockAuditSessionsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> status,
  Value<String> auditMode,
  Value<DateTime> startedAt,
  Value<DateTime?> completedAt,
  Value<int> totalItemsCounted,
  Value<int> totalDiscrepancies,
  Value<double> netDiscrepancyValue,
  Value<String?> notes,
});

final class $$StockAuditSessionsTableReferences extends BaseReferences<
    _$AppDatabase, $StockAuditSessionsTable, StockAuditSession> {
  $$StockAuditSessionsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$StockAuditItemsTable, List<StockAuditItem>>
      _stockAuditItemsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.stockAuditItems,
              aliasName:
                  'stock_audit_session__id__stock_audit_item__session_id');

  $$StockAuditItemsTableProcessedTableManager get stockAuditItemsRefs {
    final manager =
        $$StockAuditItemsTableTableManager($_db, $_db.stockAuditItems)
            .filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_stockAuditItemsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$StockAuditSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $StockAuditSessionsTable> {
  $$StockAuditSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get auditMode => $composableBuilder(
      column: $table.auditMode, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalItemsCounted => $composableBuilder(
      column: $table.totalItemsCounted,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalDiscrepancies => $composableBuilder(
      column: $table.totalDiscrepancies,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get netDiscrepancyValue => $composableBuilder(
      column: $table.netDiscrepancyValue,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  Expression<bool> stockAuditItemsRefs(
      Expression<bool> Function($$StockAuditItemsTableFilterComposer f) f) {
    final $$StockAuditItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.stockAuditItems,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StockAuditItemsTableFilterComposer(
              $db: $db,
              $table: $db.stockAuditItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$StockAuditSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $StockAuditSessionsTable> {
  $$StockAuditSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get auditMode => $composableBuilder(
      column: $table.auditMode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalItemsCounted => $composableBuilder(
      column: $table.totalItemsCounted,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalDiscrepancies => $composableBuilder(
      column: $table.totalDiscrepancies,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get netDiscrepancyValue => $composableBuilder(
      column: $table.netDiscrepancyValue,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));
}

class $$StockAuditSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StockAuditSessionsTable> {
  $$StockAuditSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get auditMode =>
      $composableBuilder(column: $table.auditMode, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => column);

  GeneratedColumn<int> get totalItemsCounted => $composableBuilder(
      column: $table.totalItemsCounted, builder: (column) => column);

  GeneratedColumn<int> get totalDiscrepancies => $composableBuilder(
      column: $table.totalDiscrepancies, builder: (column) => column);

  GeneratedColumn<double> get netDiscrepancyValue => $composableBuilder(
      column: $table.netDiscrepancyValue, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  Expression<T> stockAuditItemsRefs<T extends Object>(
      Expression<T> Function($$StockAuditItemsTableAnnotationComposer a) f) {
    final $$StockAuditItemsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.stockAuditItems,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StockAuditItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.stockAuditItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$StockAuditSessionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $StockAuditSessionsTable,
    StockAuditSession,
    $$StockAuditSessionsTableFilterComposer,
    $$StockAuditSessionsTableOrderingComposer,
    $$StockAuditSessionsTableAnnotationComposer,
    $$StockAuditSessionsTableCreateCompanionBuilder,
    $$StockAuditSessionsTableUpdateCompanionBuilder,
    (StockAuditSession, $$StockAuditSessionsTableReferences),
    StockAuditSession,
    PrefetchHooks Function({bool stockAuditItemsRefs})> {
  $$StockAuditSessionsTableTableManager(
      _$AppDatabase db, $StockAuditSessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockAuditSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockAuditSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockAuditSessionsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> auditMode = const Value.absent(),
            Value<DateTime> startedAt = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<int> totalItemsCounted = const Value.absent(),
            Value<int> totalDiscrepancies = const Value.absent(),
            Value<double> netDiscrepancyValue = const Value.absent(),
            Value<String?> notes = const Value.absent(),
          }) =>
              StockAuditSessionsCompanion(
            id: id,
            name: name,
            status: status,
            auditMode: auditMode,
            startedAt: startedAt,
            completedAt: completedAt,
            totalItemsCounted: totalItemsCounted,
            totalDiscrepancies: totalDiscrepancies,
            netDiscrepancyValue: netDiscrepancyValue,
            notes: notes,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<String> status = const Value.absent(),
            Value<String> auditMode = const Value.absent(),
            required DateTime startedAt,
            Value<DateTime?> completedAt = const Value.absent(),
            Value<int> totalItemsCounted = const Value.absent(),
            Value<int> totalDiscrepancies = const Value.absent(),
            Value<double> netDiscrepancyValue = const Value.absent(),
            Value<String?> notes = const Value.absent(),
          }) =>
              StockAuditSessionsCompanion.insert(
            id: id,
            name: name,
            status: status,
            auditMode: auditMode,
            startedAt: startedAt,
            completedAt: completedAt,
            totalItemsCounted: totalItemsCounted,
            totalDiscrepancies: totalDiscrepancies,
            netDiscrepancyValue: netDiscrepancyValue,
            notes: notes,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$StockAuditSessionsTable, StockAuditSession>(
                        table),
                    $$StockAuditSessionsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({stockAuditItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (stockAuditItemsRefs) db.stockAuditItems
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (stockAuditItemsRefs)
                    await $_getPrefetchedData<StockAuditSession,
                            $StockAuditSessionsTable, StockAuditItem>(
                        currentTable: table,
                        referencedTable: $$StockAuditSessionsTableReferences
                            ._stockAuditItemsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$StockAuditSessionsTableReferences(db, table, p0)
                                .stockAuditItemsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.sessionId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$StockAuditSessionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $StockAuditSessionsTable,
    StockAuditSession,
    $$StockAuditSessionsTableFilterComposer,
    $$StockAuditSessionsTableOrderingComposer,
    $$StockAuditSessionsTableAnnotationComposer,
    $$StockAuditSessionsTableCreateCompanionBuilder,
    $$StockAuditSessionsTableUpdateCompanionBuilder,
    (StockAuditSession, $$StockAuditSessionsTableReferences),
    StockAuditSession,
    PrefetchHooks Function({bool stockAuditItemsRefs})>;
typedef $$StockAuditItemsTableCreateCompanionBuilder = StockAuditItemsCompanion
    Function({
  Value<int> id,
  required int sessionId,
  required int productId,
  required int expectedQty,
  required int countedQty,
  required int difference,
  Value<bool> isReconciled,
  Value<DateTime?> reconciledAt,
  Value<String?> notes,
  required DateTime updatedAt,
});
typedef $$StockAuditItemsTableUpdateCompanionBuilder = StockAuditItemsCompanion
    Function({
  Value<int> id,
  Value<int> sessionId,
  Value<int> productId,
  Value<int> expectedQty,
  Value<int> countedQty,
  Value<int> difference,
  Value<bool> isReconciled,
  Value<DateTime?> reconciledAt,
  Value<String?> notes,
  Value<DateTime> updatedAt,
});

final class $$StockAuditItemsTableReferences extends BaseReferences<
    _$AppDatabase, $StockAuditItemsTable, StockAuditItem> {
  $$StockAuditItemsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $StockAuditSessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.stockAuditSessions
          .createAlias('stock_audit_item__session_id__stock_audit_session__id');

  $$StockAuditSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<int>('session_id')!;

    final manager =
        $$StockAuditSessionsTableTableManager($_db, $_db.stockAuditSessions)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $ProductsTable _productIdTable(_$AppDatabase db) =>
      db.products.createAlias('stock_audit_item__product_id__product__id');

  $$ProductsTableProcessedTableManager get productId {
    final $_column = $_itemColumn<int>('product_id')!;

    final manager = $$ProductsTableTableManager($_db, $_db.products)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$StockAuditItemsTableFilterComposer
    extends Composer<_$AppDatabase, $StockAuditItemsTable> {
  $$StockAuditItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get expectedQty => $composableBuilder(
      column: $table.expectedQty, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get countedQty => $composableBuilder(
      column: $table.countedQty, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get difference => $composableBuilder(
      column: $table.difference, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isReconciled => $composableBuilder(
      column: $table.isReconciled, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get reconciledAt => $composableBuilder(
      column: $table.reconciledAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$StockAuditSessionsTableFilterComposer get sessionId {
    final $$StockAuditSessionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.stockAuditSessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StockAuditSessionsTableFilterComposer(
              $db: $db,
              $table: $db.stockAuditSessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProductsTableFilterComposer get productId {
    final $$ProductsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productId,
        referencedTable: $db.products,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductsTableFilterComposer(
              $db: $db,
              $table: $db.products,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$StockAuditItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $StockAuditItemsTable> {
  $$StockAuditItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get expectedQty => $composableBuilder(
      column: $table.expectedQty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get countedQty => $composableBuilder(
      column: $table.countedQty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get difference => $composableBuilder(
      column: $table.difference, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isReconciled => $composableBuilder(
      column: $table.isReconciled,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get reconciledAt => $composableBuilder(
      column: $table.reconciledAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$StockAuditSessionsTableOrderingComposer get sessionId {
    final $$StockAuditSessionsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.stockAuditSessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StockAuditSessionsTableOrderingComposer(
              $db: $db,
              $table: $db.stockAuditSessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ProductsTableOrderingComposer get productId {
    final $$ProductsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productId,
        referencedTable: $db.products,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductsTableOrderingComposer(
              $db: $db,
              $table: $db.products,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$StockAuditItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StockAuditItemsTable> {
  $$StockAuditItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get expectedQty => $composableBuilder(
      column: $table.expectedQty, builder: (column) => column);

  GeneratedColumn<int> get countedQty => $composableBuilder(
      column: $table.countedQty, builder: (column) => column);

  GeneratedColumn<int> get difference => $composableBuilder(
      column: $table.difference, builder: (column) => column);

  GeneratedColumn<bool> get isReconciled => $composableBuilder(
      column: $table.isReconciled, builder: (column) => column);

  GeneratedColumn<DateTime> get reconciledAt => $composableBuilder(
      column: $table.reconciledAt, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$StockAuditSessionsTableAnnotationComposer get sessionId {
    final $$StockAuditSessionsTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.sessionId,
            referencedTable: $db.stockAuditSessions,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$StockAuditSessionsTableAnnotationComposer(
                  $db: $db,
                  $table: $db.stockAuditSessions,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return composer;
  }

  $$ProductsTableAnnotationComposer get productId {
    final $$ProductsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productId,
        referencedTable: $db.products,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductsTableAnnotationComposer(
              $db: $db,
              $table: $db.products,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$StockAuditItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $StockAuditItemsTable,
    StockAuditItem,
    $$StockAuditItemsTableFilterComposer,
    $$StockAuditItemsTableOrderingComposer,
    $$StockAuditItemsTableAnnotationComposer,
    $$StockAuditItemsTableCreateCompanionBuilder,
    $$StockAuditItemsTableUpdateCompanionBuilder,
    (StockAuditItem, $$StockAuditItemsTableReferences),
    StockAuditItem,
    PrefetchHooks Function({bool sessionId, bool productId})> {
  $$StockAuditItemsTableTableManager(
      _$AppDatabase db, $StockAuditItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StockAuditItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StockAuditItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StockAuditItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> sessionId = const Value.absent(),
            Value<int> productId = const Value.absent(),
            Value<int> expectedQty = const Value.absent(),
            Value<int> countedQty = const Value.absent(),
            Value<int> difference = const Value.absent(),
            Value<bool> isReconciled = const Value.absent(),
            Value<DateTime?> reconciledAt = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              StockAuditItemsCompanion(
            id: id,
            sessionId: sessionId,
            productId: productId,
            expectedQty: expectedQty,
            countedQty: countedQty,
            difference: difference,
            isReconciled: isReconciled,
            reconciledAt: reconciledAt,
            notes: notes,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int sessionId,
            required int productId,
            required int expectedQty,
            required int countedQty,
            required int difference,
            Value<bool> isReconciled = const Value.absent(),
            Value<DateTime?> reconciledAt = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            required DateTime updatedAt,
          }) =>
              StockAuditItemsCompanion.insert(
            id: id,
            sessionId: sessionId,
            productId: productId,
            expectedQty: expectedQty,
            countedQty: countedQty,
            difference: difference,
            isReconciled: isReconciled,
            reconciledAt: reconciledAt,
            notes: notes,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$StockAuditItemsTable, StockAuditItem>(table),
                    $$StockAuditItemsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({sessionId = false, productId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (sessionId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.sessionId,
                    referencedTable:
                        $$StockAuditItemsTableReferences._sessionIdTable(db),
                    referencedColumn:
                        $$StockAuditItemsTableReferences._sessionIdTable(db).id,
                  ) as T;
                }
                if (productId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.productId,
                    referencedTable:
                        $$StockAuditItemsTableReferences._productIdTable(db),
                    referencedColumn:
                        $$StockAuditItemsTableReferences._productIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$StockAuditItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $StockAuditItemsTable,
    StockAuditItem,
    $$StockAuditItemsTableFilterComposer,
    $$StockAuditItemsTableOrderingComposer,
    $$StockAuditItemsTableAnnotationComposer,
    $$StockAuditItemsTableCreateCompanionBuilder,
    $$StockAuditItemsTableUpdateCompanionBuilder,
    (StockAuditItem, $$StockAuditItemsTableReferences),
    StockAuditItem,
    PrefetchHooks Function({bool sessionId, bool productId})>;
typedef $$BatchesTableCreateCompanionBuilder = BatchesCompanion Function({
  Value<int> id,
  required int productId,
  required String batchNumber,
  Value<DateTime?> expiryDate,
  Value<int> stockQty,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
});
typedef $$BatchesTableUpdateCompanionBuilder = BatchesCompanion Function({
  Value<int> id,
  Value<int> productId,
  Value<String> batchNumber,
  Value<DateTime?> expiryDate,
  Value<int> stockQty,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
});

final class $$BatchesTableReferences
    extends BaseReferences<_$AppDatabase, $BatchesTable, ProductBatch> {
  $$BatchesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProductsTable _productIdTable(_$AppDatabase db) =>
      db.products.createAlias('batch__product_id__product__id');

  $$ProductsTableProcessedTableManager get productId {
    final $_column = $_itemColumn<int>('product_id')!;

    final manager = $$ProductsTableTableManager($_db, $_db.products)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$BatchesTableFilterComposer
    extends Composer<_$AppDatabase, $BatchesTable> {
  $$BatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get batchNumber => $composableBuilder(
      column: $table.batchNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get expiryDate => $composableBuilder(
      column: $table.expiryDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get stockQty => $composableBuilder(
      column: $table.stockQty, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  $$ProductsTableFilterComposer get productId {
    final $$ProductsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productId,
        referencedTable: $db.products,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductsTableFilterComposer(
              $db: $db,
              $table: $db.products,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $BatchesTable> {
  $$BatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get batchNumber => $composableBuilder(
      column: $table.batchNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get expiryDate => $composableBuilder(
      column: $table.expiryDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get stockQty => $composableBuilder(
      column: $table.stockQty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  $$ProductsTableOrderingComposer get productId {
    final $$ProductsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productId,
        referencedTable: $db.products,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductsTableOrderingComposer(
              $db: $db,
              $table: $db.products,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BatchesTable> {
  $$BatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get batchNumber => $composableBuilder(
      column: $table.batchNumber, builder: (column) => column);

  GeneratedColumn<DateTime> get expiryDate => $composableBuilder(
      column: $table.expiryDate, builder: (column) => column);

  GeneratedColumn<int> get stockQty =>
      $composableBuilder(column: $table.stockQty, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$ProductsTableAnnotationComposer get productId {
    final $$ProductsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.productId,
        referencedTable: $db.products,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProductsTableAnnotationComposer(
              $db: $db,
              $table: $db.products,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BatchesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BatchesTable,
    ProductBatch,
    $$BatchesTableFilterComposer,
    $$BatchesTableOrderingComposer,
    $$BatchesTableAnnotationComposer,
    $$BatchesTableCreateCompanionBuilder,
    $$BatchesTableUpdateCompanionBuilder,
    (ProductBatch, $$BatchesTableReferences),
    ProductBatch,
    PrefetchHooks Function({bool productId})> {
  $$BatchesTableTableManager(_$AppDatabase db, $BatchesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> productId = const Value.absent(),
            Value<String> batchNumber = const Value.absent(),
            Value<DateTime?> expiryDate = const Value.absent(),
            Value<int> stockQty = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
          }) =>
              BatchesCompanion(
            id: id,
            productId: productId,
            batchNumber: batchNumber,
            expiryDate: expiryDate,
            stockQty: stockQty,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int productId,
            required String batchNumber,
            Value<DateTime?> expiryDate = const Value.absent(),
            Value<int> stockQty = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
          }) =>
              BatchesCompanion.insert(
            id: id,
            productId: productId,
            batchNumber: batchNumber,
            expiryDate: expiryDate,
            stockQty: stockQty,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$BatchesTable, ProductBatch>(table),
                    $$BatchesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({productId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (productId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.productId,
                    referencedTable:
                        $$BatchesTableReferences._productIdTable(db),
                    referencedColumn:
                        $$BatchesTableReferences._productIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$BatchesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BatchesTable,
    ProductBatch,
    $$BatchesTableFilterComposer,
    $$BatchesTableOrderingComposer,
    $$BatchesTableAnnotationComposer,
    $$BatchesTableCreateCompanionBuilder,
    $$BatchesTableUpdateCompanionBuilder,
    (ProductBatch, $$BatchesTableReferences),
    ProductBatch,
    PrefetchHooks Function({bool productId})>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db, _db.suppliers);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db, _db.products);
  $$LocationsTableTableManager get locations =>
      $$LocationsTableTableManager(_db, _db.locations);
  $$MovementsTableTableManager get movements =>
      $$MovementsTableTableManager(_db, _db.movements);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$StockAuditSessionsTableTableManager get stockAuditSessions =>
      $$StockAuditSessionsTableTableManager(_db, _db.stockAuditSessions);
  $$StockAuditItemsTableTableManager get stockAuditItems =>
      $$StockAuditItemsTableTableManager(_db, _db.stockAuditItems);
  $$BatchesTableTableManager get batches =>
      $$BatchesTableTableManager(_db, _db.batches);
}
