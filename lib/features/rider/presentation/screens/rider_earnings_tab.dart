import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/earning.dart';
import '../../../../data/repositories/earnings_repository.dart';
import '../../../../widgets/widgets.dart';
import '../providers/rider_earnings_providers.dart';

/// The Rider's Earnings tab.
///
/// Three-block layout:
///   1. Summary card — owed / paid this month / paid all-time
///   2. Status filter chips (All / Pending / Approved / Paid / Cancelled)
///   3. List of earning rows (type, tracking ID, status badge, amount,
///      date)
///
/// Earnings rows do not exist until Phase 11 wires the compensation
/// service, so this tab shows an empty state today. The empty state is
/// informational rather than terse — the rider should understand WHY
/// (they haven't completed any deliveries yet).
class RiderEarningsTab extends ConsumerWidget {
  const RiderEarningsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(riderEarningsProvider);

    return async.when(
      loading: () => const LoadingView(message: 'Loading your earnings…'),
      error: (_, __) => ErrorView(
        message: 'Could not load your earnings.',
        onRetry: () => ref.invalidate(riderEarningsProvider),
      ),
      data: (result) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(riderEarningsProvider);
          await ref.read(riderEarningsProvider.future);
        },
        child: _Content(result: result),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  final EarningsResult result;
  const _Content({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(riderEarningsFilterProvider);
    final filtered = ref.watch(filteredRiderEarningsProvider);
    final hasEarnings = result.items.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _SummaryCard(result: result),
        const SizedBox(height: AppSpacing.lg),
        _FilterChips(
          activeStatus: filter.status,
          onChanged: (s) =>
              ref.read(riderEarningsFilterProvider.notifier).setStatus(s),
        ),
        const SizedBox(height: AppSpacing.md),
        if (!hasEarnings)
          const _EmptyState()
        else if (filtered.isEmpty)
          _FilterEmptyState(
            onClear: () =>
                ref.read(riderEarningsFilterProvider.notifier).clear(),
          )
        else
          for (final e in filtered) ...[
            _EarningCard(earning: e),
            const SizedBox(height: AppSpacing.sm),
          ],
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Summary card
// ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final EarningsResult result;
  const _SummaryCard({required this.result});

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
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Earnings summary',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _SummaryRow(
            icon: Icons.schedule_rounded,
            label: 'Owed to you',
            value: _formatTsh(result.owedTsh),
            valueColor:
                result.owedTsh > 0 ? AppColors.warning : AppColors.onSurface,
          ),
          _SummaryRow(
            icon: Icons.calendar_month_rounded,
            label: 'Paid this month',
            value: _formatTsh(result.paidThisMonthTsh),
          ),
          _SummaryRow(
            icon: Icons.emoji_events_rounded,
            label: 'All-time paid',
            value: _formatTsh(result.paidTotalTsh),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.onSurfaceMuted),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: text.bodyMedium?.copyWith(
              color: AppColors.onSurfaceMuted,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: text.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Filter chips
// ─────────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  final EarningStatus? activeStatus;
  final ValueChanged<EarningStatus?> onChanged;

  const _FilterChips({
    required this.activeStatus,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('All', null),
          const SizedBox(width: 6),
          _chip('Pending', EarningStatus.pending),
          const SizedBox(width: 6),
          _chip('Approved', EarningStatus.approved),
          const SizedBox(width: 6),
          _chip('Paid', EarningStatus.paid),
          const SizedBox(width: 6),
          _chip('Cancelled', EarningStatus.cancelled),
        ],
      ),
    );
  }

  Widget _chip(String label, EarningStatus? status) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: activeStatus == status,
      onSelected: (_) => onChanged(status),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Earning card
// ─────────────────────────────────────────────────────────────

class _EarningCard extends StatelessWidget {
  final Earning earning;
  const _EarningCard({required this.earning});

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                _iconFor(earning.type),
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  earning.typeLabel,
                  style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                earning.amountLabel,
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: earning.isNegative
                      ? AppColors.error
                      : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              if (earning.deliveryTrackingId != null) ...[
                Icon(
                  Icons.local_shipping_outlined,
                  size: 14,
                  color: AppColors.onSurfaceMuted,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Expanded(
                  child: Text(
                    earning.deliveryTrackingId!,
                    style: text.bodySmall?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                const Spacer(),
              const SizedBox(width: AppSpacing.xs),
              _StatusBadge(status: earning.status),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            _formatDate(earning.earnedAt),
            style: text.bodySmall?.copyWith(
              color: AppColors.onSurfaceSubtle,
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(EarningType t) {
    return switch (t) {
      EarningType.rider_baseline => Icons.receipt_long_rounded,
      EarningType.rider_bonus => Icons.celebration_rounded,
      EarningType.dispatcher_flat => Icons.work_rounded,
      EarningType.dispatcher_shift => Icons.schedule_rounded,
      EarningType.dispatcher_percent => Icons.percent_rounded,
      EarningType.adjustment => Icons.tune_rounded,
    };
  }
}

class _StatusBadge extends StatelessWidget {
  final EarningStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (status) {
      EarningStatus.pending => (
          'Pending',
          AppColors.warning,
          AppColors.warningSurface
        ),
      EarningStatus.approved => (
          'Approved',
          AppColors.info,
          AppColors.infoSurface
        ),
      EarningStatus.paid => (
          'Paid',
          AppColors.success,
          AppColors.successSurface
        ),
      EarningStatus.cancelled => (
          'Cancelled',
          AppColors.error,
          AppColors.errorSurface
        ),
      EarningStatus.unknown => (
          'Unknown',
          AppColors.onSurfaceMuted,
          AppColors.surface
        ),
    };

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
          color: fg,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Empty states
// ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.surface,
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No earnings yet',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Your earnings will appear here once you complete deliveries.',
            style: text.bodyMedium?.copyWith(
              color: AppColors.onSurfaceMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FilterEmptyState extends StatelessWidget {
  final VoidCallback onClear;
  const _FilterEmptyState({required this.onClear});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.surface,
            child: Icon(
              Icons.filter_alt_off_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No earnings match this filter',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear_rounded, size: 18),
            label: const Text('Clear filter'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────

String _formatTsh(double amount) {
  if (amount.abs() >= 1000000) {
    return 'TZS ${(amount / 1000000).toStringAsFixed(1)}M';
  }
  if (amount.abs() >= 10000) {
    return 'TZS ${(amount / 1000).toStringAsFixed(1)}k';
  }
  return 'TZS ${amount.toStringAsFixed(0)}';
}

String _formatDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}