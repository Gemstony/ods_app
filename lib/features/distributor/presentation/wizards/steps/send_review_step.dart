import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../data/models/delivery.dart';
import '../../../../../data/models/delivery_input.dart';
import '../../../../../shared/providers/repository_providers.dart';
import '../../../../../widgets/widgets.dart';
import '../../providers/distributor_dashboard_providers.dart';
import '../widgets/wizard_bottom_bar.dart';

/// Send step 4: review + submit.
///
/// Loads a price preview on init. On submit, creates the delivery via
/// `POST /distributor/deliveries` (Send-specific payload) and pops the
/// wizard with the created `Delivery` (in `pending_payment` status).
class SendReviewStep extends ConsumerStatefulWidget {
  final List<DeliveryItemInput> items;
  final String pickupAddress;
  final double pickupLatitude;
  final double pickupLongitude;
  final String recipientName;
  final String recipientPhone;
  final String destinationAddress;
  final double destinationLatitude;
  final double destinationLongitude;
  final VoidCallback onBack;

  const SendReviewStep({
    super.key,
    required this.items,
    required this.pickupAddress,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.recipientName,
    required this.recipientPhone,
    required this.destinationAddress,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.onBack,
  });

  @override
  ConsumerState<SendReviewStep> createState() => _SendReviewStepState();
}

class _SendReviewStepState extends ConsumerState<SendReviewStep> {
  PricePreviewResult? _preview;
  Failure? _previewError;
  bool _loadingPreview = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _loadingPreview = true;
      _previewError = null;
    });
    final repo = ref.read(deliveryRepositoryProvider);
    final result = await repo.pricePreview(
      PricePreviewInput(
        serviceType: ServiceType.send,
        pickupLatitude: widget.pickupLatitude,
        pickupLongitude: widget.pickupLongitude,
        destinationLatitude: widget.destinationLatitude,
        destinationLongitude: widget.destinationLongitude,
        applyReward: false,
      ),
    );
    if (!mounted) return;
    result.fold(
      onSuccess: (preview) => setState(() {
        _preview = preview;
        _loadingPreview = false;
      }),
      onFailure: (failure) => setState(() {
        _previewError = failure;
        _loadingPreview = false;
      }),
    );
  }

  Future<void> _submit() async {
    if (_preview == null) return;
    setState(() => _submitting = true);

    final repo = ref.read(deliveryRepositoryProvider);
    final result = await repo.create(
      CreateDeliveryInput(
        serviceType: ServiceType.send,
        items: widget.items,
        pickupAddress: widget.pickupAddress,
        pickupLatitude: widget.pickupLatitude,
        pickupLongitude: widget.pickupLongitude,
        recipientName: widget.recipientName,
        recipientPhone: widget.recipientPhone,
        destinationAddress: widget.destinationAddress,
        destinationLatitude: widget.destinationLatitude,
        destinationLongitude: widget.destinationLongitude,
      ),
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(
      onSuccess: (delivery) {
        ref.invalidate(distributorDashboardProvider);
        Navigator.of(context).pop<Delivery>(delivery);
      },
      onFailure: (failure) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(failure.message),
            backgroundColor: AppColors.error,
          ));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _loadingPreview
              ? const LoadingView(message: 'Computing delivery fee…')
              : _previewError != null
                  ? ErrorView(
                      message: _previewError!.message,
                      onRetry: _loadPreview,
                    )
                  : _ReviewContent(
                      items: widget.items,
                      pickupAddress: widget.pickupAddress,
                      pickupLatitude: widget.pickupLatitude,
                      pickupLongitude: widget.pickupLongitude,
                      recipientName: widget.recipientName,
                      recipientPhone: widget.recipientPhone,
                      destinationAddress: widget.destinationAddress,
                      destinationLatitude: widget.destinationLatitude,
                      destinationLongitude: widget.destinationLongitude,
                      preview: _preview!,
                    ),
        ),
        WizardBottomBar(
          onBack: _submitting ? null : widget.onBack,
          nextLabel: 'Submit & pay',
          onNext: _preview == null || _submitting ? null : _submit,
          isLoading: _submitting,
        ),
      ],
    );
  }
}

class _ReviewContent extends StatelessWidget {
  final List<DeliveryItemInput> items;
  final String pickupAddress;
  final double pickupLatitude;
  final double pickupLongitude;
  final String recipientName;
  final String recipientPhone;
  final String destinationAddress;
  final double destinationLatitude;
  final double destinationLongitude;
  final PricePreviewResult preview;

  const _ReviewContent({
    required this.items,
    required this.pickupAddress,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.recipientName,
    required this.recipientPhone,
    required this.destinationAddress,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        _Surface(
          title: 'Pickup (your location)',
          icon: Icons.store_outlined,
          children: [
            Text(
              pickupAddress,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              '${pickupLatitude.toStringAsFixed(5)}, '
              '${pickupLongitude.toStringAsFixed(5)}',
              style: text.bodySmall?.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _Surface(
          title: 'Recipient',
          icon: Icons.person_outline,
          children: [
            Text(
              recipientName,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            Row(
              children: [
                const Icon(Icons.phone_outlined,
                    size: 14, color: AppColors.onSurfaceMuted),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  recipientPhone,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _Surface(
          title: 'Deliver to',
          icon: Icons.location_on_outlined,
          children: [
            Text(
              destinationAddress,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              '${destinationLatitude.toStringAsFixed(5)}, '
              '${destinationLongitude.toStringAsFixed(5)}',
              style: text.bodySmall?.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _Surface(
          title: 'Items (${items.length})',
          icon: Icons.inventory_2_outlined,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                child: Text(
                  item.exgoOrderId != null
                      ? 'EXGO ${item.exgoOrderId}'
                      : '${item.quantity ?? 1} × ${item.productName}'
                          '${item.productCode != null ? ' · ${item.productCode}' : ''}',
                  style: text.bodySmall,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _Surface(
          title: 'Price',
          icon: Icons.payments_outlined,
          children: [
            _PriceRow(
              label: 'ODS delivery fee',
              value: 'TZS ${preview.odsDeliveryFee.toStringAsFixed(0)}',
            ),
            if (preview.hasDiscount) ...[
              const SizedBox(height: AppSpacing.xxs),
              _PriceRow(
                label: preview.discountReason ?? 'Discount',
                value: '-TZS ${preview.discountAmount.toStringAsFixed(0)}',
                isDiscount: true,
              ),
            ],
            const Divider(height: AppSpacing.lg),
            _PriceRow(
              label: 'Total',
              value: preview.totalLabel,
              isBold: true,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'You will be redirected to payment after submitting.',
              style: text.bodySmall?.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Surface extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _Surface({
    required this.title,
    required this.icon,
    required this.children,
  });

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
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ...children,
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool isDiscount;

  const _PriceRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.isDiscount = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: text.bodyMedium?.copyWith(
              color: AppColors.onSurfaceMuted,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          value,
          style: text.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: isDiscount ? AppColors.success : null,
          ),
        ),
      ],
    );
  }
}