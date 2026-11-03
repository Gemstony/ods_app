import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/delivery.dart';
import '../../../../widgets/widgets.dart';
import '../../../shared/presentation/screens/delivery_detail_screen.dart';
import '../providers/manager_delivery_providers.dart';
import '../providers/manager_packages_providers.dart';

/// Manager's physical inventory view.
///
/// Shows deliveries sitting at the branch waiting for a Rider, ordered
/// oldest-first, with per-package aging. Filters by age bucket so
/// managers can focus on what's been sitting too long.
class ManagerPackagesTab extends ConsumerWidget {
  const ManagerPackagesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packagesAsync = ref.watch(managerPackagesProvider);
    final filter = ref.watch(packageAgeFilterProvider);

    return Column(
      children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.md,
            AppSpacing.screenH,
            AppSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary from unfiltered data — fetched independently of
              // the filter so counts are always accurate.
              packagesAsync.maybeWhen(
                data: (_) => _SummaryBanner(
                  packages: ref
                      .watch(managerPackagesProvider)
                      .valueOrNull ??
                      const [],
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.sm),
              _AgeFilterChips(current: filter),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: packagesAsync.when(
            loading: () =>
                const LoadingView(message: 'Loading packages…'),
            error: (_, __) => ErrorView(
              message: 'Could not load packages at branch.',
              onRetry: () =>
                  ref.invalidate(managerPackagesProvider),
            ),
            data: (packages) {
              if (packages.isEmpty) {
                return EmptyView(
                  title: 'No packages at branch',
                  subtitle: filter == PackageAgeFilter.all
                      ? 'Paid deliveries waiting for a rider will appear here.'
                      : 'No packages match this filter.',
                  icon: Icons.inventory_2_outlined,
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(managerPackagesProvider);
                  await ref.read(managerPackagesProvider.future);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.screenH),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: packages.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) {
                    final pkg = packages[i];
                    return DeliveryCard(
                      delivery: pkg,
                      trailing: _AgingChip(hours: pkg.hoursAtBranch),
                      onTap: () => _openDetail(context, ref, pkg),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    WidgetRef ref,
    Delivery delivery,
  ) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DeliveryDetailScreen(
        delivery: delivery,
        onRefresh: () async {
          try {
            return await ref.read(
              managerDeliveryDetailProvider(delivery.id).future,
            );
          } catch (_) {
            return null;
          }
        },
      ),
    ));
  }
}

// ─────────────────────────────────────────────────────────────
// Summary banner
// ─────────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final List<Delivery> packages;
  const _SummaryBanner({required this.packages});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final total = packages.length;
    final fresh = packages.where((d) => d.packageAge == 'fresh').length;
    final aging = packages.where((d) => d.packageAge == 'aging').length;
    final stale = packages.where((d) => d.packageAge == 'stale').length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: stale > 0 ? AppColors.error : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.inventory_2_rounded,
                size: 18,
                color: stale > 0 ? AppColors.error : AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '$total ${total == 1 ? 'package' : 'packages'} at branch',
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _MiniStat(
                label: 'Fresh',
                value: fresh,
                color: AppColors.success,
              ),
              _MiniStat(
                label: 'Aging',
                value: aging,
                color: AppColors.warning,
              ),
              _MiniStat(
                label: 'Stale',
                value: stale,
                color: AppColors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$value $label',
            style: text.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Age filter chips
// ─────────────────────────────────────────────────────────────

class _AgeFilterChips extends ConsumerWidget {
  final PackageAgeFilter current;
  const _AgeFilterChips({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _chip(ref, 'All', PackageAgeFilter.all),
          const SizedBox(width: AppSpacing.xs),
          _chip(ref, 'Fresh', PackageAgeFilter.fresh),
          const SizedBox(width: AppSpacing.xs),
          _chip(ref, 'Aging', PackageAgeFilter.aging),
          const SizedBox(width: AppSpacing.xs),
          _chip(ref, 'Stale', PackageAgeFilter.stale),
        ],
      ),
    );
  }

  Widget _chip(WidgetRef ref, String label, PackageAgeFilter value) {
    return ChoiceChip(
      label: Text(label),
      selected: current == value,
      onSelected: (_) {
        ref.read(packageAgeFilterProvider.notifier).state = value;
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Aging chip shown in DeliveryCard's trailing slot
// ─────────────────────────────────────────────────────────────

class _AgingChip extends StatelessWidget {
  final int? hours;
  const _AgingChip({required this.hours});

  @override
  Widget build(BuildContext context) {
    if (hours == null) return const SizedBox.shrink();
    final (color, label) = _colorAndLabel(hours!);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hours! > 24)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 14,
              color: color,
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }

  (Color, String) _colorAndLabel(int h) {
    if (h < 4) {
      return (AppColors.success, '${h}h at branch');
    }
    if (h <= 24) {
      return (AppColors.warning, '${h}h at branch');
    }
    final days = h ~/ 24;
    return (
      AppColors.error,
      days == 1 ? '1d at branch' : '${days}d at branch',
    );
  }
}