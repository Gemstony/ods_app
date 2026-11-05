import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/auth/auth_user.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../widgets/widgets.dart';

/// The Rider's Profile tab.
///
/// Read-only view of the signed-in rider's own account:
///   - Header:    avatar initials + name + "Delivery Agent" + status
///   - Contact:   email + phone (with verified indicator)
///   - Personal:  NIDA / sex / DOB (hidden entirely if all null)
///   - Vehicle:   type / color / ownership / plate (hidden if all null)
///   - Account:   member since + branch
///   - Footer:    app name + version
///
/// Logout lives in the AppBar (via RoleDashboardScaffold's LogoutMenu).
/// Editing rider details requires a `PUT /rider/profile` endpoint that
/// doesn't exist yet — intentionally not surfaced here.
class RiderProfileTab extends ConsumerWidget {
  const RiderProfileTab({super.key});

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
          if (_hasPersonalInfo(user)) ...[
            const SizedBox(height: AppSpacing.lg),
            _PersonalCard(user: user),
          ],
          if (_hasVehicleInfo(user)) ...[
            const SizedBox(height: AppSpacing.lg),
            _VehicleCard(user: user),
          ],
          const SizedBox(height: AppSpacing.lg),
          _AccountCard(user: user),
          const SizedBox(height: AppSpacing.xl),
          const _VersionFooter(),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  static bool _hasPersonalInfo(AuthUser u) =>
      u.nida != null || u.sex != null || u.dateOfBirth != null;

  static bool _hasVehicleInfo(AuthUser u) =>
      u.vehicleType != null ||
      u.vehicleColor != null ||
      u.vehicleOwnership != null ||
      u.plateNumber != null;
}

// ─────────────────────────────────────────────────────────────
// Header card
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
                    const _RoleBadge(label: 'Delivery Agent'),
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
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
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

  static StatusType _statusType(String status) =>
      status == 'active' ? StatusType.success : StatusType.warning;
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
      _kv(
        context,
        'Email',
        user.email,
        trailing: user.emailVerifiedAt != null
            ? const Icon(
                Icons.verified_rounded,
                size: 16,
                color: AppColors.success,
              )
            : const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: AppColors.warning,
              ),
      ),
      _kv(context, 'Phone', user.phone),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// Personal details card
// ─────────────────────────────────────────────────────────────

class _PersonalCard extends StatelessWidget {
  final AuthUser user;
  const _PersonalCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(children: [
      const _SectionTitle(
        icon: Icons.badge_outlined,
        title: 'Personal details',
      ),
      const SizedBox(height: AppSpacing.sm),
      if (user.nida != null) _kv(context, 'NIDA', user.nida!),
      if (user.sex != null) _kv(context, 'Sex', _sexLabel(user.sex!)),
      if (user.dateOfBirth != null)
        _kv(context, 'Date of birth', _formatDate(user.dateOfBirth!)),
    ]);
  }

  static String _sexLabel(String v) => switch (v) {
        'male' => 'Male',
        'female' => 'Female',
        'other' => 'Other',
        _ => v,
      };
}

// ─────────────────────────────────────────────────────────────
// Vehicle card
// ─────────────────────────────────────────────────────────────

class _VehicleCard extends StatelessWidget {
  final AuthUser user;
  const _VehicleCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(children: [
      const _SectionTitle(
        icon: Icons.two_wheeler_rounded,
        title: 'Vehicle',
      ),
      const SizedBox(height: AppSpacing.sm),
      if (user.vehicleType != null)
        _kv(context, 'Type', user.vehicleType!),
      if (user.vehicleColor != null)
        _kv(context, 'Color', user.vehicleColor!),
      if (user.vehicleOwnership != null)
        _kv(context, 'Ownership', _ownershipLabel(user.vehicleOwnership!)),
      if (user.plateNumber != null)
        _kv(context, 'Plate number', user.plateNumber!),
    ]);
  }

  static String _ownershipLabel(String v) => switch (v) {
        'owned' => 'Owned',
        'rented' => 'Rented',
        'company' => 'Company',
        _ => v,
      };
}

// ─────────────────────────────────────────────────────────────
// Account card
// ─────────────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  final AuthUser user;
  const _AccountCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final branch = user.branch;
    return _SurfaceCard(children: [
      const _SectionTitle(
        icon: Icons.account_circle_outlined,
        title: 'Account',
      ),
      const SizedBox(height: AppSpacing.sm),
      _kv(
        context,
        'Member since',
        user.createdAt == null ? '—' : _formatDate(user.createdAt!),
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
// Shared widgets (mirrors DistributorProfileTab)
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

// ─────────────────────────────────────────────────────────────
// Formatting
// ─────────────────────────────────────────────────────────────

String _formatDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}