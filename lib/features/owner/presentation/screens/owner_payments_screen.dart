import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/ledger_entries.dart';
import '../../../../widgets/widgets.dart';
import '../providers/owner_ledger_providers.dart';
import 'owner_payment_detail_screen.dart';

class OwnerPaymentsScreen extends ConsumerWidget {
  const OwnerPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ownerPaymentsProvider);
    final filter = ref.watch(paymentsFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: Column(
        children: [
          _FilterBar(
            filter: filter,
            onStatusesChanged: (s) => ref
                .read(paymentsFilterProvider.notifier)
                .setStatuses(s),
            onClear: () => ref.read(paymentsFilterProvider.notifier).clear(),
          ),
          const Divider(height: 1),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(message: 'Loading payments…'),
              error: (_, __) => ErrorView(
                message: 'Could not load payments.',
                onRetry: () => ref.invalidate(ownerPaymentsProvider),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return const EmptyView(
                    title: 'No payments',
                    subtitle: 'Payment records will appear here.',
                    icon: Icons.payments_outlined,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(ownerPaymentsProvider);
                    await ref.read(ownerPaymentsProvider.future);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.screenH),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) => _PaymentRow(entry: entries[i]),
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
  final PaymentsFilter filter;
  final ValueChanged<List<String>> onStatusesChanged;
  final VoidCallback onClear;

  const _FilterBar({
    required this.filter,
    required this.onStatusesChanged,
    required this.onClear,
  });

  static const _statuses = [
    'pending',
    'processing',
    'completed',
    'failed',
    'refunded',
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip('All', filter.statuses.isEmpty, () => onClear()),
            const SizedBox(width: 6),
            for (final s in _statuses) ...[
              _chip(
                _label(s),
                filter.statuses.contains(s),
                () {
                  final set = List<String>.from(filter.statuses);
                  set.contains(s) ? set.remove(s) : set.add(s);
                  onStatusesChanged(set);
                },
              ),
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

class _PaymentRow extends StatelessWidget {
  final OwnerPaymentEntry entry;
  const _PaymentRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final p = entry.payment;
    final text = Theme.of(context).textTheme;
    final (statusColor, statusBg) = _statusColors(p.status.name);

    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OwnerPaymentDetailScreen(paymentId: p.id),
      )),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
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
                    p.reference,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusBadge(
                  label: p.statusLabel,
                  color: statusColor,
                  bg: statusBg,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Row(
              children: [
                Text(
                  p.amountLabel,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  p.stageLabel,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
            if (entry.delivery != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: [
                  const Icon(
                    Icons.local_shipping_outlined,
                    size: 14,
                    color: AppColors.onSurfaceMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${entry.delivery!.trackingId} · ${entry.delivery!.status}',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static (Color, Color) _statusColors(String s) => switch (s) {
        'completed' => (AppColors.success, AppColors.successSurface),
        'pending' || 'processing' => (AppColors.warning, AppColors.warningSurface),
        'failed' || 'cancelled' => (AppColors.error, AppColors.errorSurface),
        'refunded' => (AppColors.info, AppColors.infoSurface),
        _ => (AppColors.onSurfaceMuted, AppColors.surface),
      };
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}