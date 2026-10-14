import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';

/// A section heading, as the design sets them: sentence case and solid,
/// rather than the grey uppercase tracking this app used to use.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.padding});

  final String text;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: context.palette.textPrimary,
        ),
      ),
    );
  }
}

/// A tinted rounded-square holding an icon — the leading element of a
/// [ToolTile], and the same shape the dashboard's quick actions use.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.accent,
    this.size = 40,
  });

  final IconData icon;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.22 : 0.13),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, size: size * 0.52, color: accent),
    );
  }
}

/// A row in a list of tools: badge, title, one line of explanation, chevron.
class ToolTile extends StatelessWidget {
  const ToolTile({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Replaces the chevron, for a tile that toggles or shows a value.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(12);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: palette.cardSurface,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: palette.border),
            ),
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            child: Row(
              children: [
                IconBadge(icon: icon, accent: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.3,
                          color: palette.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                trailing ??
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

/// The empty state a screen shows before anything has been created on it:
/// a soft disc, a headline, a line of explanation, and the one action that
/// resolves it.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.accent,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;

  /// Defaults to the primary colour.
  final Color? accent;

  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = accent ?? palette.primary;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 132,
              height: 132,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tint.withValues(alpha: isDark ? 0.12 : 0.07),
              ),
              child: Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tint.withValues(alpha: isDark ? 0.16 : 0.11),
                ),
                child: Icon(icon, size: 42, color: tint),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: palette.textTertiary,
              ),
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 26),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon ?? Icons.add_rounded, size: 21),
                  label: Text(
                    actionLabel!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
