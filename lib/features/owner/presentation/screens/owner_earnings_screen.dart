import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/ledger_entries.dart';
import '../../../../widgets/widgets.dart';
import '../providers/owner_ledger_providers.dart';

class OwnerEarningsScreen extends ConsumerWidget {
  const OwnerEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ownerEarningsProvider);
    final filter = ref.watch(earningsFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: Column(
        children: [
          _FilterBar(
            filter: filter,
            onStatuses: (s) =>
                ref.read(earningsFilterProvider.notifier).setStatuses(s),
            onTypes: (t) =>
                ref.read(earningsFilterProvider.notifier).setTypes(t),
            onClear: () => ref.read(earningsFilterProvider.notifier).clear(),
          ),
          const Divider(height: 1),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(message: 'Loading earnings…'),
              error: (_, __) => ErrorView(
                message: 'Could not load earnings.',
                onRetry: () => ref.invalidate(ownerEarningsProvider),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return const EmptyView(
                    title: 'No earnings',
                    subtitle: 'Compensation awards will appear here.',
                    icon: Icons.attach_money_outlined,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(ownerEarningsProvider);
                    await ref.read(ownerEarningsProvider.future);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.screenH),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) => _EarningRow(entry: entries[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final EarningsFilter filter;
  final ValueChanged<List<String>> onStatuses;
  final ValueChanged<List<String>> onTypes;
  final VoidCallback onClear;

  const _FilterBar({
    required this.filter,
    required this.onStatuses,
    required this.onTypes,
    required this.onClear,
  });

  static const _statuses = ['pending', 'approved', 'paid', 'cancelled'];
  static const _types = [
    'rider_baseline',
    'rider_bonus',
    'dispatcher_flat',
    'dispatcher_percent',
    'adjustment',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.screenH,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('All', filter.statuses.isEmpty, onClear),
                const SizedBox(width: 6),
                for (final s in _statuses) ...[
                  _chip(_label(s), filter.statuses.contains(s), () {
                    final set = List<String>.from(filter.statuses);
                    set.contains(s) ? set.remove(s) : set.add(s);
                    onStatuses(set);
                  }),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('All types', filter.types.isEmpty, () => onTypes([])),
                const SizedBox(width: 6),
                for (final t in _types) ...[
                  _chip(_typeLabel(t), filter.types.contains(t), () {
                    final set = List<String>.from(filter.types);
                    set.contains(t) ? set.remove(t) : set.add(t);
                    onTypes(set);
                  }),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  static String _label(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static String _typeLabel(String t) => switch (t) {
        'rider_baseline' => 'Baseline',
        'rider_bonus' => 'Bonus',
        'dispatcher_flat' => 'Disp. flat',
        'dispatcher_percent' => 'Disp. %',
        'adjustment' => 'Adjust.',
        _ => t,
      };
}

class _EarningRow extends StatelessWidget {
  final OwnerEarningEntry entry;
  const _EarningRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final e = entry.earning;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  e.typeLabel,
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                e.amountLabel,
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: e.amount < 0 ? AppColors.error : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            children: [
              if (entry.user != null) ...[
                const Icon(Icons.person_outline_rounded,
                    size: 14, color: AppColors.onSurfaceMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    entry.user!.name,
                    style: text.bodySmall?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                const Spacer(),
              Text(
                e.statusLabel,
                style: text.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: e.status.name == 'paid'
                      ? AppColors.success
                      : e.status.name == 'pending'
                          ? AppColors.warning
                          : e.status.name == 'approved'
                              ? AppColors.info
                              : AppColors.error,
                ),
              ),
            ],
          ),
          if (entry.delivery != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.local_shipping_outlined,
                    size: 14, color: AppColors.onSurfaceMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    entry.delivery!.trackingId,
                    style: text.bodySmall?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}