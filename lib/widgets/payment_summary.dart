import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../data/models/delivery.dart';

/// Shows the fee breakdown for a delivery.
///
/// Used by:
///   - Distributor "Confirm delivery" screen (Phase 7)
///   - Delivery detail screen (Phase 7)
///   - Manager oversight (Phase 6)
///
/// Rows rendered:
///   - ODS delivery fee:      always shown (when set)
///   - Bus/cargo fare:        regional deliveries only
///   - Discount (if > 0):     label uses `discountReason` when available
///   - Total:                 always shown
///
/// When `delivery.odsDeliveryFee` is null (before price preview completes),
/// a "Calculating fee…" placeholder with a spinner is shown instead.
///
/// All values come from the delivery's own snapshot fields — this widget
/// never recomputes or calls the network.
class PaymentSummary extends StatelessWidget {
  final Delivery delivery;

  const PaymentSummary({super.key, required this.delivery});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    if (delivery.odsDeliveryFee == null) {
      return _pendingState(text);
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Fee breakdown',
            style: text.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          _lineItem(
            context,
            label: 'ODS delivery fee',
            amount: delivery.odsDeliveryFee!,
            currency: delivery.currency,
          ),

          if (delivery.isRegional && delivery.busCargoFare != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _lineItem(
              context,
              label: 'Bus / cargo fare',
              amount: delivery.busCargoFare!,
              currency: delivery.currency,
            ),
          ],

          if (delivery.discountAmount > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            _lineItem(
              context,
              label: delivery.discountReason ?? 'Discount',
              amount: -delivery.discountAmount,
              currency: delivery.currency,
              isNegative: true,
            ),
          ],

          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),

          Row(
            children: [
              Text(
                'Total',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                _formatFee(delivery.totalAmount ?? 0, delivery.currency),
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pendingState(TextTheme text) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Calculating fee…',
            style: text.bodyMedium?.copyWith(
              color: AppColors.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineItem(
    BuildContext context, {
    required String label,
    required double amount,
    required String currency,
    bool isNegative = false,
  }) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: text.bodyMedium?.copyWith(
              color: AppColors.onSurfaceMuted,
            ),
          ),
        ),
        Text(
          _formatFee(amount, currency),
          style: text.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: isNegative ? AppColors.success : AppColors.onSurface,
          ),
        ),
      ],
    );
  }

  String _formatFee(double amount, String currency) {
    final sign = amount < 0 ? '-' : '';
    return '$sign$currency ${amount.abs().toStringAsFixed(0)}';
  }
}