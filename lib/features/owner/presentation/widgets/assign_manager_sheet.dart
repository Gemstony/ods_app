import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ods_app/features/owner/presentation/screens/owner_branch_providers.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/auth/auth_user.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../widgets/widgets.dart';


/// Modal sheet: pick a Manager to assign to a branch.
///
/// Excludes the currently-assigned manager (caller passes their ID).
/// Returns `true` on successful assignment, `null` on dismiss.
Future<bool?> showAssignManagerSheet(
  BuildContext context, {
  required int branchId,
  required int? currentManagerUserId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusXl),
      ),
    ),
    builder: (_) => _AssignManagerSheet(
      branchId: branchId,
      currentManagerUserId: currentManagerUserId,
    ),
  );
}

class _AssignManagerSheet extends ConsumerStatefulWidget {
  final int branchId;
  final int? currentManagerUserId;

  const _AssignManagerSheet({
    required this.branchId,
    this.currentManagerUserId,
  });

  @override
  ConsumerState<_AssignManagerSheet> createState() =>
      _AssignManagerSheetState();
}

class _AssignManagerSheetState extends ConsumerState<_AssignManagerSheet> {
  bool _submitting = false;
  int? _selectedUserId;

  Future<void> _confirm() async {
    if (_selectedUserId == null) return;
    setState(() => _submitting = true);

    final repo = ref.read(branchRepositoryProvider);
    final result = await repo.assignManager(
      branchId: widget.branchId,
      userId: _selectedUserId!,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(
      onSuccess: (_) {
        ref.invalidate(ownerBranchesProvider);
        ref.invalidate(ownerBranchProvider(widget.branchId));
        ref.invalidate(ownerBranchManagerHistoryProvider(widget.branchId));
        Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context) {
    final managersAsync = ref.watch(availableManagersProvider);
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: 40,
              height: 4,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              ),
            ),
            Text(
              'Assign branch manager',
              style: text.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Only active Managers not currently assigned are shown.',
              style: text.bodySmall?.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: managersAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => ErrorView(
                  message: 'Could not load managers.',
                  onRetry: () => ref.invalidate(availableManagersProvider),
                ),
                data: (managers) {
                  final candidates = managers
                      .where((m) => m.id != widget.currentManagerUserId)
                      .toList(growable: false);

                  if (candidates.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: EmptyView(
                        title: 'No available managers',
                        subtitle:
                            'Create a Manager from the Users tab to assign.',
                        icon: Icons.people_outline,
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: candidates.length,
                    itemBuilder: (_, i) => _ManagerTile(
                      manager: candidates[i],
                      selected: _selectedUserId == candidates[i].id,
                      onTap: _submitting
                          ? null
                          : () => setState(
                              () => _selectedUserId = candidates[i].id),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Assign',
              onPressed: _selectedUserId == null ? null : _confirm,
              isLoading: _submitting,
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ),
      ),
    );
  }
}

class _ManagerTile extends StatelessWidget {
  final AuthUser manager;
  final bool selected;
  final VoidCallback? onTap;

  const _ManagerTile({
    required this.manager,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 0,
      ),
      leading: CircleAvatar(
        backgroundColor:
            selected ? AppColors.primary : AppColors.surface,
        child: Icon(
          Icons.person,
          color: selected ? Colors.white : AppColors.primary,
          size: 20,
        ),
      ),
      title: Text(manager.name),
      subtitle: Text(manager.email),
      trailing: selected
          ? const Icon(Icons.check_circle, color: AppColors.primary)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      selected: selected,
      selectedTileColor: AppColors.surface,
      onTap: onTap,
    );
  }
}