import 'package:flutter/material.dart';

import '../data/database.dart';
import '../services/license_service.dart';
import 'widgets/paywall_sheet.dart';

/// Guards a Pro-only feature, offering the upgrade if it is locked.
///
/// The paywall used to advertise barcode sticker printing and the voice
/// assistant as Pro while both were fully available free. Someone paying ₹499
/// for them already had them, and the upgrade screen was selling nothing.
/// This is the gate those two rows were always describing.
///
/// Deliberately **not** used for thermal slip printing. A free slip carries
/// the `StockSafe` mark, so every one a shopkeeper hands to a customer or
/// supplier advertises the app; gating printing would remove the only
/// distribution this app has. It is also the output of audits and stock
/// movements, which `LicenseService` promises stay free forever.
///
/// Returns true when the caller may proceed — either already unlocked, or
/// unlocked just now from the sheet.
Future<bool> requirePro(BuildContext context, AppDatabase db) async {
  if (await LicenseService(db).isProUnlocked()) return true;
  if (!context.mounted) return false;
  return await PaywallSheet.show(context) == true;
}
