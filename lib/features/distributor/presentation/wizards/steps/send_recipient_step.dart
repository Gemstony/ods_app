import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../widgets/widgets.dart';
import '../widgets/wizard_bottom_bar.dart';

/// Send step 3: recipient + destination details.
///
/// Collects the person receiving the delivery (name + phone) and where
/// they are (address + GPS).
class SendRecipientStep extends StatefulWidget {
  final void Function({
    required String recipientName,
    required String recipientPhone,
    required String destinationAddress,
    required double destinationLatitude,
    required double destinationLongitude,
  }) onSubmitted;
  final VoidCallback onBack;

  const SendRecipientStep({
    super.key,
    required this.onSubmitted,
    required this.onBack,
  });

  @override
  State<SendRecipientStep> createState() => _SendRecipientStepState();
}

class _SendRecipientStepState extends State<SendRecipientStep> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  AutovalidateMode _autoValidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autoValidate = AutovalidateMode.onUserInteraction);
      return;
    }

    widget.onSubmitted(
      recipientName: _nameController.text.trim(),
      recipientPhone: _phoneController.text.trim(),
      destinationAddress: _addressController.text.trim(),
      destinationLatitude: double.parse(_latController.text.trim()),
      destinationLongitude: double.parse(_lngController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: _autoValidate,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenH),
              children: [
                Text(
                  'Who is receiving the products?',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'The rider will contact this person and deliver to this '
                  'address.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _nameController,
                  label: 'Recipient name',
                  hint: 'Full name',
                  prefixIcon: Icons.person_outline,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return 'Recipient name is required.';
                    if (s.length < 2) return 'Name is too short.';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _phoneController,
                  label: 'Recipient phone',
                  hint: '0712 345 678',
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                  textInputAction: TextInputAction.next,
                  validator: (v) => Validators.phone(v),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Delivery address',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                AppTextField(
                  controller: _addressController,
                  label: 'Address',
                  hint: 'Street, area, city',
                  prefixIcon: Icons.location_on_outlined,
                  maxLines: 2,
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return 'Address is required.';
                    if (s.length < 5) return 'Address is too short.';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _latController,
                        label: 'Latitude',
                        hint: '-6.7924',
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                          decimal: true,
                        ),
                        prefixIcon: Icons.my_location_outlined,
                        validator: _validateLatitude,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppTextField(
                        controller: _lngController,
                        label: 'Longitude',
                        hint: '39.2083',
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                          decimal: true,
                        ),
                        prefixIcon: Icons.explore_outlined,
                        validator: _validateLongitude,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          WizardBottomBar(
            onBack: widget.onBack,
            nextLabel: 'Next',
            onNext: _submit,
          ),
        ],
      ),
    );
  }

  String? _validateLatitude(String? v) {
    final d = double.tryParse(v?.trim() ?? '');
    if (d == null) return 'Required.';
    if (d < -90 || d > 90) return 'Between -90 and 90.';
    return null;
  }

  String? _validateLongitude(String? v) {
    final d = double.tryParse(v?.trim() ?? '');
    if (d == null) return 'Required.';
    if (d < -180 || d > 180) return 'Between -180 and 180.';
    return null;
  }
}