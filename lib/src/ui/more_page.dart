import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/database.dart';
import '../services/app_localization.dart';
import '../services/license_service.dart';
import '../theme/app_palette.dart';
import 'ask_stocksafe_page.dart';
import 'backup_page.dart';
import 'barcode_label_print_page.dart';
import 'low_stock_page.dart';
import 'pro_gate.dart';
import 'settings_page.dart';
import 'suppliers_page.dart';
import 'support_report_page.dart';
import 'widgets/floating_wave_nav_bar.dart';
import 'widgets/paywall_sheet.dart';

/// "More Operations & Tools" Hub.
///
/// Designed as a high-density, professional business operations center
/// with dedicated feature cards for inventory replenishment, vendor management,
/// barcode label printing, offline AI insights, diagnostic support, and data safety.
class MorePage extends StatefulWidget {
  const MorePage({super.key});

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  Stream<LicenseStatus>? _licenseStream;
  AppDatabase? _lastDb;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final db = AppScope.read(context).db;
    if (_licenseStream == null || _lastDb != db) {
      _lastDb = db;
      _licenseStream = LicenseService(db).watchLicenseStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = AppScope.read(context).db;
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Bottom margin ensures full scrollability above the floating navigation bar
    final bottomNavPadding = FloatingWaveNavBar.totalHeight(context) + 24;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1220) : palette.appBackground,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottomNavPadding),
          children: [
            // ── Header ──────────────────────────────────────────────
            _buildHeader(context),
            const SizedBox(height: 14),

            // ── Pro Status / Upgrade Banner ─────────────────────────
            StreamBuilder<LicenseStatus>(
              stream: _licenseStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(height: 84);
                }
                final status = snapshot.data!;
                final isPro = status.isPro;
                final active = status.activeProductCount;
                final bonusSlots = status.rewardSlots;
                final capacity = status.effectiveCapacity;
                final remaining = status.remaining;

                return _ProBannerCard(
                  isPro: isPro,
                  activeProducts: active,
                  effectiveCapacity: capacity,
                  remainingSlots: remaining,
                  bonusSlots: bonusSlots,
                  onTap: isPro ? null : () => PaywallSheet.show(context),
                );
              },
            ),
            const SizedBox(height: 18),

            // ── Section 1: Operations & Reordering ──────────────────
            const _MoreSectionHeader(
              icon: Icons.layers_rounded,
              title: 'Operations & Reordering',
              subtitle: 'Keep stock levels healthy and manage your supply chain.',
            ),
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _OperationsCard(
                      accentColor: const Color(0xFFF59E0B),
                      icon: Icons.warning_amber_rounded,
                      title: AppLocale.tr('low_stock') != 'low_stock'
                          ? AppLocale.tr('low_stock')
                          : 'Low Stock',
                      description:
                          'Get smart reorder recommendations & alerts before you run out.',
                      visual: const _LowStockVisual(),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LowStockPage()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OperationsCard(
                      accentColor: const Color(0xFF3B82F6),
                      icon: Icons.local_shipping_rounded,
                      title: AppLocale.tr('suppliers') != 'suppliers'
                          ? AppLocale.tr('suppliers')
                          : 'Suppliers & Vendors',
                      description:
                          'Manage your supplier list, create purchase orders, and share PO on WhatsApp.',
                      visual: const _SuppliersVisual(),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SuppliersPage()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ── Section 2: Printing & Labels ────────────────────────
            const _MoreSectionHeader(
              icon: Icons.print_rounded,
              title: 'Printing & Labels',
              subtitle: 'Create and print product labels for faster inventory management.',
            ),
            const SizedBox(height: 10),
            _BarcodePrintingCard(
              onTap: () async {
                if (!await requirePro(context, db)) return;
                if (!context.mounted) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BarcodeLabelPrintPage()),
                );
              },
            ),
            const SizedBox(height: 22),

            // ── Section 3: AI Assistant ─────────────────────────────
            const _MoreSectionHeader(
              icon: Icons.auto_awesome,
              iconColor: Color(0xFF8B5CF6),
              title: 'AI Assistant',
              subtitle: 'Get instant, offline insights about your inventory.',
            ),
            const SizedBox(height: 10),
            _AskStockSafeAiCard(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AskStockSafePage()),
              ),
              onSelectQuestion: (query) => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AskStockSafePage(initialQuery: query)),
              ),
            ),
            const SizedBox(height: 22),

            // ── Section 4: Help ─────────────────────────────────────
            const _MoreSectionHeader(
              icon: Icons.help_outline_rounded,
              title: 'Help',
            ),
            const SizedBox(height: 10),
            _ToolTileCard(
              icon: Icons.support_agent_rounded,
              accentColor: const Color(0xFF3B82F6),
              title: 'Report a problem',
              subtitle:
                  'Send a diagnostic report — counts only, never your product data.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SupportReportPage()),
              ),
            ),
            const SizedBox(height: 22),

            // ── Section 5: Data & System ────────────────────────────
            const _MoreSectionHeader(
              icon: Icons.storage_rounded,
              title: 'Data & System',
            ),
            const SizedBox(height: 10),
            _ToolTileCard(
              icon: Icons.security_rounded,
              accentColor: const Color(0xFF22C55E),
              title: AppLocale.tr('backup_data') != 'backup_data'
                  ? AppLocale.tr('backup_data')
                  : 'Backup & Data Recovery',
              subtitle:
                  'Cryptographic SHA-256 snapshots, CSV catalog and safe restore.',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BackupPage()),
              ),
            ),
            _ToolTileCard(
              icon: Icons.settings_outlined,
              accentColor: const Color(0xFF94A3B8),
              title: AppLocale.tr('settings') != 'settings'
                  ? AppLocale.tr('settings')
                  : 'Settings & Profile',
              subtitle: 'Store profile, English/Tamil language, database health',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                isDark
                    ? 'assets/images/logo_shield_dark.png'
                    : 'assets/images/logo_shield_light.png',
                width: 20,
                height: 22,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
              const SizedBox(width: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  children: [
                    TextSpan(
                      text: 'Stock',
                      style: TextStyle(
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      ),
                    ),
                    const TextSpan(
                      text: 'Safe',
                      style: TextStyle(
                        color: Color(0xFF0080FF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            AppLocale.tr('more_tools') != 'more_tools'
                ? AppLocale.tr('more_tools')
                : 'More Operations & Tools',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Powerful tools to manage, reorder, and grow your inventory.',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header with Icon & Subtitle
// ─────────────────────────────────────────────────────────────────────────────

class _MoreSectionHeader extends StatelessWidget {
  const _MoreSectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = iconColor ?? const Color(0xFF3B82F6);

    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 10),
            child: Icon(icon, size: 20, color: color),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pro Upgrade Banner Card
// ─────────────────────────────────────────────────────────────────────────────

class _ProBannerCard extends StatelessWidget {
  const _ProBannerCard({
    required this.isPro,
    required this.activeProducts,
    required this.effectiveCapacity,
    required this.remainingSlots,
    this.bonusSlots = 0,
    this.onTap,
  });

  final bool isPro;
  final int activeProducts;
  final int effectiveCapacity;
  final int remainingSlots;
  final int bonusSlots;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gold = Color(0xFFF59E0B);
    final radius = BorderRadius.circular(16);

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF2C1D06).withValues(alpha: 0.95),
                      const Color(0xFF191206).withValues(alpha: 0.95),
                    ]
                  : [
                      const Color(0xFFFEF3C7),
                      const Color(0xFFFDE68A),
                    ],
            ),
            borderRadius: radius,
            border: Border.all(
              color: gold.withValues(alpha: isDark ? 0.65 : 0.8),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: gold.withValues(alpha: isDark ? 0.22 : 0.12),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: gold.withValues(alpha: isDark ? 0.22 : 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: gold.withValues(alpha: isDark ? 0.50 : 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(
                      isPro ? Icons.workspace_premium_rounded : Icons.emoji_events_rounded,
                      size: 26,
                      color: gold,
                    ),
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
                            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isPro
                              ? '$activeProducts products tracked · Unlimited capacity'
                              : (bonusSlots > 0
                                  ? '$activeProducts of $effectiveCapacity products used ($bonusSlots bonus) · $remainingSlots pending'
                                  : '$activeProducts of $effectiveCapacity products used · $remainingSlots pending'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!isPro) ...[
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: gold,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: gold.withValues(alpha: 0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '👑 Pro',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E1500),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: gold.withValues(alpha: isDark ? 0.20 : 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: gold,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.5)),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF22C55E),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (!isPro) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: effectiveCapacity > 0
                        ? (activeProducts / effectiveCapacity).clamp(0.0, 1.0)
                        : 0.0,
                    backgroundColor: isDark
                        ? const Color(0xFF334155).withValues(alpha: 0.5)
                        : Colors.amber.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      activeProducts >= effectiveCapacity
                          ? const Color(0xFFEF4444)
                          : (activeProducts >= effectiveCapacity * 0.8
                              ? const Color(0xFFF59E0B)
                              : gold),
                    ),
                    minHeight: 5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2-Column Operations Card (Low Stock & Suppliers)
// ─────────────────────────────────────────────────────────────────────────────

class _OperationsCard extends StatelessWidget {
  const _OperationsCard({
    required this.accentColor,
    required this.icon,
    required this.title,
    required this.description,
    required this.visual,
    required this.onTap,
  });

  final Color accentColor;
  final IconData icon;
  final String title;
  final String description;
  final Widget visual;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF151E2E) : palette.cardSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155).withValues(alpha: 0.6) : palette.border,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon container
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: accentColor.withValues(alpha: isDark ? 0.35 : 0.25),
                    width: 0.8,
                  ),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFF8FAFC) : palette.textPrimary,
                ),
              ),
              const SizedBox(height: 4),

              // Description
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.25,
                  color: isDark ? const Color(0xFF94A3B8) : palette.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              const Spacer(),

              // Bottom right graphic
              Align(
                alignment: Alignment.bottomRight,
                child: visual,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card Visuals (Cardboard boxes & PO clipboard)
// ─────────────────────────────────────────────────────────────────────────────

class _LowStockVisual extends StatelessWidget {
  const _LowStockVisual();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Box 1 (Bottom Left)
          Positioned(
            left: 2,
            bottom: 2,
            child: _CardboardBox(width: 24, height: 22),
          ),
          // Box 2 (Bottom Right)
          Positioned(
            left: 22,
            bottom: 2,
            child: _CardboardBox(width: 26, height: 24),
          ),
          // Box 3 (Top Center)
          Positioned(
            left: 12,
            bottom: 16,
            child: _CardboardBox(width: 22, height: 20),
          ),
          // Alert Badge (Red circle with !)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF151E2E), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.6),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '!',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardboardBox extends StatelessWidget {
  const _CardboardBox({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF59E0B),
            Color(0xFFD97706),
            Color(0xFFB45309),
          ],
        ),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFFFBBF24).withValues(alpha: 0.5),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: width * 0.35,
          height: height,
          color: const Color(0xFF92400E).withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _SuppliersVisual extends StatelessWidget {
  const _SuppliersVisual();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Clipboard base (Blue)
          Positioned(
            left: 4,
            top: 2,
            child: Container(
              width: 36,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Top clip
                  Container(
                    width: 14,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Paper Sheet
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(3, 0, 3, 3),
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PO',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2563EB),
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(width: 20, height: 1.2, color: const Color(0xFF94A3B8)),
                          const SizedBox(height: 2),
                          Container(width: 16, height: 1.2, color: const Color(0xFFCBD5E1)),
                          const SizedBox(height: 2),
                          Container(width: 18, height: 1.2, color: const Color(0xFFCBD5E1)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Green WhatsApp badge at bottom right
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF151E2E), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.6),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(
                Icons.chat_bubble_rounded,
                color: Colors.white,
                size: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Barcode Sticker Printing Card
// ─────────────────────────────────────────────────────────────────────────────

class _BarcodePrintingCard extends StatelessWidget {
  const _BarcodePrintingCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF151E2E) : palette.cardSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155).withValues(alpha: 0.6) : palette.border,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF22C55E).withValues(alpha: isDark ? 0.35 : 0.25),
                    width: 0.8,
                  ),
                ),
                child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF22C55E), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocale.tr('barcode_label_printing') != 'barcode_label_printing'
                          ? AppLocale.tr('barcode_label_printing')
                          : 'Barcode Sticker Printing',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFF8FAFC) : palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Generate sticker sheets (A4 or thermal rolls) with Code 128 / QR.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.25,
                        color: isDark ? const Color(0xFF94A3B8) : palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _BarcodeStickerVisual(),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarcodeStickerVisual extends StatelessWidget {
  const _BarcodeStickerVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barcode stripes
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final w in [1.5, 3.0, 1.0, 2.5, 1.0, 3.5, 1.5, 2.0, 1.0]) ...[
                    Container(width: w, height: 20, color: Colors.black87),
                    const SizedBox(width: 1.5),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'CODE 128',
                style: TextStyle(
                  fontSize: 6,
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
          Container(width: 0.8, height: 22, color: Colors.black12),
          const SizedBox(width: 6),
          // Miniature QR Code icon
          const Icon(
            Icons.qr_code_rounded,
            size: 22,
            color: Colors.black87,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dedicated Ask StockSafe AI Feature Card
// ─────────────────────────────────────────────────────────────────────────────

class _AskStockSafeAiCard extends StatelessWidget {
  const _AskStockSafeAiCard({
    required this.onTap,
    required this.onSelectQuestion,
  });

  final VoidCallback onTap;
  final ValueChanged<String> onSelectQuestion;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF2C1948).withValues(alpha: 0.85),
                      const Color(0xFF151E2E),
                    ]
                  : [
                      const Color(0xFFF5F3FF),
                      Colors.white,
                    ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.65 : 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.20 : 0.10),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.25 : 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.5 : 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Color(0xFFA78BFA), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocale.tr('ask_ai') != 'ask_ai'
                              ? AppLocale.tr('ask_ai')
                              : 'Ask StockSafe AI',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFF8FAFC) : palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Ask questions about your stock, inventory value, reorder plans, and more — works offline.',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.25,
                            color: isDark ? const Color(0xFF94A3B8) : palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const _AiRobotVisual(),
                ],
              ),
              const SizedBox(height: 12),

              // 3 Example Question Pills (Master Prompt Section 7)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _AiQuestionChip(
                    question: 'Which products are running low?',
                    onTap: () => onSelectQuestion('Which products are running low?'),
                  ),
                  _AiQuestionChip(
                    question: 'What is my total inventory valuation?',
                    onTap: () => onSelectQuestion('What is my total inventory purchase value?'),
                  ),
                  _AiQuestionChip(
                    question: 'Which products need restocking?',
                    onTap: () => onSelectQuestion('Which products are running low?'),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // CTA Row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Ask StockSafe AI →',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiRobotVisual extends StatelessWidget {
  const _AiRobotVisual();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 46,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Robot Head
          Positioned(
            left: 2,
            bottom: 0,
            child: Container(
              width: 38,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFEDE9FE),
                    Color(0xFFDDD6FE),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC4B5FD), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                // Dark visor face
                child: Container(
                  width: 28,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1B4B),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF38BDF8),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF38BDF8),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Floating analytics chart badge
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFC084FC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF151E2E), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(width: 2.2, height: 6, color: Colors.white70),
                  const SizedBox(width: 1.2),
                  Container(width: 2.2, height: 10, color: Colors.white),
                  const SizedBox(width: 1.2),
                  Container(width: 2.2, height: 14, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiQuestionChip extends StatelessWidget {
  const _AiQuestionChip({required this.question, required this.onTap});

  final String question;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark
          ? const Color(0xFF8B5CF6).withValues(alpha: 0.14)
          : const Color(0xFFEDE9FE),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.35 : 0.25),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.help_outline_rounded, size: 12, color: Color(0xFFA78BFA)),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  question,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF4C1D95),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Standard Tool Tile Card (Help, Data & System)
// ─────────────────────────────────────────────────────────────────────────────

class _ToolTileCard extends StatelessWidget {
  const _ToolTileCard({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isDark ? const Color(0xFF151E2E) : palette.cardSurface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF334155).withValues(alpha: 0.6) : palette.border,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: isDark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accentColor.withValues(alpha: isDark ? 0.35 : 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF8FAFC) : palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.25,
                          color: isDark ? const Color(0xFF94A3B8) : palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark ? const Color(0xFF94A3B8) : palette.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
