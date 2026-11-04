import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/auth/auth_user.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../widgets/widgets.dart';

/// The Distributor's Profile tab.
///
/// Read-only view of the signed-in distributor's own account:
///   - Header: avatar initials + name + "Distributor" badge + status chip
///   - Contact: email, phone
///   - Account: Distributor ID, member since, branch (if any),
///     email-verified state
///   - Footer: app name + version
///
/// Logout lives in the AppBar (via [RoleDashboardScaffold]'s LogoutMenu).
/// Editing profile / changing password require backend endpoints that
/// don't exist yet — intentionally not surfaced here.
class DistributorProfileTab extends ConsumerWidget {
  const DistributorProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Not signed in.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenH),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _HeaderCard(user: user),
          const SizedBox(height: AppSpacing.lg),
          _ContactCard(user: user),
          const SizedBox(height: AppSpacing.lg),
          _AccountDetailsCard(user: user),
          const SizedBox(height: AppSpacing.xl),
          const _VersionFooter(),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Header card — avatar + name + role badge + status
// ─────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final AuthUser user;
  const _HeaderCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary,
            child: Text(
              _initials(user.name),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  children: [
                    _RoleBadge(label: _roleLabel(user.role)),
                    const SizedBox(width: AppSpacing.xs),
                    StatusChip(
                      label: _statusLabel(user.status),
                      type: _statusType(user.status),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }
    final first = parts.first[0];
    final last = parts.last[0];
    return '$first$last'.toUpperCase();
  }

  static String _roleLabel(String role) {
    if (role.isEmpty) return 'User';
    return role[0].toUpperCase() + role.substring(1);
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'pending':
        return 'Pending approval';
      case 'suspended':
        return 'Suspended';
      case 'deactivated':
        return 'Deactivated';
      default:
        return status.isEmpty ? 'Unknown' : status;
    }
  }

  static StatusType _statusType(String status) {
    return status == 'active' ? StatusType.success : StatusType.warning;
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  const _RoleBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Contact card
// ─────────────────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  final AuthUser user;
  const _ContactCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(children: [
      const _SectionTitle(
        icon: Icons.contact_mail_outlined,
        title: 'Contact',
      ),
      const SizedBox(height: AppSpacing.sm),
      _kv(context, 'Email', user.email, trailing: _verifiedOrPending(user)),
      _kv(context, 'Phone', user.phone),
    ]);
  }

  Widget? _verifiedOrPending(AuthUser user) {
    if (user.emailVerifiedAt != null) {
      return const Icon(
        Icons.verified_rounded,
        size: 16,
        color: AppColors.success,
      );
    }
    return const Icon(
      Icons.info_outline_rounded,
      size: 16,
      color: AppColors.warning,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Account details card
// ─────────────────────────────────────────────────────────────

class _AccountDetailsCard extends StatelessWidget {
  final AuthUser user;
  const _AccountDetailsCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final distributorId = user.distributorId;
    final branch = user.branch;
    final createdAt = user.createdAt;

    return _SurfaceCard(children: [
      const _SectionTitle(
        icon: Icons.badge_outlined,
        title: 'Account',
      ),
      const SizedBox(height: AppSpacing.sm),
      _kv(
        context,
        'Distributor ID',
        (distributorId == null || distributorId.isEmpty)
            ? 'Not assigned yet'
            : distributorId,
      ),
      _kv(
        context,
        'Member since',
        createdAt == null ? '—' : _formatDate(createdAt),
      ),
      _kv(
        context,
        'Branch',
        branch == null
            ? 'No branch assigned'
            : '${branch.name} · ${branch.code}',
      ),
    ]);
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────
// Version footer
// ─────────────────────────────────────────────────────────────

class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(
          '${AppConfig.appName} · ${AppConfig.appTagline}',
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(
            color: AppColors.onSurfaceSubtle,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Version ${AppConfig.appVersion}',
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(
            color: AppColors.onSurfaceSubtle,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared widgets (mirrors ManagerProfileTab)
// ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        Text(
          title,
          style: text.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final List<Widget> children;
  const _SurfaceCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

Widget _kv(
  BuildContext context,
  String label,
  String value, {
  Widget? trailing,
}) {
  final text = Theme.of(context).textTheme;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: text.bodyMedium?.copyWith(
              color: AppColors.onSurfaceMuted,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  value,
                  style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.xxs),
                trailing,
              ],
            ],
          ),
        ),
      ],
    ),
  );
}