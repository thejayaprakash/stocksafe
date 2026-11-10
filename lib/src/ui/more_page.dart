import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../services/app_localization.dart';
import '../services/license_service.dart';
import '../services/theme_service.dart';
import 'ask_stocksafe_page.dart';
import 'backup_page.dart';
import 'barcode_label_print_page.dart';
import 'pro_gate.dart';
import 'low_stock_page.dart';
import 'settings_page.dart';
import 'support_report_page.dart';
import 'suppliers_page.dart';
import 'widgets/app_tiles.dart';
import 'widgets/paywall_sheet.dart';

/// "More" hub for secondary and advanced operational tools.
/// Implements progressive disclosure: keeping the primary 4 tabs
/// laser-focused on Home, Products, Scan, and Stock Count, while
/// providing friction-free access to utilities here.
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = AppScope.read(context).db;
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocale.tr('more_tools') != 'more_tools' ? AppLocale.tr('more_tools') : 'More Operations & Tools'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Pro Status / Upgrade Card
          FutureBuilder<(bool, int)>(
            future: () async {
              final lic = LicenseService(db);
              final isPro = await lic.isProUnlocked();
              final cap = await lic.getEffectiveCapacity();
              return (isPro, cap);
            }(),
            builder: (context, snapshot) {
              // Null while the check is in flight. Rendering the upgrade
              // offer during that frame would flash "Upgrade to Pro" at
              // somebody who has already paid, so nothing is shown until the
              // answer is in.
              if (!snapshot.hasData) return const SizedBox(height: 74);
              final (isPro, capacity) = snapshot.data!;
              return _ProCard(
                isPro: isPro,
                effectiveCapacity: capacity,
                onTap: isPro ? null : () => PaywallSheet.show(context),
              );
            },
          ),
          const SizedBox(height: 16),

          // Section 1: Inventory & Suppliers
          _buildSectionHeader(theme, 'Operations & Reordering'),
          _buildToolTile(
            context,
            icon: Icons.warning_amber_rounded,
            iconColor: palette.warning,
            title: AppLocale.tr('low_stock'),
            subtitle: 'Velocity-based restock recommendations & alerts',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LowStockPage())),
          ),
          _buildToolTile(
            context,
            icon: Icons.local_shipping_outlined,
            iconColor: palette.primary,
            title: AppLocale.tr('suppliers'),
            subtitle: 'Vendor directory, WhatsApp PO dispatch & purchase orders',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SuppliersPage())),
          ),
          const SizedBox(height: 16),

          // Section 2: Hardware & Utilities
          _buildSectionHeader(theme, 'Printing & Labels'),
          _buildToolTile(
            context,
            icon: Icons.qr_code_2_rounded,
            iconColor: palette.brandSuccess,
            title: AppLocale.tr('barcode_label_printing'),
            subtitle: 'Generate sticker sheets (A4 or thermal rolls) with Code 128 / QR',
            onTap: () async {
              if (!await requirePro(context, db)) return;
              if (!context.mounted) return;
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const BarcodeLabelPrintPage()));
            },
          ),
          _buildToolTile(
            context,
            icon: Icons.auto_awesome,
            iconColor: palette.secondary,
            title: AppLocale.tr('ask_ai'),
            subtitle: 'Offline inventory questions, valuation & stock queries',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AskStockSafePage())),
          ),
          const SizedBox(height: 16),

          // Section 3: Data Safety & System
          _buildSectionHeader(theme, 'Help'),
          _buildToolTile(
            context,
            icon: Icons.support_agent_outlined,
            iconColor: palette.info,
            title: 'Report a problem',
            subtitle: 'Send a diagnostic report — counts only, never your product data',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SupportReportPage()),
            ),
          ),

          _buildSectionHeader(theme, 'Data & System'),
          _buildToolTile(
            context,
            icon: Icons.security_rounded,
            iconColor: palette.brandSuccess,
            title: AppLocale.tr('backup_data') != 'backup_data' ? AppLocale.tr('backup_data') : 'Backup & Data Recovery',
            subtitle: 'Cryptographic SHA-256 snapshots, CSV catalog import & export',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupPage())),
          ),
          _buildToolTile(
            context,
            icon: Icons.settings_outlined,
            iconColor: palette.textTertiary,
            title: AppLocale.tr('settings'),
            subtitle: 'Store profile, English/Tamil language, database health',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
    );
  }

  static Widget _buildSectionHeader(ThemeData theme, String title) {
    return SectionTitle(
      title,
      padding: const EdgeInsets.only(left: 2, bottom: 8),
    );
  }

  static Widget _buildToolTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ToolTile(
      icon: icon,
      accent: iconColor,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }
}

/// The gold banner at the top of More: the licence state, and the way to
/// change it.
class _ProCard extends StatelessWidget {
  const _ProCard({required this.isPro, this.effectiveCapacity = 50, this.onTap});

  final bool isPro;
  final int effectiveCapacity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gold = Color(0xFFF59E0B);
    final radius = BorderRadius.circular(14);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Material(
        color: gold.withValues(alpha: isDark ? 0.14 : 0.10),
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: gold.withValues(alpha: 0.38)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 13, 12, 13),
            child: Row(
              children: [
                Icon(
                  isPro
                      ? Icons.workspace_premium_rounded
                      : Icons.emoji_events_rounded,
                  size: 28,
                  color: gold,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPro
                            ? 'StockSafe Pro Active'
                            : 'Upgrade to Pro — ₹499 Lifetime',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isPro
                            ? 'Lifetime unlimited products & offline features'
                            : 'Track as many products as you like — the free tier allows $effectiveCapacity products',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.3,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isPro)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: palette.textTertiary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
