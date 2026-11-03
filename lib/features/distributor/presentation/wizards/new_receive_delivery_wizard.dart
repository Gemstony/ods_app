import 'package:flutter/material.dart';
import 'package:ods_app/data/models/delivery.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/branch.dart';
import '../../../../data/models/delivery_input.dart';
import 'steps/order_details_step.dart';
import 'steps/receive_branch_step.dart';
import 'steps/receive_location_step.dart';
import 'steps/receive_review_step.dart';

/// 4-step wizard for creating a Receive delivery.
///
/// Steps:
///   0. Branch picker
///   1. Order details (EXGO or WhatsApp)
///   2. Distributor's current location
///   3. Review + price preview + submit
///
/// On submit, the wizard invalidates `distributorDashboardProvider` and
/// pops with the created [Delivery] (in `pending_payment` status).
class NewReceiveDeliveryWizard extends StatefulWidget {
  const NewReceiveDeliveryWizard({super.key});

  @override
  State<NewReceiveDeliveryWizard> createState() =>
      _NewReceiveDeliveryWizardState();
}

class _NewReceiveDeliveryWizardState
    extends State<NewReceiveDeliveryWizard> {
  static const _labels = ['Branch', 'Order', 'Location', 'Review'];

  int _step = 0;

  Branch? _branch;
  List<DeliveryItemInput> _items = const [];
  String? _pickupContactPhone;
  String? _destinationAddress;
  double? _destinationLatitude;
  double? _destinationLongitude;

  void _onBranchSelected(Branch branch) {
    setState(() {
      _branch = branch;
      _step = 1;
    });
  }

  void _onOrderDetailsSubmitted({
    required List<DeliveryItemInput> items,
    required String pickupContactPhone,
  }) {
    setState(() {
      _items = items;
      _pickupContactPhone = pickupContactPhone;
      _step = 2;
    });
  }

  void _onLocationSubmitted({
    required String address,
    required double latitude,
    required double longitude,
  }) {
    setState(() {
      _destinationAddress = address;
      _destinationLatitude = latitude;
      _destinationLongitude = longitude;
      _step = 3;
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
          title: Text('New delivery · ${_labels[_step]}'),
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
          serviceType: ServiceType.receive,
          onSubmitted: _onOrderDetailsSubmitted,
          onBack: _onBack,
        ),
      2 => ReceiveLocationStep(
          onSubmitted: _onLocationSubmitted,
          onBack: _onBack,
        ),
      3 => ReceiveReviewStep(
          branch: _branch!,
          items: _items,
          pickupContactPhone: _pickupContactPhone!,
          destinationAddress: _destinationAddress!,
          destinationLatitude: _destinationLatitude!,
          destinationLongitude: _destinationLongitude!,
          onBack: _onBack,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

// ─────────────────────────────────────────────────────────────
// Progress bar
// ─────────────────────────────────────────────────────────────

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