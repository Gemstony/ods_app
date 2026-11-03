import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/distributor_dashboard_kpis.dart';
import '../../../../widgets/widgets.dart';
import '../providers/distributor_rewards_providers.dart';

/// The Distributor's Rewards tab — full-screen progress view.
class DistributorRewardsTab extends ConsumerWidget {
  const DistributorRewardsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(distributorRewardsProvider);

    return kpisAsync.when(
      loading: () => const LoadingView(message: 'Loading your rewards…'),
      error: (_, __) => ErrorView(
        message: 'Could not load your rewards.',
        onRetry: () => ref.invalidate(distributorRewardsProvider),
      ),
      data: (kpis) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(distributorRewardsProvider);
          await ref.read(distributorRewardsProvider.future);
        },
        child: _Content(kpis: kpis),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final DistributorRewardKpis kpis;
  const _Content({required this.kpis});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // ─── Header ─────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your rewards',
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Earn discounts and free deliveries by completing '
                    'ODS deliveries.',
                    style: text.bodySmall?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (kpis.progress.currentMonth.isNotEmpty)
              _MonthBadge(month: kpis.progress.currentMonth),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // ─── Available rewards banner ───────────────────────
        if (kpis.hasAnyAvailable) ...[
          _AvailableRewardsBanner(kpis: kpis),
          const SizedBox(height: AppSpacing.md),
        ],

        // ─── Main progress card ─────────────────────────────
        RewardProgressCard(
          reward: kpis.progress,
          tier1Threshold: kpis.tier1Threshold,
          tier2Threshold: kpis.tier2Threshold,
          tier1DiscountPercent: kpis.tier1DiscountPercent,
        ),

        const SizedBox(height: AppSpacing.lg),

        // ─── How it works ───────────────────────────────────
        _HowItWorksCard(kpis: kpis),

        const SizedBox(height: AppSpacing.lg),

        // ─── Redemption history placeholder ─────────────────
        const _RedemptionHistoryPlaceholder(),

        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Month badge
// ─────────────────────────────────────────────────────────────

class _MonthBadge extends StatelessWidget {
  final String month; // 'YYYY-MM'
  const _MonthBadge({required this.month});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        _formatMonth(month),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  String _formatMonth(String month) {
    final parts = month.split('-');
    if (parts.length != 2) return month;
    final year = parts[0];
    final monthNum = int.tryParse(parts[1]);
    if (monthNum == null || monthNum < 1 || monthNum > 12) return month;
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${names[monthNum - 1]} $year';
  }
}

// ─────────────────────────────────────────────────────────────
// Available rewards banner
// ─────────────────────────────────────────────────────────────
//
// IMPORTANT: The banner copy uses celebratory phrasing that is
// intentionally different from the how-it-works card ("Tier 1
// discount" / "Tier 2 benefit"). This makes the UI clearer AND
// removes any ambiguity in test finders.

class _AvailableRewardsBanner extends StatelessWidget {
  final DistributorRewardKpis kpis;
  const _AvailableRewardsBanner({required this.kpis});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rewards = <String>[];
    final expiryDates = <String>[];

    if (kpis.progress.isTier1Usable) {
      rewards.add(
        '${kpis.tier1DiscountPercent.toStringAsFixed(0)}% off your next delivery',
      );
      if (kpis.progress.tier1ExpiresAt != null) {
        expiryDates.add(
          'Discount expires ${_formatDate(kpis.progress.tier1ExpiresAt!)}',
        );
      }
    }
    if (kpis.progress.isTier2Usable) {
      rewards.add('One free delivery');
      if (kpis.progress.tier2ExpiresAt != null) {
        expiryDates.add(
          'Free delivery expires ${_formatDate(kpis.progress.tier2ExpiresAt!)}',
        );
      }
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.successSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.success),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.celebration_rounded,
                color: AppColors.success,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Reward available!',
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final reward in rewards)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Text(
                      reward,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (expiryDates.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              expiryDates.join(' · '),
              style: text.bodySmall?.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────
// How it works
// ─────────────────────────────────────────────────────────────

class _HowItWorksCard extends StatelessWidget {
  final DistributorRewardKpis kpis;
  const _HowItWorksCard({required this.kpis});

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
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'How rewards work',
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _Rule(
            icon: Icons.local_offer_rounded,
            title: 'Tier 1 discount',
            body:
                'Complete ${kpis.tier1Threshold} successful deliveries in a '
                'calendar month to unlock a '
                '${kpis.tier1DiscountPercent.toStringAsFixed(0)}% discount '
                'on an eligible ODS delivery fee.',
          ),
          const SizedBox(height: AppSpacing.sm),
          _Rule(
            icon: Icons.card_giftcard_rounded,
            title: 'Tier 2 benefit',
            body:
                'Complete ${kpis.tier2Threshold} successful deliveries within '
                'the rolling window to unlock a free eligible delivery '
                '(ODS fee waived; bus/cargo fare still applies for Regional).',
          ),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _Rule({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primaryLight),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: text.bodySmall?.copyWith(
                  color: AppColors.onSurfaceMuted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Redemption history placeholder
// ─────────────────────────────────────────────────────────────

class _RedemptionHistoryPlaceholder extends StatelessWidget {
  const _RedemptionHistoryPlaceholder();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.history_rounded,
            size: 20,
            color: AppColors.onSurfaceSubtle,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Redemption history',
                  style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your redeemed rewards will appear here. Coming in '
                  'Phase 13.',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.onSurfaceSubtle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}