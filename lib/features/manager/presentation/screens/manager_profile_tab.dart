import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/branch.dart';
import '../../../../shared/providers/auth_provider.dart';
import '../../../../widgets/widgets.dart';
import '../providers/manager_branch_providers.dart';
import 'manager_branch_form_screen.dart';

/// The Manager's Profile tab.
///
/// Shows the branch, the current manager, and the signed-in manager's
/// own contact info. Edit button opens `ManagerBranchFormScreen` — the
/// Manager-specific form that allows name/address/GPS updates (not code
/// or status).
class ManagerProfileTab extends ConsumerWidget {
  const ManagerProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchAsync = ref.watch(managerBranchProvider);

    return branchAsync.when(
      loading: () => const LoadingView(message: 'Loading your branch…'),
      error: (_, __) => ErrorView(
        message: 'Could not load your branch.',
        onRetry: () => ref.invalidate(managerBranchProvider),
      ),
      data: (branch) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(managerBranchProvider);
          await ref.read(managerBranchProvider.future);
        },
        child: _Content(branch: branch),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  final Branch branch;
  const _Content({required this.branch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _BranchHeaderCard(branch: branch),
        if (!branch.isActive) ...[
          const SizedBox(height: AppSpacing.sm),
          const _InactiveBanner(),
        ],
        const SizedBox(height: AppSpacing.lg),
        _BranchInfoCard(branch: branch),
        if (user != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _ManagerCard(
            name: user.name,
            email: user.email,
            phone: user.phone,
            assignedAt: branch.currentManager?.assignedAt,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _EditButton(branch: branch),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Header card
// ─────────────────────────────────────────────────────────────

class _BranchHeaderCard extends StatelessWidget {
  final Branch branch;
  const _BranchHeaderCard({required this.branch});

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
          const CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary,
            child: const Icon(
              Icons.store_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  branch.name,
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  branch.code,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.onSurfaceMuted,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          StatusChip(
            label: branch.isActive ? 'Active' : 'Inactive',
            type: branch.isActive ? StatusType.success : StatusType.warning,
          ),
        ],
      ),
    );
  }
}

class _InactiveBanner extends StatelessWidget {
  const _InactiveBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'This branch is currently inactive. Contact the Owner to reactivate.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Branch info card
// ─────────────────────────────────────────────────────────────

class _BranchInfoCard extends StatelessWidget {
  final Branch branch;
  const _BranchInfoCard({required this.branch});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(children: [
      const _SectionTitle(
        icon: Icons.info_outline_rounded,
        title: 'Branch details',
      ),
      const SizedBox(height: AppSpacing.sm),
      _kv(context, 'Address', branch.address),
      _kv(context, 'GPS', branch.coordinates),
      _kv(
        context,
        'Hours',
        _formatHours(branch.operatingHours),
      ),
      _kv(
        context,
        'Manager',
        branch.currentManager?.name ?? 'Not assigned',
      ),
    ]);
  }

  static String _formatHours(Map<String, dynamic>? hours) {
    if (hours == null || hours.isEmpty) return 'Not set';
    final activeDays = hours.entries
        .where((e) => e.value != null)
        .length;
    if (activeDays == 0) return 'Not set';
    return '$activeDays day${activeDays == 1 ? '' : 's'} configured';
  }

  Widget _kv(BuildContext context, String label, String value) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Manager (self) card
// ─────────────────────────────────────────────────────────────

class _ManagerCard extends StatelessWidget {
  final String name;
  final String email;
  final String phone;
  final DateTime? assignedAt;

  const _ManagerCard({
    required this.name,
    required this.email,
    required this.phone,
    this.assignedAt,
  });

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(children: [
      const _SectionTitle(
        icon: Icons.person_outline_rounded,
        title: 'Your profile',
      ),
      const SizedBox(height: AppSpacing.sm),
      _kv(context, 'Name', name),
      _kv(context, 'Email', email),
      _kv(context, 'Phone', phone),
      if (assignedAt != null)
        _kv(context, 'Assigned', _formatDate(assignedAt!)),
    ]);
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Widget _kv(BuildContext context, String label, String value) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Edit button
// ─────────────────────────────────────────────────────────────

class _EditButton extends ConsumerWidget {
  final Branch branch;
  const _EditButton({required this.branch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppButton(
      label: 'Edit branch details',
      icon: Icons.edit_outlined,
      onPressed: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ManagerBranchFormScreen(initialBranch: branch),
        ));
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared widgets
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