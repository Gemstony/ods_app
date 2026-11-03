import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../widgets/widgets.dart';
import '../widgets/wizard_bottom_bar.dart';

/// Regional step 4: bus/cargo transport fare.
///
/// The distributor enters the fare their bus/cargo provider will charge.
/// This is a *separate* charge from the ODS delivery fee — the recipient
/// pays ODS for the service and the provider for the transport.
///
/// Entering 0 is valid — the recipient picks up from the station at no
/// additional cost (some providers include it; some distributors arrange
/// it themselves).
class RegionalFareStep extends StatefulWidget {
  final void Function({required double busCargoFare}) onSubmitted;
  final VoidCallback onBack;

  const RegionalFareStep({
    super.key,
    required this.onSubmitted,
    required this.onBack,
  });

  @override
  State<RegionalFareStep> createState() => _RegionalFareStepState();
}

class _RegionalFareStepState extends State<RegionalFareStep> {
  final _formKey = GlobalKey<FormState>();
  final _fareController = TextEditingController();
  AutovalidateMode _autoValidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _fareController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autoValidate = AutovalidateMode.onUserInteraction);
      return;
    }

    widget.onSubmitted(
      busCargoFare: double.parse(_fareController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
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
                  'Bus / cargo transport fare',
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'The amount your bus or cargo provider will charge for '
                  'transporting the package.',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ─── Two-charge explanation ────────────────────
                _TwoChargeBanner(),
                const SizedBox(height: AppSpacing.lg),

                AppTextField(
                  controller: _fareController,
                  label: 'Transport fare (TZS)',
                  hint: '3500',
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.directions_bus_outlined,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  helperText:
                      'Enter 0 if the recipient collects from the bus '
                      'station at no additional cost.',
                  validator: _validateFare,
                ),
              ],
            ),
          ),
          WizardBottomBar(
            onBack: widget.onBack,
            nextLabel: 'Review',
            onNext: _submit,
          ),
        ],
      ),
    );
  }

  String? _validateFare(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Transport fare is required (enter 0 if none).';
    final n = double.tryParse(s);
    if (n == null) return 'Enter a valid number.';
    if (n < 0) return 'Fare cannot be negative.';
    if (n > 1000000) return 'Fare is unexpectedly high.';
    return null;
  }
}

class _TwoChargeBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.infoSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.info),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppColors.info,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Two separate charges',
                style: text.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Regional delivery has two charges:\n'
            '• ODS delivery fee — the service charge for arranging the '
            'delivery\n'
            '• Bus/cargo fare — paid to the transport provider',
            style: text.bodySmall?.copyWith(
              color: AppColors.onSurface,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}