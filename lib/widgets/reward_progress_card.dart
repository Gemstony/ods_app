import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../data/models/reward.dart';

/// Shows the distributor's progress toward both reward tiers.
///
/// Used by:
///   - Distributor "Rewards" tab (Phase 7)
///   - Distributor home — compact variant (Phase 7)
///
/// Thresholds default to the seeded values (20 / 50 / 50%), but callers
/// should pass the values from `pricingConfigProvider` once Phase 5 wires
/// it up.
///
/// When a tier is available:
///   - Progress bar fills 100% with success color.
///   - "AVAILABLE" badge appears.
///   - Expiry date (if set) replaces the "N more" text.
class RewardProgressCard extends StatelessWidget {
  final Reward reward;
  final int tier1Threshold;
  final int tier2Threshold;
  final double tier1DiscountPercent;

  const RewardProgressCard({
    super.key,
    required this.reward,
    this.tier1Threshold = 20,
    this.tier2Threshold = 50,
    this.tier1DiscountPercent = 50.0,
  });

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
                Icons.card_giftcard_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Reward progress',
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          _TierRow(
            title: 'Tier 1 · ${tier1DiscountPercent.toStringAsFixed(0)}% off',
            current: reward.monthlyCount,
            threshold: tier1Threshold,
            isAvailable: reward.isTier1Usable,
            expiresAt: reward.tier1ExpiresAt,
            helperLabel: 'this month',
          ),
          const SizedBox(height: AppSpacing.md),

          _TierRow(
            title: 'Tier 2 · Free delivery',
            current: reward.rollingCount,
            threshold: tier2Threshold,
            isAvailable: reward.isTier2Usable,
            expiresAt: reward.tier2ExpiresAt,
            helperLabel: 'in rolling window',
          ),
        ],
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  final String title;
  final int current;
  final int threshold;
  final bool isAvailable;
  final DateTime? expiresAt;
  final String helperLabel;

  const _TierRow({
    required this.title,
    required this.current,
    required this.threshold,
    required this.isAvailable,
    required this.helperLabel,
    this.expiresAt,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final progress =
        threshold <= 0 ? 0.0 : (current / threshold).clamp(0.0, 1.0);
    final remaining = (threshold - current).clamp(0, threshold);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
            ),
            if (isAvailable)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: const Text(
                  'AVAILABLE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: AppColors.borderSubtle,
            valueColor: AlwaysStoppedAnimation<Color>(
              isAvailable ? AppColors.success : AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Row(
          children: [
            Text(
              '$current / $threshold',
              style: text.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceMuted,
              ),
            ),
            const Spacer(),
            if (isAvailable && expiresAt != null)
              Text(
                'Expires ${_formatDate(expiresAt!)}',
                style: text.bodySmall?.copyWith(
                  color: AppColors.warning,
                ),
              )
            else if (!isAvailable)
              Text(
                '$remaining more $helperLabel',
                style: text.bodySmall?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }
}