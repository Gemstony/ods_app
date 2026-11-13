import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/ledger_entries.dart';
import '../../../../widgets/widgets.dart';
import '../providers/owner_ledger_providers.dart';

class OwnerPayoutsScreen extends ConsumerWidget {
  const OwnerPayoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ownerPayoutsProvider);
    final filter = ref.watch(payoutsFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payouts')),
      body: Column(
        children: [
          _FilterBar(
            filter: filter,
            onStatuses: (s) =>
                ref.read(payoutsFilterProvider.notifier).setStatuses(s),
            onClear: () => ref.read(payoutsFilterProvider.notifier).clear(),
          ),
          const Divider(height: 1),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(message: 'Loading payouts…'),
              error: (_, __) => ErrorView(
                message: 'Could not load payouts.',
                onRetry: () => ref.invalidate(ownerPayoutsProvider),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return const EmptyView(
                    title: 'No payouts',
                    subtitle: 'Payout batches will appear here.',
                    icon: Icons.account_balance_wallet_outlined,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(ownerPayoutsProvider);
                    await ref.read(ownerPayoutsProvider.future);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.screenH),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) => _PayoutRow(entry: entries[i]),
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
  final PayoutsFilter filter;
  final ValueChanged<List<String>> onStatuses;
  final VoidCallback onClear;

  const _FilterBar({
    required this.filter,
    required this.onStatuses,
    required this.onClear,
  });

  static const _statuses = ['pending', 'processing', 'paid', 'failed', 'cancelled'];

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
      child: SingleChildScrollView(
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
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  static String _label(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _PayoutRow extends StatelessWidget {
  final OwnerPayoutEntry entry;
  const _PayoutRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final p = entry.payout;
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
                  p.reference ?? 'Payout #${p.id}',
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              Text(
                '${p.currency} ${p.amount.toStringAsFixed(0)}',
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
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
                p.status.name,
                style: text.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: p.status.name == 'paid'
                      ? AppColors.success
                      : p.status.name == 'pending' ||
                              p.status.name == 'processing'
                          ? AppColors.warning
                          : AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}