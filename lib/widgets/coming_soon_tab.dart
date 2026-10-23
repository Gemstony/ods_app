import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// Standard placeholder used inside every role dashboard tab until the tab's
/// real content arrives in its dedicated phase.
///
/// Consistency across all 20 placeholder tabs is the point — same icon size,
/// same title hierarchy, same muted subtitle. When a tab goes live, replace
/// this widget in that one place; every other tab stays unchanged.
class ComingSoonTab extends StatelessWidget {
  final String title;
  final String phase;
  final IconData icon;

  const ComingSoonTab({
    super.key,
    required this.title,
    required this.phase,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.surface,
                child: Icon(icon, size: 44, color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                style: text.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Built in Phase $phase.',
                style: text.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}