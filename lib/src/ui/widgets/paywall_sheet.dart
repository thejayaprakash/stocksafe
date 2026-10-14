import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../services/app_localization.dart';
import '../../services/billing_service.dart';
import '../../services/license_service.dart';
import '../../app_scope.dart';

/// Clean, non-nagging Paywall Sheet for StockSafe Pro.
///
/// Triggers when:
/// 1. Retailer hits the 100-product free tier limit and tries to add product #101.
/// 2. Retailer accesses "Upgrade to Pro" from Settings.
class PaywallSheet extends StatefulWidget {
  const PaywallSheet({super.key, this.onUnlocked});

  final VoidCallback? onUnlocked;

  /// Show paywall as a modal bottom sheet.
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaywallSheet(
        onUnlocked: () => Navigator.pop(ctx, true),
      ),
    );
  }

  @override
  State<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<PaywallSheet> {
  /// The live database, read through the scope rather than passed in.
  /// Uses [AppScope.read] so it is safe to call from initState; widgets that
  /// must rebuild when the connection is replaced should call AppScope.of in
  /// build instead.
  AppDatabase get _db => AppScope.read(context).db;

  late final LicenseService _licenseService;
  late final BillingService _billing;
  bool _isLoading = false;
  int _activeCount = 0;
  // Shown only until the real limit loads from LicenseService a frame later.
  // Kept in step with LicenseService.defaultFreeLimit so the sheet never
  // flashes a number the app does not enforce.
  int _freeLimit = LicenseService.defaultFreeLimit;

  @override
  void initState() {
    super.initState();
    _licenseService = LicenseService(_db);
    _billing = BillingService();
    _loadState();
  }

  Future<void> _loadState() async {
    final count = await _db.productDao.countActive();
    final limit = await _licenseService.getFreeLimit();
    if (mounted) {
      setState(() {
        _activeCount = count;
        _freeLimit = limit;
      });
    }
  }

  /// Buys through Google Play, and unlocks only on what Play confirms.
  ///
  /// Every outcome gets its own sentence. A shopkeeper who paid by UPI and a
  /// shopkeeper whose card was declined are in completely different positions,
  /// and one message for both leaves the first one convinced the app took
  /// their money and gave nothing back.
  @override
  void dispose() {
    // Cancels the purchase stream subscription. Without this, every open of
    // the paywall leaves another listener attached to the plugin's broadcast
    // stream for the life of the process.
    _billing.dispose();
    super.dispose();
  }

  Future<void> _handleUnlock() async {
    setState(() => _isLoading = true);
    try {
      final result = await _licenseService.purchasePro(_billing);
      if (!mounted) return;

      if (result.grantsUnlock) {
        _say(AppLocale.tr('pro_unlocked_success'), good: true);
        widget.onUnlocked?.call();
        return;
      }

      switch (result.outcome) {
        case BillingOutcome.pending:
          // UPI and net-banking settle asynchronously. Saying "failed" here is
          // wrong and alarming; saying "done" would give the app away.
          _say(
            'Payment started. UPI and bank payments can take a while to '
            'confirm — Pro unlocks automatically once your bank completes it. '
            'You can keep using StockSafe meanwhile.',
            seconds: 9,
          );
        case BillingOutcome.cancelled:
          break; // They chose to stop. Nothing to report.
        case BillingOutcome.unavailable:
          _say(
            result.message ??
                'In-app purchase is not available on this device. If you have '
                'an activation voucher, use "Enter activation code".',
            seconds: 7,
          );
        case BillingOutcome.failed:
          _say(result.message ?? 'The store could not complete that purchase.');
        case BillingOutcome.nothingToRestore:
        case BillingOutcome.purchased:
        case BillingOutcome.restored:
          break; // Handled above.
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _say(String message, {bool good = false, int seconds = 5}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: seconds),
        backgroundColor: good ? Colors.green.shade700 : null,
      ),
    );
  }

  Future<void> _handleRestore() async {
    setState(() => _isLoading = true);
    try {
      final result = await _licenseService.restoreFromPlay(_billing);
      if (!mounted) return;

      if (result.grantsUnlock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocale.tr('purchases_restored')),
            backgroundColor: Colors.green.shade700,
          ),
        );
        widget.onUnlocked?.call();
      } else {
        // Play is the authority here, not this device: the entitlement lives
        // with the Google account, which is what makes a reinstall or a new
        // phone free.
        _say(
          result.outcome == BillingOutcome.unavailable
              ? (result.message ?? 'The Play Store is not available here.')
              : 'No previous purchase was found for this Google account.',
          seconds: 6,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _enterActivationCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Offline Activation Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your 16-character retail voucher or license key:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'e.g. STOCKSAFE-XXXX-XXXX',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Activate'),
          ),
        ],
      ),
    );

    if (code != null && code.isNotEmpty) {
      setState(() => _isLoading = true);
      final activated = await _licenseService.validateAndActivateOfflineKey(code);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (activated) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocale.tr('pro_unlocked_success')),
            backgroundColor: Colors.green.shade700,
          ),
        );
        widget.onUnlocked?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid activation key. Please check and try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Crown / Pro Header badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocale.tr('paywall_title'),
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$_activeCount / $_freeLimit ${AppLocale.tr('products_used_free')}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _activeCount >= _freeLimit ? Colors.orange.shade800 : null,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Price Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                    theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '₹499',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(\$5.99 USD)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'ONE-TIME UNLOCK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppLocale.tr('paywall_no_subscription'),
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Feature bullet list
            _FeatureRow(
              icon: Icons.all_inclusive,
              title: AppLocale.tr('feature_unlimited_products'),
              subtitle: AppLocale.tr('feature_unlimited_desc'),
            ),
            _FeatureRow(
              icon: Icons.qr_code_2,
              title: AppLocale.tr('feature_barcode_stickers'),
              subtitle: AppLocale.tr('feature_barcode_desc'),
            ),
            _FeatureRow(
              icon: Icons.graphic_eq,
              title: AppLocale.tr('feature_voice_assistant'),
              subtitle: AppLocale.tr('feature_voice_desc'),
            ),
            _FeatureRow(
              icon: Icons.storefront,
              title: AppLocale.tr('feature_own_branding'),
              subtitle: AppLocale.tr('feature_own_branding_desc'),
            ),

            const SizedBox(height: 12),

            // Data Safety Promise
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Colors.blue, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppLocale.tr('paywall_data_guarantee'),
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.blue.shade800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Main CTA Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _isLoading ? null : _handleUnlock,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        '${AppLocale.tr("unlock_unlimited_btn")} · ₹499',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Secondary actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _handleRestore,
                    child: Text(AppLocale.tr('restore_purchases_btn')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: _isLoading ? null : _enterActivationCode,
                    child: const Text('Activation Code'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
