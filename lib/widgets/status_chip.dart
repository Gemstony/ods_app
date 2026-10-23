import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// Semantic categories for a status chip. Each maps to a specific
/// background + text color pair below — never hardcode colors in screens.
enum StatusType { neutral, primary, success, warning, error, info }

/// Small pill badge showing a status.
///
/// Used for delivery statuses ("Active", "Delivered"), payment states
/// ("Pending", "Paid"), and regional dispatch states ("Dispatched").
class StatusChip extends StatelessWidget {
  final String label;
  final StatusType type;

  /// Optional leading icon (e.g., a check for delivered).
  final IconData? icon;

  /// Compact mode reduces vertical padding — for use inside table cells.
  final bool isCompact;

  const StatusChip({
    super.key,
    required this.label,
    this.type = StatusType.neutral,
    this.icon,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(type);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? AppSpacing.xs : AppSpacing.sm,
        vertical: isCompact ? 2 : AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: isCompact ? 12 : 14, color: palette.foreground),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Text(
            label,
            style: TextStyle(
              color: palette.foreground,
              fontSize: isCompact ? 11 : 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  _ChipPalette _paletteFor(StatusType type) => switch (type) {
        StatusType.neutral => const _ChipPalette(
            background: AppColors.disabledSurface,
            foreground: AppColors.onSurfaceMuted,
          ),
        StatusType.primary => const _ChipPalette(
            background: AppColors.primary,
            foreground: Colors.white,
          ),
        StatusType.success => const _ChipPalette(
            background: AppColors.successSurface,
            foreground: Color(0xFF14532D),
          ),
        StatusType.warning => const _ChipPalette(
            background: AppColors.warningSurface,
            foreground: Color(0xFF78350F),
          ),
        StatusType.error => const _ChipPalette(
            background: AppColors.errorSurface,
            foreground: Color(0xFF7F1D1D),
          ),
        StatusType.info => const _ChipPalette(
            background: AppColors.infoSurface,
            foreground: Color(0xFF075985),
          ),
      };
}

class _ChipPalette {
  final Color background;
  final Color foreground;
  const _ChipPalette({required this.background, required this.foreground});
}