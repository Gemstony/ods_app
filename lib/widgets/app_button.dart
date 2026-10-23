import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// Visual variants matching the three Material button families.
enum AppButtonVariant { primary, secondary, text }

/// Height / text-size presets.
enum AppButtonSize { small, medium, large }

/// Consistent button used across the entire app.
///
/// Wraps [ElevatedButton], [OutlinedButton], or [TextButton] so that:
///   - the loading state (spinner + disabled) is uniform everywhere
///   - full-width behaviour is one flag, not per-screen SizedBoxes
///   - icon placement is consistent (left of label, 8px gap)
///   - sizes map to the same heights regardless of variant
///
/// Never use raw `ElevatedButton` in feature code. If a screen needs a
/// behaviour these variants don't cover, add it here.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  /// Default is the ODS-branded solid green button.
  final AppButtonVariant variant;

  /// Default medium (52px). Small (40px) for compact rows, large (60px)
  /// for hero CTAs.
  final AppButtonSize size;

  /// Replaces the label with a spinner and disables taps. This is the
  /// single most important feature — every async form uses it.
  final bool isLoading;

  /// True by default. Set false for buttons that shouldn't stretch.
  final bool isFullWidth;

  /// Optional leading icon. Passed through to the Material button so it
  /// participates in theme + accessibility.
  final IconData? icon;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.isFullWidth = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;
    final style = _styleFor(context);
    final child = _buildChild(context);

    final button = switch (variant) {
      AppButtonVariant.primary => ElevatedButton(
          onPressed: effectiveOnPressed,
          style: style,
          child: child,
        ),
      AppButtonVariant.secondary => OutlinedButton(
          onPressed: effectiveOnPressed,
          style: style,
          child: child,
        ),
      AppButtonVariant.text => TextButton(
          onPressed: effectiveOnPressed,
          style: style,
          child: child,
        ),
    };

    return isFullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }

  // ─── Content ─────────────────────────────────────────────────────

  Widget _buildChild(BuildContext context) {
    if (isLoading) {
      final spinnerColor = switch (variant) {
        AppButtonVariant.primary => AppColors.onPrimary,
        AppButtonVariant.secondary => AppColors.primary,
        AppButtonVariant.text => AppColors.primary,
      };
      return SizedBox(
        height: _spinnerSize,
        width: _spinnerSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: spinnerColor,
        ),
      );
    }

    if (icon == null) return Text(label);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: _iconSize),
        const SizedBox(width: AppSpacing.xs),
        Text(label),
      ],
    );
  }

  // ─── Style ───────────────────────────────────────────────────────

  ButtonStyle _styleFor(BuildContext context) {
    final base = switch (variant) {
      AppButtonVariant.primary => ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.disabled,
          disabledForegroundColor: Colors.white70,
        ),
      AppButtonVariant.secondary => OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      AppButtonVariant.text => TextButton.styleFrom(
          foregroundColor: AppColors.primary,
        ),
    };

    return base.copyWith(
      minimumSize: WidgetStatePropertyAll(Size(0, _height)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: _hPadding),
      ),
      textStyle: WidgetStatePropertyAll(
        TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: _fontSize,
          letterSpacing: 0.1,
        ),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
    );
  }

  // ─── Size tokens ─────────────────────────────────────────────────

  double get _height => switch (size) {
        AppButtonSize.small => 40,
        AppButtonSize.medium => 52,
        AppButtonSize.large => 60,
      };

  double get _fontSize => switch (size) {
        AppButtonSize.small => 13,
        AppButtonSize.medium => 14,
        AppButtonSize.large => 16,
      };

  double get _hPadding => switch (size) {
        AppButtonSize.small => AppSpacing.sm,
        AppButtonSize.medium => AppSpacing.lg,
        AppButtonSize.large => AppSpacing.xl,
      };

  double get _iconSize => switch (size) {
        AppButtonSize.small => 16,
        AppButtonSize.medium => 18,
        AppButtonSize.large => 20,
      };

  double get _spinnerSize => switch (size) {
        AppButtonSize.small => 16,
        AppButtonSize.medium => 20,
        AppButtonSize.large => 24,
      };
}
