import 'package:flutter/material.dart';

import '../data/database.dart';
import '../services/license_service.dart';

/// Where the shop's name is stored. Was a bare `'shop_name'` literal at every
/// call site, with three different fallbacks between them.
const String shopNameSettingKey = 'shop_name';

/// Shown in Settings before the shopkeeper has entered anything. It is a
/// prompt, not a value: it is never written to the database and never printed.
const String shopNamePlaceholder = 'STOCKSAFE KIRANA';

/// Who a printed slip is from, and whether the vendor mark goes on it.
class PrintIdentity {
  const PrintIdentity({required this.shopName, required this.proUnlocked});

  final String shopName;
  final bool proUnlocked;
}

/// Resolves the identity for a slip, asking for the shop name if it is unset.
///
/// Printing used to fall back to the literal `STOCKSAFE` when no name had been
/// entered, which put this app's name at the top of a slip handed to the
/// shopkeeper's customer. That is worse than not printing: the shop gets no
/// identity, and the slip reads as though it came from someone else.
///
/// So the name is asked for once, at the moment it is about to matter, rather
/// than guessed. Returns null if the shopkeeper backs out, in which case
/// nothing should be printed.
Future<PrintIdentity?> resolvePrintIdentity(
  BuildContext context,
  AppDatabase db,
) async {
  var name = (await db.settingDao.get(shopNameSettingKey))?.trim() ?? '';

  if (name.isEmpty) {
    if (!context.mounted) return null;
    final entered = await _askShopName(context);
    if (entered == null || entered.isEmpty) return null;
    await db.settingDao.set(shopNameSettingKey, entered);
    name = entered;
  }

  final proUnlocked = await LicenseService(db).isProUnlocked();
  return PrintIdentity(shopName: name, proUnlocked: proUnlocked);
}

Future<String?> _askShopName(BuildContext context) {
  final controller = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('What is your shop called?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This prints at the top of every slip you hand out, so your '
            'customers and suppliers know who it is from.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Shop name',
              hintText: 'e.g. Sri Lakshmi Stores',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
          const SizedBox(height: 8),
          Text(
            'You can change it later in Settings.',
            style: Theme.of(ctx).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Save and print'),
        ),
      ],
    ),
  );
}
