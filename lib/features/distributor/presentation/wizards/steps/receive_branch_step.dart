import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../data/models/branch.dart';
import '../../../../../shared/providers/repository_providers.dart';
import '../../../../../widgets/widgets.dart';
import '../widgets/wizard_bottom_bar.dart';

/// Step 1: pick a pickup branch.
class ReceiveBranchStep extends ConsumerStatefulWidget {
  final void Function(Branch) onSelected;
  final VoidCallback onBack;

  const ReceiveBranchStep({
    super.key,
    required this.onSelected,
    required this.onBack,
  });

  @override
  ConsumerState<ReceiveBranchStep> createState() => _ReceiveBranchStepState();
}

class _ReceiveBranchStepState extends ConsumerState<ReceiveBranchStep> {
  List<Branch> _branches = const [];
  Branch? _selected;
  bool _loading = true;
  Failure? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = ref.read(branchRepositoryProvider);
    final result = await repo.listAvailableForPickup();
    if (!mounted) return;
    result.fold(
      onSuccess: (branches) => setState(() {
        _branches = branches;
        _loading = false;
      }),
      onFailure: (failure) => setState(() {
        _error = failure;
        _loading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LoadingView(message: 'Loading branches…');
    }
    if (_error != null) {
      return ErrorView(
        message: _error!.message,
        onRetry: _load,
      );
    }
    if (_branches.isEmpty) {
      return Column(
        children: [
          const Expanded(
            child: EmptyView(
              title: 'No pickup branches available',
              subtitle: 'Contact the platform owner — no active branches '
                  'are currently accepting pickups.',
              icon: Icons.store_mall_directory_outlined,
            ),
          ),
          WizardBottomBar(
            backLabel: 'Cancel',
            onBack: widget.onBack,
            nextLabel: 'Next',
            onNext: null,
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            itemCount: _branches.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) {
              final branch = _branches[i];
              final isSelected = _selected?.id == branch.id;
              return _BranchTile(
                branch: branch,
                selected: isSelected,
                onTap: () => setState(() => _selected = branch),
              );
            },
          ),
        ),
        WizardBottomBar(
          backLabel: 'Cancel',
          onBack: widget.onBack,
          nextLabel: 'Next',
          onNext: _selected == null
              ? null
              : () => widget.onSelected(_selected!),
        ),
      ],
    );
  }
}

class _BranchTile extends StatelessWidget {
  final Branch branch;
  final bool selected;
  final VoidCallback onTap;

  const _BranchTile({
    required this.branch,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.primary : AppColors.onSurfaceSubtle,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      branch.name,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${branch.code} · ${branch.address}',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}