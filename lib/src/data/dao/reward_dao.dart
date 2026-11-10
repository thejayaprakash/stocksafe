import 'dart:async';
import 'package:drift/drift.dart';
import '../database.dart';
import '../../services/reward_config.dart';

/// Data class representing an active or historical reward entitlement.
class RewardEntitlementRecord {
  const RewardEntitlementRecord({
    this.id,
    required this.rewardTransactionId,
    this.rewardType = 'product_capacity',
    this.rewardAmount = RewardConfig.rewardSlotsPerAd,
    required this.earnedAt,
    required this.expiresAt,
    this.verificationStatus = 'verified',
    this.source = 'admob_rewarded',
    required this.createdAt,
  });

  final int? id;
  final String rewardTransactionId;
  final String rewardType;
  final int rewardAmount;
  final DateTime earnedAt;
  final DateTime expiresAt;
  final String verificationStatus;
  final String source;
  final DateTime createdAt;

  bool get isExpired => expiresAt.isBefore(DateTime.now());
  bool get isValid => verificationStatus == 'verified' && !isExpired;

  factory RewardEntitlementRecord.fromRow(TypedResult row) {
    return RewardEntitlementRecord(
      id: row.read<int>('id'),
      rewardTransactionId: row.read<String>('reward_transaction_id'),
      rewardType: row.read<String>('reward_type'),
      rewardAmount: row.read<int>('reward_amount'),
      earnedAt: DateTime.parse(row.read<String>('earned_at')),
      expiresAt: DateTime.parse(row.read<String>('expires_at')),
      verificationStatus: row.read<String>('verification_status'),
      source: row.read<String>('source'),
      createdAt: DateTime.parse(row.read<String>('created_at')),
    );
  }
}

/// DAO for interacting with the `reward_entitlement` SQLite table.
///
/// Ensures backward compatibility with existing schemas by dynamically ensuring
/// table presence without requiring destructive schema resets.
class RewardDao {
  RewardDao(this._db);

  final AppDatabase _db;
  bool _tableInitialized = false;

  /// Ensures the reward_entitlement table and associated indexes exist in SQLite.
  Future<void> ensureTableExists() async {
    if (_tableInitialized) return;
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS reward_entitlement (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reward_transaction_id TEXT NOT NULL UNIQUE,
        reward_type TEXT NOT NULL DEFAULT 'product_capacity',
        reward_amount INTEGER NOT NULL DEFAULT 2,
        earned_at TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        verification_status TEXT NOT NULL DEFAULT 'verified',
        source TEXT NOT NULL DEFAULT 'admob_rewarded',
        created_at TEXT NOT NULL
      );
    ''');
    await _db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_reward_tx ON reward_entitlement(reward_transaction_id);
    ''');
    await _db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_reward_expires ON reward_entitlement(expires_at);
    ''');
    _tableInitialized = true;
  }

  /// Checks if a transaction identifier has already been recorded.
  Future<bool> hasTransaction(String transactionId) async {
    await ensureTableExists();
    final rows = await _db.customSelect(
      'SELECT 1 FROM reward_entitlement WHERE reward_transaction_id = ?1 LIMIT 1',
      variables: [Variable<String>(transactionId)],
    ).get();
    return rows.isNotEmpty;
  }

  /// Inserts a newly verified reward entitlement.
  /// Returns `true` if inserted, `false` if duplicate transactionId or failed.
  Future<bool> insertReward(RewardEntitlementRecord record) async {
    await ensureTableExists();
    try {
      final insertedId = await _db.customInsert(
        '''
        INSERT INTO reward_entitlement (
          reward_transaction_id, reward_type, reward_amount,
          earned_at, expires_at, verification_status, source, created_at
        ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
        ''',
        variables: [
          Variable<String>(record.rewardTransactionId),
          Variable<String>(record.rewardType),
          Variable<int>(record.rewardAmount),
          Variable<String>(record.earnedAt.toIso8601String()),
          Variable<String>(record.expiresAt.toIso8601String()),
          Variable<String>(record.verificationStatus),
          Variable<String>(record.source),
          Variable<String>(record.createdAt.toIso8601String()),
        ],
      );
      return insertedId > 0;
    } catch (_) {
      // Handles UNIQUE constraint violation or database error
      return false;
    }
  }

  /// Calculates the total number of currently active, non-expired verified reward slots.
  Future<int> getActiveRewardSlots({DateTime? asOf}) async {
    await ensureTableExists();
    final nowStr = (asOf ?? DateTime.now()).toIso8601String();
    final row = await _db.customSelect(
      '''
      SELECT COALESCE(SUM(reward_amount), 0) AS total_slots
      FROM reward_entitlement
      WHERE verification_status = 'verified'
        AND expires_at > ?1
      ''',
      variables: [Variable<String>(nowStr)],
    ).getSingle();
    return row.read<int>('total_slots');
  }

  /// Gets the count of rewarded ads completed today (calendar day in local time).
  Future<int> getDailyCompletedCount({DateTime? forDate}) async {
    await ensureTableExists();
    final target = forDate ?? DateTime.now();
    final startOfDay = DateTime(target.year, target.month, target.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final row = await _db.customSelect(
      '''
      SELECT COUNT(*) AS c
      FROM reward_entitlement
      WHERE verification_status = 'verified'
        AND earned_at >= ?1 AND earned_at < ?2
      ''',
      variables: [
        Variable<String>(startOfDay.toIso8601String()),
        Variable<String>(endOfDay.toIso8601String()),
      ],
    ).getSingle();
    return row.read<int>('c');
  }

  /// Fetches all active unexpired verified reward records.
  Future<List<RewardEntitlementRecord>> getActiveRewards({DateTime? asOf}) async {
    await ensureTableExists();
    final nowStr = (asOf ?? DateTime.now()).toIso8601String();
    final rows = await _db.customSelect(
      '''
      SELECT id, reward_transaction_id, reward_type, reward_amount,
             earned_at, expires_at, verification_status, source, created_at
      FROM reward_entitlement
      WHERE verification_status = 'verified'
        AND expires_at > ?1
      ORDER BY expires_at ASC
      ''',
      variables: [Variable<String>(nowStr)],
    ).get();

    return rows.map((r) => RewardEntitlementRecord.fromRow(r)).toList();
  }

  /// Clears all stored rewards (e.g. during testing or backup restoration).
  Future<void> clearAll() async {
    await ensureTableExists();
    await _db.customStatement('DELETE FROM reward_entitlement');
  }
}
