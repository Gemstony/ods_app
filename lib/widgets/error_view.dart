import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import 'app_button.dart';

/// Full-tab error state.
///
/// Screens pass `failure.message` here (never the exception itself). The
/// retry button shows only when [onRetry] is provided — network failures
/// are retryable, auth failures are not.
class ErrorView extends StatelessWidget {
  /// Message safe to display. Typically `failure.message`.
  final String message;

  /// Optional headline above the message.
  final String? title;

  /// If non-null, renders a "Try again" button.
  final VoidCallback? onRetry;

  /// Override the default retry button label.
  final String retryLabel;

  /// Override the default error icon.
  final IconData? icon;

  const ErrorView({
    super.key,
    required this.message,
    this.title,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.errorSurface,
              child: Icon(
                icon ?? Icons.error_outline_rounded,
                size: 44,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (title != null) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: text.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: 180,
                child: AppButton(
                  label: retryLabel,
                  onPressed: onRetry,
                  variant: AppButtonVariant.secondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}