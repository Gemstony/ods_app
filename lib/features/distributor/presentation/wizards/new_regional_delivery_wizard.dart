import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/branch.dart';
import '../../../../data/models/delivery.dart';
import '../../../../data/models/delivery_input.dart';
import 'steps/order_details_step.dart';
import 'steps/receive_branch_step.dart';
import 'steps/regional_fare_step.dart';
import 'steps/regional_recipient_step.dart';
import 'steps/regional_review_step.dart';

/// 5-step wizard for creating a Regional delivery.
///
/// Steps:
///   0. Pickup branch         (reused from Receive — 7.3)
///   1. Order details         (reused from Receive — order IDs only,
///                             no contact phone, per 7.4's flag)
///   2. Recipient + destination region/district/bus stop
///   3. Bus/cargo transport fare
///   4. Review with two-charge breakdown + submit
///
/// Ends with a `pending_payment` delivery ready for Phase 11's payment
/// flow. The bus cargo fare is captured now and stored on the delivery
/// — the payment split is a Phase 11 concern.
///
/// Pops with the created `Delivery` on success.
class NewRegionalDeliveryWizard extends StatefulWidget {
  const NewRegionalDeliveryWizard({super.key});

  @override
  State<NewRegionalDeliveryWizard> createState() =>
      _NewRegionalDeliveryWizardState();
}

class _NewRegionalDeliveryWizardState
    extends State<NewRegionalDeliveryWizard> {
  static const _labels = [
    'Branch',
    'Order',
    'Recipient',
    'Bus fare',
    'Review',
  ];

  int _step = 0;

  Branch? _branch;
  List<DeliveryItemInput> _items = const [];
  String _recipientName = '';
  String _recipientPhone = '';
  String _destinationRegion = '';
  String _destinationDistrict = '';
  String _destinationBusStop = '';
  double _busCargoFare = 0;

  void _onBranchSelected(Branch branch) {
    setState(() {
      _branch = branch;
      _step = 1;
    });
  }

  void _onOrderSubmitted({
    required List<DeliveryItemInput> items,
    required String pickupContactPhone,
  }) {
    // pickupContactPhone intentionally ignored for Regional — the
    // recipient phone (collected in step 2) is the coordination number.
    setState(() {
      _items = items;
      _step = 2;
    });
  }

  void _onRecipientSubmitted({
    required String recipientName,
    required String recipientPhone,
    required String destinationRegion,
    required String destinationDistrict,
    required String destinationBusStop,
  }) {
    setState(() {
      _recipientName = recipientName;
      _recipientPhone = recipientPhone;
      _destinationRegion = destinationRegion;
      _destinationDistrict = destinationDistrict;
      _destinationBusStop = destinationBusStop;
      _step = 3;
    });
  }

  void _onFareSubmitted({required double busCargoFare}) {
    setState(() {
      _busCargoFare = busCargoFare;
      _step = 4;
    });
  }

  void _onBack() {
    if (_step == 0) {
      Navigator.of(context).pop();
    } else {
      setState(() => _step--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('New Regional · ${_labels[_step]}'),
          leading: IconButton(
            icon: Icon(_step == 0 ? Icons.close : Icons.arrow_back),
            onPressed: _onBack,
          ),
        ),
        body: Column(
          children: [
            _WizardProgress(
              step: _step,
              total: _labels.length,
              label: _labels[_step],
            ),
            Expanded(child: _buildCurrentStep()),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    return switch (_step) {
      0 => ReceiveBranchStep(
          onSelected: _onBranchSelected,
          onBack: _onBack,
        ),
      1 => OrderDetailsStep(
          serviceType: ServiceType.regional,
          showContactPhone: false,
          onSubmitted: _onOrderSubmitted,
          onBack: _onBack,
        ),
      2 => RegionalRecipientStep(
          onSubmitted: _onRecipientSubmitted,
          onBack: _onBack,
        ),
      3 => RegionalFareStep(
          onSubmitted: _onFareSubmitted,
          onBack: _onBack,
        ),
      4 => RegionalReviewStep(
          branch: _branch!,
          items: _items,
          recipientName: _recipientName,
          recipientPhone: _recipientPhone,
          destinationRegion: _destinationRegion,
          destinationDistrict: _destinationDistrict,
          destinationBusStop: _destinationBusStop,
          busCargoFare: _busCargoFare,
          onBack: _onBack,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _WizardProgress extends StatelessWidget {
  final int step;
  final int total;
  final String label;

  const _WizardProgress({
    required this.step,
    required this.total,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final progress = (step + 1) / total;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.sm,
        AppSpacing.screenH,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Step ${step + 1} of $total',
                style: text.bodySmall?.copyWith(
                  color: AppColors.onSurfaceMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                label,
                style: text.labelLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: AppColors.borderSubtle,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}