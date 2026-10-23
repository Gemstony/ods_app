import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/routing/route_names.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// Placeholder scaffold shown by every role dashboard until its real UI is
/// built in the respective phase.
///
/// Provides a consistent structure (AppBar, icon, title, description) and a
/// temporary "Back to login" action so routing can be exercised repeatedly
/// during development. Real dashboards replace this widget's *usage* in 1.6+.
class PlaceholderDashboard extends StatelessWidget {
  final String title;
  final String roleLabel;
  final IconData icon;
  final String phaseHint;

  const PlaceholderDashboard({
    super.key,
    required this.title,
    required this.roleLabel,
    required this.icon,
    required this.phaseHint,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Back to login',
            icon: const Icon(Icons.logout),
            onPressed: () => context.go(RouteNames.login),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.surface,
                  child: Icon(icon, color: AppColors.primary, size: 48),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '$roleLabel panel',
                  style: text.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  phaseHint,
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}