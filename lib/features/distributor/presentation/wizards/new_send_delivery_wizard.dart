import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/delivery.dart';
import '../../../../data/models/delivery_input.dart';
import 'steps/order_details_step.dart';
import 'steps/send_recipient_step.dart';
import 'steps/send_review_step.dart';
import 'steps/wizard_location_step.dart';

/// 4-step wizard for creating a Send delivery.
///
/// Steps:
///   0. Order details (EXGO or WhatsApp) — no contact phone
///   1. Pickup location (distributor's current location)
///   2. Recipient details (name + phone + destination address + GPS)
///   3. Review + price preview + submit
///
/// Ends with a `pending_payment` delivery ready for Phase 11's payment
/// flow. Pops with the created `Delivery` on success.
class NewSendDeliveryWizard extends StatefulWidget {
  const NewSendDeliveryWizard({super.key});

  @override
  State<NewSendDeliveryWizard> createState() => _NewSendDeliveryWizardState();
}

class _NewSendDeliveryWizardState extends State<NewSendDeliveryWizard> {
  static const _labels = ['Order', 'Pickup', 'Recipient', 'Review'];

  int _step = 0;

  List<DeliveryItemInput> _items = const [];
  String _pickupAddress = '';
  double _pickupLatitude = 0;
  double _pickupLongitude = 0;
  String _recipientName = '';
  String _recipientPhone = '';
  String _destinationAddress = '';
  double _destinationLatitude = 0;
  double _destinationLongitude = 0;

  void _onOrderDetailsSubmitted({
    required List<DeliveryItemInput> items,
    required String pickupContactPhone,
  }) {
    // pickupContactPhone intentionally ignored for Send — the rider
    // contacts the recipient directly.
    setState(() {
      _items = items;
      _step = 1;
    });
  }

  void _onPickupSubmitted({
    required String address,
    required double latitude,
    required double longitude,
  }) {
    setState(() {
      _pickupAddress = address;
      _pickupLatitude = latitude;
      _pickupLongitude = longitude;
      _step = 2;
    });
  }

  void _onRecipientSubmitted({
    required String recipientName,
    required String recipientPhone,
    required String destinationAddress,
    required double destinationLatitude,
    required double destinationLongitude,
  }) {
    setState(() {
      _recipientName = recipientName;
      _recipientPhone = recipientPhone;
      _destinationAddress = destinationAddress;
      _destinationLatitude = destinationLatitude;
      _destinationLongitude = destinationLongitude;
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
          title: Text('New Send · ${_labels[_step]}'),
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
      0 => OrderDetailsStep(
          serviceType: ServiceType.send,
          showContactPhone: false,
          onSubmitted: _onOrderDetailsSubmitted,
          onBack: _onBack,
        ),
      1 => WizardLocationStep(
          title: 'Where are you dispatching from?',
          subtitle:
              'Enter your current location — this is where the rider '
              'will collect the products.',
          onSubmitted: _onPickupSubmitted,
          onBack: _onBack,
        ),
      2 => SendRecipientStep(
          onSubmitted: _onRecipientSubmitted,
          onBack: _onBack,
        ),
      3 => SendReviewStep(
          items: _items,
          pickupAddress: _pickupAddress,
          pickupLatitude: _pickupLatitude,
          pickupLongitude: _pickupLongitude,
          recipientName: _recipientName,
          recipientPhone: _recipientPhone,
          destinationAddress: _destinationAddress,
          destinationLatitude: _destinationLatitude,
          destinationLongitude: _destinationLongitude,
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