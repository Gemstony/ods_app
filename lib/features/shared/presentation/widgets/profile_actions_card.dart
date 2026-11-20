import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../screens/change_password_screen.dart';
import '../screens/edit_profile_screen.dart';

/// Card with the two self-service account actions every role's Profile
/// tab exposes: "Edit profile" and "Change password".
///
/// Both push full-screen forms under `features/shared` — the endpoints
/// (`PUT /auth/profile`, `PUT /auth/password`) are role-agnostic.
class ProfileActionsCard extends ConsumerWidget {
  const ProfileActionsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ActionTile(
            icon: Icons.edit_outlined,
            title: 'Edit profile',
            subtitle: 'Update your name and phone number',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EditProfileScreen(user: user),
              ),
            ),
          ),
          const Divider(height: AppSpacing.lg),
          _ActionTile(
            icon: Icons.lock_outline_rounded,
            title: 'Change password',
            subtitle: 'Update your sign-in password',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ChangePasswordScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: text.bodySmall?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.onSurfaceSubtle,
            ),
          ],
        ),
      ),
    );
  }
}
