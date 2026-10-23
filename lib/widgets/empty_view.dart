import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// Full-tab empty state — no data yet, no error, just nothing to show.
///
/// Distinct from [ErrorView] (something failed) and [LoadingView] (waiting).
/// Use for "no deliveries yet", "no rewards yet", "no staff".
class EmptyView extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;

  /// Optional call-to-action (e.g., "Create delivery" button).
  final Widget? action;

  const EmptyView({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.action,
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
              backgroundColor: AppColors.surface,
              child: Icon(
                icon ?? Icons.inbox_outlined,
                size: 44,
                color: AppColors.primaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.titleMedium,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}