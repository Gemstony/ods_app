import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../widgets/widgets.dart';
import '../widgets/wizard_bottom_bar.dart';

/// Generic location-collection step.
///
/// Used by Send (pickup = distributor's location). Receive has its own
/// `ReceiveLocationStep` for now — the two can be unified in a later
/// polish pass. This one is title-parameterized so Send gets the right
/// heading without a dedicated file.
///
/// Collects: address (multi-line) + latitude + longitude.
class WizardLocationStep extends StatefulWidget {
  final String title;
  final String subtitle;
  final void Function({
    required String address,
    required double latitude,
    required double longitude,
  }) onSubmitted;
  final VoidCallback onBack;

  const WizardLocationStep({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onSubmitted,
    required this.onBack,
  });

  @override
  State<WizardLocationStep> createState() => _WizardLocationStepState();
}

class _WizardLocationStepState extends State<WizardLocationStep> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  AutovalidateMode _autoValidate = AutovalidateMode.disabled;

  @override
  void dispose() {
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
      address: _addressController.text.trim(),
      latitude: double.parse(_latController.text.trim()),
      longitude: double.parse(_lngController.text.trim()),
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
                  widget.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  widget.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
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
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'GPS coordinates',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Find your GPS coordinates in a maps app (e.g., Google '
                  'Maps → long-press → copy coordinates).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
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