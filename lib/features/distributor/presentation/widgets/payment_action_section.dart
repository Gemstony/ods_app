import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/delivery.dart';
import '../../../../widgets/widgets.dart';
import 'payment_flow_sheet.dart';

/// Section shown at the bottom of the delivery-detail screen when the
/// delivery is `pending_payment`. Opens the payment flow modal and calls
/// [onRefresh] when payment succeeds so the detail screen (and the caller
/// list) re-fetches.
class PaymentActionSection extends StatelessWidget {
  final Delivery delivery;
  final VoidCallback onRefresh;

  const PaymentActionSection({
    super.key,
    required this.delivery,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (delivery.status != DeliveryStatus.pending_payment) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.payment_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Payment required',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Complete payment to unlock this delivery for processing.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Pay ${delivery.totalAmountLabel}',
            icon: Icons.payment_rounded,
            onPressed: () async {
              final success =
                  await PaymentFlowSheet.show(context, delivery);
              if (success == true) onRefresh();
            },
          ),
        ],
      ),
    );
  }
}