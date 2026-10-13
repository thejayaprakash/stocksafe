# StockSafe

Offline stock manager for small shops. One promise: **it never loses your data.**

Flutter (Android + iOS), local-only SQLite via [Drift](https://drift.simonbinder.eu/).

## The core design

Stock level is never a number you overwrite. It is derived from an append-only
movement ledger:

```
current stock = SELECT SUM(qty_delta) FROM movement WHERE product_id = ?
```

- `product.stock_qty` is a **cache** for list speed — always rebuildable from the ledger
- `movement` rows are append-only (insert only; no updates, no deletes)
- Products are **soft-deleted** (`deleted_at`), never dropped
- Every schema change ships with a tested migration — never destructive

## Commands

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generate drift code
flutter analyze
flutter test
flutter run
```

## Project layout

```
lib/
  main.dart                  # app entry, cache rebuild on launch
  src/
    data/
      tables.dart            # drift table definitions
      database.dart          # AppDatabase + DatabaseMigrations
      backup_service.dart    # local rolling snapshots, CSV export
      dao/
        product_dao.dart     # soft delete, indexed search, cache rebuild, low stock
        movement_dao.dart    # append-only ledger writes (transactional)
        setting_dao.dart     # key/value store
    ui/
      home_page.dart         # bottom nav shell: Products, Low Stock, Settings
      product_edit_page.dart # add/edit with barcode pre-fill from scanner
      product_detail_page.dart
      stock_movement_page.dart
      scanner_page.dart      # CameraX + ML Kit barcode scanning
      low_stock_page.dart    # filtered list: stock_qty <= low_stock_level
      settings_page.dart     # cache rebuild, backup link, about
      backup_page.dart       # snapshot create/restore, CSV export & share
test/
  ledger_test.dart           # ledger, cache rebuild, soft delete, search
```

## Rules you do not break

1. Never `fallbackToDestructiveMigration()` / destructive migration — that one line
   is how the competitor deleted its users' products.
2. Every schema change ships with a tested migration (dump schemas with
   `dart run drift_dev schema dump lib/src/data/database.dart drift_schemas/`
   and test with `dart run drift_dev schema test`).
3. No blocking I/O on the UI isolate.
4. Soft delete everywhere.
5. Never put a paywall in front of backup of data a user already entered.

## Roadmap (from stocksafe.md)

- [x] Phase 2 core: data model, product list, stock in/out, detail, search
- [x] Phase 3: barcode scanning (mobile_scanner, bundled model), low-stock screen
- [x] Phase 4: backup — local rolling snapshots (7-copy rotation), CSV/zip export
- [ ] Phase 5: paywall (free ≤ 50 products), one-time unlock via Play Billing / RevenueCat
- [ ] Phase 6: closed testing (12 testers × 14 days if Personal account)
- [ ] Phase 7: store listing and launch

