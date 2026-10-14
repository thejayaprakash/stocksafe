import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../services/app_localization.dart';
import '../services/license_service.dart';
import 'ask_stocksafe_page.dart';
import 'backup_page.dart';
import 'barcode_label_print_page.dart';
import 'pro_gate.dart';
import 'low_stock_page.dart';
import 'settings_page.dart';
import 'support_report_page.dart';
import 'suppliers_page.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocale.tr('more_tools') != 'more_tools' ? AppLocale.tr('more_tools') : 'More Operations & Tools'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Pro Status / Upgrade Card
          FutureBuilder<bool>(
            future: LicenseService(db).isProUnlocked(),
            builder: (context, snapshot) {
              final isPro = snapshot.data ?? false;
              if (isPro) {
                return Card(
                  elevation: 0,
                  color: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.workspace_premium, color: Color(0xFF10B981), size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'StockSafe Pro Active',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Lifetime unlimited products & offline features',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Card(
                elevation: 0,
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => PaywallSheet.show(context),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.stars, color: Colors.amber, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Upgrade to Pro — ₹499 Lifetime',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Track as many products as you like - the free tier stops at 100',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white70),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Section 1: Inventory & Suppliers
          _buildSectionHeader(theme, 'OPERATIONS & REORDERING'),
          _buildToolTile(
            context,
            icon: Icons.warning_amber_rounded,
            iconColor: Colors.amber.shade700,
            title: AppLocale.tr('low_stock'),
            subtitle: 'Velocity-based restock recommendations & alerts',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LowStockPage())),
          ),
          _buildToolTile(
            context,
            icon: Icons.local_shipping_outlined,
            iconColor: const Color(0xFF3B82F6),
            title: AppLocale.tr('suppliers'),
            subtitle: 'Vendor directory, WhatsApp PO dispatch & purchase orders',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SuppliersPage())),
          ),
          const SizedBox(height: 16),

          // Section 2: Hardware & Utilities
          _buildSectionHeader(theme, 'PRINTING & LABELS'),
          _buildToolTile(
            context,
            icon: Icons.qr_code_2_rounded,
            iconColor: const Color(0xFF10B981),
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
            iconColor: Colors.purple.shade400,
            title: AppLocale.tr('ask_ai'),
            subtitle: 'Offline inventory questions, valuation & stock queries',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AskStockSafePage())),
          ),
          const SizedBox(height: 16),

          // Section 3: Data Safety & System
          _buildSectionHeader(theme, 'HELP'),
          _buildToolTile(
            context,
            icon: Icons.support_agent_outlined,
            iconColor: const Color(0xFF6366F1),
            title: 'Report a problem',
            subtitle: 'Send a diagnostic report — counts only, never your product data',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SupportReportPage()),
            ),
          ),

          _buildSectionHeader(theme, 'DATA & SYSTEM'),
          _buildToolTile(
            context,
            icon: Icons.security_rounded,
            iconColor: const Color(0xFF10B981),
            title: AppLocale.tr('backup_data') != 'backup_data' ? AppLocale.tr('backup_data') : 'Backup & Data Recovery',
            subtitle: 'Cryptographic SHA-256 snapshots, CSV catalog import & export',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupPage())),
          ),
          _buildToolTile(
            context,
            icon: Icons.settings_outlined,
            iconColor: Colors.blueGrey,
            title: AppLocale.tr('settings'),
            subtitle: 'Store profile, English/Tamil language, database health',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
    );
  }

  static Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
          letterSpacing: 0.8,
        ),
      ),
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
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}
