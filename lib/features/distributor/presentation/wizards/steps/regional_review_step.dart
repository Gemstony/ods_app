import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../data/models/branch.dart';
import '../../../../../data/models/delivery.dart';
import '../../../../../data/models/delivery_input.dart';
import '../../../../../shared/providers/repository_providers.dart';
import '../../../../../widgets/widgets.dart';
import '../../providers/distributor_dashboard_providers.dart';
import '../widgets/wizard_bottom_bar.dart';

/// Regional step 5: review + submit.
///
/// Shows ODS fee and bus fare as separate line items, then the total.
/// Matches the doc: "Regional Delivery must show the total payable
/// amount: ODS delivery fee + bus/cargo transport fare before the
/// distributor confirms the request."
class RegionalReviewStep extends ConsumerStatefulWidget {
  final Branch branch;
  final List<DeliveryItemInput> items;
  final String recipientName;
  final String recipientPhone;
  final String destinationRegion;
  final String destinationDistrict;
  final String destinationBusStop;
  final double busCargoFare;
  final VoidCallback onBack;

  const RegionalReviewStep({
    super.key,
    required this.branch,
    required this.items,
    required this.recipientName,
    required this.recipientPhone,
    required this.destinationRegion,
    required this.destinationDistrict,
    required this.destinationBusStop,
    required this.busCargoFare,
    required this.onBack,
  });

  @override
  ConsumerState<RegionalReviewStep> createState() =>
      _RegionalReviewStepState();
}

class _RegionalReviewStepState extends ConsumerState<RegionalReviewStep> {
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
        serviceType: ServiceType.regional,
        pickupBranchId: widget.branch.id,
        destinationRegion: widget.destinationRegion,
        destinationDistrict: widget.destinationDistrict,
        busCargoFare: widget.busCargoFare,
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
        serviceType: ServiceType.regional,
        items: widget.items,
        pickupBranchId: widget.branch.id,
        recipientName: widget.recipientName,
        recipientPhone: widget.recipientPhone,
        destinationRegion: widget.destinationRegion,
        destinationDistrict: widget.destinationDistrict,
        destinationBusStop: widget.destinationBusStop,
        busCargoFare: widget.busCargoFare,
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
              ? const LoadingView(message: 'Computing charges…')
              : _previewError != null
                  ? ErrorView(
                      message: _previewError!.message,
                      onRetry: _loadPreview,
                    )
                  : _ReviewContent(
                      branch: widget.branch,
                      items: widget.items,
                      recipientName: widget.recipientName,
                      recipientPhone: widget.recipientPhone,
                      destinationRegion: widget.destinationRegion,
                      destinationDistrict: widget.destinationDistrict,
                      destinationBusStop: widget.destinationBusStop,
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
  final Branch branch;
  final List<DeliveryItemInput> items;
  final String recipientName;
  final String recipientPhone;
  final String destinationRegion;
  final String destinationDistrict;
  final String destinationBusStop;
  final PricePreviewResult preview;

  const _ReviewContent({
    required this.branch,
    required this.items,
    required this.recipientName,
    required this.recipientPhone,
    required this.destinationRegion,
    required this.destinationDistrict,
    required this.destinationBusStop,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      children: [
        _Surface(
          title: 'Pickup branch',
          icon: Icons.store_outlined,
          children: [
            Text(
              branch.name,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              branch.address,
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
          title: 'Destination',
          icon: Icons.location_on_outlined,
          children: [
            Text(
              '$destinationRegion · $destinationDistrict',
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              'Bus stop: $destinationBusStop',
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
          title: 'Charges',
          icon: Icons.payments_outlined,
          children: [
            // ─── ODS fee ──────────────────────────────────
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

            // ─── Bus fare ─────────────────────────────────
            if (preview.busCargoFare != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              _PriceRow(
                label: 'Bus / cargo transport fare',
                value:
                    'TZS ${preview.busCargoFare!.toStringAsFixed(0)}',
              ),
            ],

            const Divider(height: AppSpacing.lg),
            _PriceRow(
              label: 'Total payable',
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