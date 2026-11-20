import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../widgets/dar_es_salaam_map_picker.dart';
import '../../../../../widgets/widgets.dart';
import '../widgets/wizard_bottom_bar.dart';

/// Step 3: enter the distributor's current location.
///
/// The distributor enters their address + map location. This is the
/// delivery destination for a Receive delivery.
class ReceiveLocationStep extends StatefulWidget {
  final void Function({
    required String address,
    required double latitude,
    required double longitude,
  }) onSubmitted;
  final VoidCallback onBack;

  const ReceiveLocationStep({
    super.key,
    required this.onSubmitted,
    required this.onBack,
  });

  @override
  State<ReceiveLocationStep> createState() => _ReceiveLocationStepState();
}

class _ReceiveLocationStepState extends State<ReceiveLocationStep> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  AutovalidateMode _autoValidate = AutovalidateMode.disabled;

  LatLng? get _initialMapPosition {
    final latitude = double.tryParse(_latController.text);
    final longitude = double.tryParse(_lngController.text);
    if (latitude == null || longitude == null || (latitude == 0 && longitude == 0)) return null;
    return LatLng(latitude, longitude);
  }

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
                  'Where should we deliver?',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Enter your current location — this is where the rider '
                  'will bring the products.',
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
                DarEsSalaamMapPicker(
                  initialPosition: _initialMapPosition,
                  enabled: true,
                  onChanged: (point) {
                    _latController.text = point.latitude.toString();
                    _lngController.text = point.longitude.toString();
                  },
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
}
