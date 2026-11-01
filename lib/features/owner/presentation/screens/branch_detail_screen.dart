import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ods_app/data/models/branch_input.dart';
import 'package:ods_app/features/owner/presentation/providers/owner_branch_providers.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/branch.dart';
import '../../../../data/models/branch_manager_assignment.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../widgets/widgets.dart';
import '../widgets/assign_manager_sheet.dart';
import 'branch_form_screen.dart';

class BranchDetailScreen extends ConsumerWidget {
  final int branchId;
  const BranchDetailScreen({super.key, required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchAsync = ref.watch(ownerBranchProvider(branchId));

    return Scaffold(
      appBar: AppBar(
        title: branchAsync.maybeWhen(
          data: (b) => Text(b.name),
          orElse: () => const Text('Branch'),
        ),
        actions: [
          if (branchAsync.hasValue)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _openEdit(context, branchAsync.value!),
            ),
        ],
      ),
      body: branchAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => ErrorView(
          message: 'Could not load branch.',
          onRetry: () => ref.invalidate(ownerBranchProvider(branchId)),
        ),
        data: (branch) => _BranchDetailContent(branch: branch),
      ),
    );
  }

  void _openEdit(BuildContext context, Branch branch) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BranchFormScreen(initialBranch: branch),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────
// Content
// ─────────────────────────────────────────────────────────────────────

class _BranchDetailContent extends ConsumerWidget {
  final Branch branch;
  const _BranchDetailContent({required this.branch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        _InfoCard(branch: branch),
        const SizedBox(height: AppSpacing.lg),
        _ManagerSection(branch: branch),
        const SizedBox(height: AppSpacing.lg),
        _HistorySection(branchId: branch.id),
        const SizedBox(height: AppSpacing.lg),
        _ActionsCard(branch: branch),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

// ─── Info card ───────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final Branch branch;
  const _InfoCard({required this.branch});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      children: [
        _kv(context, 'Code', branch.code),
        _kv(context, 'Address', branch.address),
        _kv(context, 'GPS', branch.coordinates),
        _kv(
          context,
          'Hours',
          branch.operatingHours == null ? 'Not set' : 'Set',
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                'Status',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
              ),
            ),
            StatusChip(
              label: branch.isActive ? 'Active' : 'Inactive',
              type: branch.isActive
                  ? StatusType.success
                  : StatusType.neutral,
              isCompact: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _kv(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Manager section ─────────────────────────────────────

class _ManagerSection extends ConsumerWidget {
  final Branch branch;
  const _ManagerSection({required this.branch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync =
        ref.watch(ownerBranchManagerHistoryProvider(branch.id));
    final current = historyAsync.maybeWhen(
      data: (h) =>
          h.where((a) => a.isActive).cast<BranchManagerAssignment?>().firstOrNull,
      orElse: () => null,
    );

    return _SurfaceCard(
      children: [
        Row(
          children: [
            const Icon(Icons.person_pin_circle,
                color: AppColors.primary, size: 18),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Branch manager',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (current == null)
          Row(
            children: [
              Expanded(
                child: Text(
                  'No manager assigned',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                ),
              ),
              AppButton(
                label: 'Assign',
                onPressed: () => showAssignManagerSheet(
                  context,
                  branchId: branch.id,
                  currentManagerUserId: null,
                ),
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                isFullWidth: false,
              ),
            ],
          )
        else
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.surface,
                child: Text(
                  current.userName.isNotEmpty
                      ? current.userName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current.userName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      current.userEmail,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceMuted,
                          ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => showAssignManagerSheet(
                  context,
                  branchId: branch.id,
                  currentManagerUserId: current.userId,
                ),
                child: const Text('Change'),
              ),
            ],
          ),
      ],
    );
  }
}

// ─── History section ─────────────────────────────────────

class _HistorySection extends ConsumerWidget {
  final int branchId;
  const _HistorySection({required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync =
        ref.watch(ownerBranchManagerHistoryProvider(branchId));

    return historyAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (history) {
        if (history.length <= 1) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                'Assignment history',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            _SurfaceCard(
              children: history
                  .map((a) => _HistoryRow(assignment: a))
                  .toList(growable: false),
            ),
          ],
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final BranchManagerAssignment assignment;
  const _HistoryRow({required this.assignment});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final started = _fmt(assignment.assignedAt);
    final ended = assignment.unassignedAt == null
        ? 'Present'
        : _fmt(assignment.unassignedAt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            assignment.isActive
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            size: 16,
            color: assignment.isActive
                ? AppColors.success
                : AppColors.onSurfaceSubtle,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assignment.userName,
                  style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$started – $ended',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime? d) {
    if (d == null) return '—';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ─── Actions card ────────────────────────────────────────

class _ActionsCard extends ConsumerWidget {
  final Branch branch;
  const _ActionsCard({required this.branch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SurfaceCard(
      children: [
        AppButton(
          label: branch.isActive ? 'Deactivate branch' : 'Reactivate branch',
          onPressed: () => _toggleStatus(context, ref),
          variant: AppButtonVariant.secondary,
          icon: branch.isActive
              ? Icons.pause_circle_outline
              : Icons.play_circle_outline,
        ),
      ],
    );
  }

  Future<void> _toggleStatus(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          branch.isActive ? 'Deactivate branch?' : 'Reactivate branch?',
        ),
        content: Text(
          branch.isActive
              ? 'Deactivated branches stop appearing in pickup selection. '
                  'Existing deliveries are unaffected. You can reactivate at any time.'
              : 'Reactivated branches appear in pickup selection again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(branch.isActive ? 'Deactivate' : 'Reactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final repo = ref.read(branchRepositoryProvider);
    final newStatus =
        branch.isActive ? BranchStatus.inactive : BranchStatus.active;
    final result = await repo.update(
      branch.id,
      BranchInputFromBranch(branch).copyWithStatus(newStatus),
    );

    if (!context.mounted) return;

    result.fold(
      onSuccess: (_) {
        ref.invalidate(ownerBranchesProvider);
        ref.invalidate(ownerBranchProvider(branch.id));
      },
      onFailure: (failure) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(failure.message),
            backgroundColor: AppColors.error,
          ));
      },
    );
  }
}

// Helper to build an input from an existing branch and swap the status.
class BranchInputFromBranch {
  final Branch _b;
  BranchInputFromBranch(this._b);

  BranchInput copyWithStatus(BranchStatus status) => BranchInput(
        name: _b.name,
        code: _b.code,
        address: _b.address,
        latitude: _b.latitude,
        longitude: _b.longitude,
        operatingHours: _b.operatingHours,
        status: status,
      );
}

// ─── Shared surface ─────────────────────────────────────

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