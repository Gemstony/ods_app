import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ods_app/features/owner/presentation/screens/owner_branch_providers.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/branch.dart';
import '../../../../widgets/widgets.dart';
import 'branch_detail_screen.dart';
import 'branch_form_screen.dart';

class OwnerBranchesTab extends ConsumerWidget {
  const OwnerBranchesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(ownerBranchesProvider);

    return branchesAsync.when(
      loading: () => const LoadingView(message: 'Loading branches…'),
      error: (e, _) => ErrorView(
        message: 'Could not load branches. Please try again.',
        onRetry: () => ref.invalidate(ownerBranchesProvider),
      ),
      data: (branches) {
        if (branches.isEmpty) {
          return _EmptyBranches(
            onCreate: () => _openForm(context),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(ownerBranchesProvider);
            await ref.read(ownerBranchesProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: branches.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => _BranchCard(
              branch: branches[i],
              onTap: () => _openDetail(context, branches[i].id),
            ),
          ),
        );
      },
    );
  }

  void _openForm(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const BranchFormScreen(),
    ));
  }

  void _openDetail(BuildContext context, int id) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BranchDetailScreen(branchId: id),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────

class _EmptyBranches extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyBranches({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return EmptyView(
      title: 'No branches yet',
      subtitle: 'Add your first branch to start receiving deliveries.',
      icon: Icons.store_rounded,
      action: SizedBox(
        width: 200,
        child: AppButton(
          label: 'Add first branch',
          onPressed: onCreate,
          icon: Icons.add,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Branch card
// ─────────────────────────────────────────────────────────────────────

class _BranchCard extends StatelessWidget {
  final Branch branch;
  final VoidCallback onTap;
  const _BranchCard({required this.branch, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      branch.name,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  StatusChip(
                    label: branch.isActive ? 'Active' : 'Inactive',
                    type: branch.isActive
                        ? StatusType.success
                        : StatusType.neutral,
                    isCompact: true,
                  ),
                ],
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
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 14,
                    color: AppColors.onSurfaceMuted,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Expanded(
                    child: Text(
                      branch.address,
                      style: text.bodySmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.onSurfaceSubtle,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}