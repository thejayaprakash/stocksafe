/// Turns a ledger reason code into something a shopkeeper reads.
///
/// Movement reasons are stored as identifiers - `opening_stock`,
/// `transfer_in` - because the ledger is append-only and queried on them.
/// They are not words anybody should be shown.
///
/// This lived as a private static on ProductDetailPage, which is exactly why
/// it had to be written twice. `transfer_in` and `transfer_out` leaked into
/// the movement history once and were fixed there; the home dashboard then
/// shipped its own `'${m.reason} · ...'` and leaked `opening_stock` in the
/// same way, because the mapping was not reachable from outside that one
/// file. It is top-level now so the next screen that lists movements has
/// something to call.
library;

const Map<String, String> _labels = {
  'opening_stock': 'Opening stock',
  'purchase': 'Purchase',
  'sale': 'Sale',
  'damage': 'Damage',
  'return': 'Return',
  'transfer_in': 'Moved in',
  'transfer_out': 'Moved out',
  'stocktake_adjustment': 'Stocktake adjustment',
};

/// Every reason code this app writes, for tests that check each one maps.
Iterable<String> get knownMovementReasons => _labels.keys;

/// The label for [reason], or the reason itself when it is not one of ours.
///
/// Unmapped values are returned unchanged rather than mangled: a user's
/// ledger can already hold free text typed into the stock movement screen,
/// and "Damaged in transit" is better shown as-is than title-cased into
/// something they did not write.
String readableMovementReason(String reason) => _labels[reason] ?? reason;
