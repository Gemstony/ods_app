import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../widgets/widgets.dart';
import '../widgets/wizard_bottom_bar.dart';

/// Regional step 3: recipient + destination region/district/bus stop.
///
/// Unlike Send, Regional doesn't collect GPS — the bus/cargo provider
/// handles delivery to a collection point. Instead, we collect the
/// recipient's name/phone plus the destination region, district, and
/// bus stop where the recipient picks up the package.
class RegionalRecipientStep extends StatefulWidget {
  final void Function({
    required String recipientName,
    required String recipientPhone,
    required String destinationRegion,
    required String destinationDistrict,
    required String destinationBusStop,
  }) onSubmitted;
  final VoidCallback onBack;

  const RegionalRecipientStep({
    super.key,
    required this.onSubmitted,
    required this.onBack,
  });

  @override
  State<RegionalRecipientStep> createState() => _RegionalRecipientStepState();
}

class _RegionalRecipientStepState extends State<RegionalRecipientStep> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _regionController = TextEditingController();
  final _districtController = TextEditingController();
  final _busStopController = TextEditingController();
  AutovalidateMode _autoValidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _regionController.dispose();
    _districtController.dispose();
    _busStopController.dispose();
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
      destinationRegion: _regionController.text.trim(),
      destinationDistrict: _districtController.text.trim(),
      destinationBusStop: _busStopController.text.trim(),
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
                  'The recipient will collect the package from the bus or '
                  'cargo station in their region.',
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
                  'Destination',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                AppTextField(
                  controller: _regionController,
                  label: 'Region',
                  hint: 'e.g. Arusha',
                  prefixIcon: Icons.map_outlined,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    return s.isEmpty ? 'Region is required.' : null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _districtController,
                  label: 'District',
                  hint: 'e.g. Arusha City',
                  prefixIcon: Icons.location_city_outlined,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    return s.isEmpty ? 'District is required.' : null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _busStopController,
                  label: 'Bus stop / collection point',
                  hint: 'e.g. Nairobi Road Station',
                  prefixIcon: Icons.directions_bus_outlined,
                  textInputAction: TextInputAction.done,
                  helperText:
                      'Where the recipient will collect the package.',
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    return s.isEmpty
                        ? 'Bus stop / collection point is required.'
                        : null;
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