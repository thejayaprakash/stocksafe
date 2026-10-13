import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'setting_dao.g.dart';

@DriftAccessor(tables: [Settings])
class SettingDao extends DatabaseAccessor<AppDatabase> with _$SettingDaoMixin {
  SettingDao(super.db);

  static const lastBackupAtKey = 'last_backup_at';
  static const backupEnabledKey = 'backup_enabled';
  static const freeLimitKey = 'free_product_limit';

  /// Reference of the last problem report the shopkeeper sent, so Help &
  /// Support can show it back to them. A report sent on WhatsApp is only
  /// traceable if both sides can quote the same string.
  static const lastSupportRefKey = 'last_support_reference';
  static const lastSupportAtKey = 'last_support_at';

  Future<String?> get(String key) async {
    final row = await (select(settings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) async {
    await into(settings).insertOnConflictUpdate(
      SettingsCompanion.insert(key: key, value: value),
    );
  }
}
