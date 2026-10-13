import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'location_dao.g.dart';

/// Stock held at a particular place.
///
/// Enterprise systems treat a location as where stock *is*, not as a label on
/// it: Odoo moves quantities between locations, NetSuite and Zoho Inventory
/// hold a separate balance and reorder level per warehouse. The same idea
/// applies at kirana scale — a shop and its godown hold different amounts of
/// the same item, and "do I need to reorder" has a different answer in each.
///
/// StockSafe keeps the signed-delta ledger it already had and partitions it:
/// stock at a location is `SUM(qty_delta)` filtered by location, and the
/// product total is the same sum unfiltered. Adding locations therefore
/// changes no existing number.
@DriftAccessor(tables: [Locations, Movements, Products])
class LocationDao extends DatabaseAccessor<AppDatabase> with _$LocationDaoMixin {
  LocationDao(super.db);

  // ── The places themselves ───────────────────────────────────────

  Stream<List<Location>> watchAll() => (select(locations)
        ..where((l) => l.deletedAt.isNull())
        ..orderBy([
          // Default first, then alphabetical — the shop before the godown.
          (l) => OrderingTerm.desc(l.isDefault),
          (l) => OrderingTerm.asc(l.name),
        ]))
      .watch();

  Future<List<Location>> getAll() => (select(locations)
        ..where((l) => l.deletedAt.isNull())
        ..orderBy([
          (l) => OrderingTerm.desc(l.isDefault),
          (l) => OrderingTerm.asc(l.name),
        ]))
      .get();

  Future<Location?> getById(int id) =>
      (select(locations)..where((l) => l.id.equals(id))).getSingleOrNull();

  /// The location new movements default to.
  ///
  /// Creates one if the table is empty, so a database that somehow reaches
  /// the app without the v6 backfill still has somewhere to put stock rather
  /// than failing every write.
  Future<Location> getOrCreateDefault() async {
    final existing = await (select(locations)
          ..where((l) => l.isDefault.equals(true) & l.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return existing;

    final anyLive = await (select(locations)
          ..where((l) => l.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
    if (anyLive != null) {
      await setDefault(anyLive.id);
      return (await getById(anyLive.id))!;
    }

    final now = DateTime.now();
    final id = await into(locations).insert(
      LocationsCompanion.insert(
        name: DatabaseMigrations.defaultLocationName,
        isDefault: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return (await getById(id))!;
  }

  Future<int> createLocation({required String name, String? note}) {
    final now = DateTime.now();
    return into(locations).insert(
      LocationsCompanion.insert(
        name: name.trim(),
        note: Value(note?.trim()),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> rename(int id, String name, {String? note}) async {
    await (update(locations)..where((l) => l.id.equals(id))).write(
      LocationsCompanion(
        name: Value(name.trim()),
        note: Value(note?.trim()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Exactly one location is the default; setting one clears the rest.
  Future<void> setDefault(int id) async {
    await transaction(() async {
      await update(locations).write(const LocationsCompanion(isDefault: Value(false)));
      await (update(locations)..where((l) => l.id.equals(id))).write(
        LocationsCompanion(
          isDefault: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  /// Soft-deletes a location.
  ///
  /// Refuses while it still holds stock, and refuses to remove the last one.
  /// Hiding a place that holds 40 bags of rice would make that stock vanish
  /// from every per-location view while still counting towards the product
  /// total — the two would disagree with no way to see why. Move the stock
  /// out first; the ledger keeps the history either way.
  Future<void> softDelete(int id) async {
    final live = await getAll();
    if (live.length <= 1) {
      throw StateError('There must always be at least one location.');
    }
    final held = await stockAt(id);
    if (held != 0) {
      throw StateError(
        'This location still holds stock. Transfer it elsewhere first.',
      );
    }

    final now = DateTime.now();
    final wasDefault = (await getById(id))?.isDefault ?? false;
    await (update(locations)..where((l) => l.id.equals(id)))
        .write(LocationsCompanion(deletedAt: Value(now), updatedAt: Value(now)));

    if (wasDefault) {
      final remaining = await getAll();
      if (remaining.isNotEmpty) await setDefault(remaining.first.id);
    }
  }

  // ── Balances ────────────────────────────────────────────────────

  /// Total units held at a location, across every product.
  Future<int> stockAt(int locationId) async {
    final row = await customSelect(
      'SELECT COALESCE(SUM(qty_delta), 0) AS total FROM movement '
      'WHERE location_id = ?1',
      variables: [Variable<int>(locationId)],
      readsFrom: {movements},
    ).getSingle();
    return row.read<int>('total');
  }

  /// One product's balance at one location.
  Future<int> stockOf(int productId, int locationId) async {
    final row = await customSelect(
      'SELECT COALESCE(SUM(qty_delta), 0) AS total FROM movement '
      'WHERE product_id = ?1 AND location_id = ?2',
      variables: [Variable<int>(productId), Variable<int>(locationId)],
      readsFrom: {movements},
    ).getSingle();
    return row.read<int>('total');
  }

  /// Where one product's stock actually sits.
  ///
  /// Locations holding nothing are omitted, so the breakdown answers "where
  /// is it" rather than listing every place in the shop against a zero.
  Stream<List<LocationStock>> watchBreakdownFor(int productId) {
    return customSelect(
      '''
      SELECT l.id          AS location_id,
             l.name        AS location_name,
             l.is_default  AS is_default,
             COALESCE(SUM(m.qty_delta), 0) AS qty
      FROM location l
      LEFT JOIN movement m
        ON m.location_id = l.id AND m.product_id = ?1
      WHERE l.deleted_at IS NULL
      GROUP BY l.id, l.name, l.is_default
      HAVING COALESCE(SUM(m.qty_delta), 0) != 0
      ORDER BY qty DESC, l.name
      ''',
      variables: [Variable<int>(productId)],
      readsFrom: {locations, movements},
    ).watch().map((rows) => rows.map(LocationStock.fromRow).toList());
  }

  /// Every live location with the number of units it holds.
  Stream<List<LocationStock>> watchTotals() {
    return customSelect(
      '''
      SELECT l.id          AS location_id,
             l.name        AS location_name,
             l.is_default  AS is_default,
             COALESCE(SUM(m.qty_delta), 0) AS qty
      FROM location l
      LEFT JOIN movement m ON m.location_id = l.id
      WHERE l.deleted_at IS NULL
      GROUP BY l.id, l.name, l.is_default
      ORDER BY l.is_default DESC, l.name
      ''',
      readsFrom: {locations, movements},
    ).watch().map((rows) => rows.map(LocationStock.fromRow).toList());
  }
}

/// A quantity held at a named place.
class LocationStock {
  const LocationStock({
    required this.locationId,
    required this.locationName,
    required this.isDefault,
    required this.quantity,
  });

  factory LocationStock.fromRow(QueryRow row) => LocationStock(
        locationId: row.read<int>('location_id'),
        locationName: row.read<String>('location_name'),
        isDefault: row.read<int>('is_default') == 1,
        quantity: row.read<int>('qty'),
      );

  final int locationId;
  final String locationName;
  final bool isDefault;
  final int quantity;
}
