import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/delivery.dart';
import '../../../../data/models/distributor_dashboard_kpis.dart';
import '../../../../widgets/widgets.dart';
import '../providers/distributor_dashboard_providers.dart';

/// The Distributor's Home tab — command center for the customer.
///
/// Shows: KPI tiles (active / awaiting payment / delivered / total),
/// spend card, reward progress card, and a compact recent-activity
/// preview. A FAB will open the create wizard in 7.3.
class DistributorHomeTab extends ConsumerWidget {
  const DistributorHomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(distributorDashboardProvider);

    return kpisAsync.when(
      loading: () => const LoadingView(message: 'Loading your dashboard…'),
      error: (_, __) => ErrorView(
        message: 'Could not load your dashboard.',
        onRetry: () => ref.invalidate(distributorDashboardProvider),
      ),
      data: (kpis) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(distributorDashboardProvider);
          await ref.read(distributorDashboardProvider.future);
        },
        child: _Content(kpis: kpis),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final DistributorDashboardKpis kpis;
  const _Content({required this.kpis});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // ─── Greeting ───────────────────────────────────────
        Text(
          'Your deliveries',
          style: text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          _formatDate(DateTime.now()),
          style: text.bodySmall?.copyWith(
            color: AppColors.onSurfaceMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ─── KPI grid ───────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                icon: Icons.local_shipping_rounded,
                label: 'Active',
                value: '${kpis.deliveries.activeCount}',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _KpiTile(
                icon: Icons.schedule_rounded,
                label: 'Awaiting payment',
                value: '${kpis.deliveries.awaitingPaymentCount}',
                isHighlighted: kpis.deliveries.awaitingPaymentCount > 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                icon: Icons.check_circle_rounded,
                label: 'Delivered this month',
                value: '${kpis.deliveries.deliveredThisMonth}',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _KpiTile(
                icon: Icons.inventory_2_rounded,
                label: 'Total this month',
                value: '${kpis.deliveries.totalThisMonth}',
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),

        // ─── Spend ──────────────────────────────────────────
        _SectionHeader(
          title: 'Spent this month',
          icon: Icons.payments_rounded,
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.trending_up_rounded,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _formatTsh(kpis.revenue.spentThisMonthTsh),
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // ─── Rewards ────────────────────────────────────────
        if (kpis.rewards.hasAnyAvailable) ...[
          _AvailableRewardBanner(),
          const SizedBox(height: AppSpacing.sm),
        ],
        RewardProgressCard(
          reward: kpis.rewards.progress,
          tier1Threshold: kpis.rewards.tier1Threshold,
          tier2Threshold: kpis.rewards.tier2Threshold,
          tier1DiscountPercent: kpis.rewards.tier1DiscountPercent,
        ),

        // ─── Recent activity ────────────────────────────────
        if (kpis.recentDeliveries.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _SectionHeader(
            title: 'Recent activity',
            icon: Icons.history_rounded,
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final d in kpis.recentDeliveries) ...[
            DeliveryCard(delivery: d),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],

        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Available reward banner
// ─────────────────────────────────────────────────────────────

class _AvailableRewardBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.successSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.success),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.celebration_rounded,
            color: AppColors.success,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'You have a reward available! Use it on your next delivery.',
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
// KPI tile
// ─────────────────────────────────────────────────────────────

class _KpiTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isHighlighted;

  const _KpiTile({
    required this.icon,
    required this.label,
    required this.value,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final valueColor = isHighlighted ? AppColors.warning : AppColors.onSurface;
    final iconColor = isHighlighted ? AppColors.warning : AppColors.primary;

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
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Text(
                  label,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        Text(
          title,
          style: text.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Formatting helpers
// ─────────────────────────────────────────────────────────────

String _formatTsh(double amount) {
  if (amount >= 1000000) {
    return 'TZS ${(amount / 1000000).toStringAsFixed(1)}M';
  }
  if (amount >= 10000) {
    return 'TZS ${(amount / 1000).toStringAsFixed(1)}k';
  }
  return 'TZS ${amount.toStringAsFixed(0)}';
}

String _formatDate(DateTime dt) {
  const weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${weekdays[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
}