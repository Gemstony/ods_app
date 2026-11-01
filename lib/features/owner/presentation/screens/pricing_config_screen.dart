import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/models/pricing_config.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../widgets/widgets.dart';
import '../providers/owner_settings_providers.dart';

/// Full-screen editor for the singleton pricing configuration.
///
/// Organised into 4 sections: Local, Regional, Compensation, Rewards.
/// Save sends `PUT /owner/pricing-config` with all 16 fields (full replace).
class PricingConfigScreen extends ConsumerStatefulWidget {
  const PricingConfigScreen({super.key});

  @override
  ConsumerState<PricingConfigScreen> createState() =>
      _PricingConfigScreenState();
}

class _PricingConfigScreenState
    extends ConsumerState<PricingConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _initialized = false;
  bool _submitting = false;
  AutovalidateMode _autoValidate = AutovalidateMode.disabled;

  final Map<String, TextEditingController> _controllers = {};
  DispatcherCompensationModel _dispatcherModel =
      DispatcherCompensationModel.flatPerPackage;

  static const _numericFields = [
    'local_rate_per_km',
    'local_minimum_fee',
    'local_rounding_increment',
    'regional_base_fee',
    'regional_minimum_fee',
    'regional_rounding_increment',
    'rider_baseline_percent',
    'rider_bonus_percent',
    'dispatcher_flat_fee',
    'dispatcher_shift_allowance',
    'dispatcher_percent',
    'reward_tier1_threshold',
    'reward_tier1_discount_percent',
    'reward_tier2_threshold',
    'reward_rolling_window_days',
  ];

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _ensureInitialized(PricingConfig config) {
    if (_initialized) return;
    _initialized = true;
    for (final field in _numericFields) {
      _controllers[field] =
          TextEditingController(text: _initialText(field, config));
    }
    _dispatcherModel = config.dispatcherCompensationModel;
  }

  String _initialText(String field, PricingConfig c) {
    final v = _getFieldValue(field, c);
    if (v is double) {
      return v == v.truncateToDouble()
          ? v.toStringAsFixed(0)
          : v.toString();
    }
    return v.toString();
  }

  dynamic _getFieldValue(String field, PricingConfig c) => switch (field) {
        'local_rate_per_km' => c.localRatePerKm,
        'local_minimum_fee' => c.localMinimumFee,
        'local_rounding_increment' => c.localRoundingIncrement,
        'regional_base_fee' => c.regionalBaseFee,
        'regional_minimum_fee' => c.regionalMinimumFee,
        'regional_rounding_increment' => c.regionalRoundingIncrement,
        'rider_baseline_percent' => c.riderBaselinePercent,
        'rider_bonus_percent' => c.riderBonusPercent,
        'dispatcher_flat_fee' => c.dispatcherFlatFee,
        'dispatcher_shift_allowance' => c.dispatcherShiftAllowance,
        'dispatcher_percent' => c.dispatcherPercent,
        'reward_tier1_threshold' => c.rewardTier1Threshold,
        'reward_tier1_discount_percent' => c.rewardTier1DiscountPercent,
        'reward_tier2_threshold' => c.rewardTier2Threshold,
        'reward_rolling_window_days' => c.rewardRollingWindowDays,
        _ => 0,
      };

  bool _isIntegerField(String field) => const {
        'local_rounding_increment',
        'regional_rounding_increment',
        'reward_tier1_threshold',
        'reward_tier2_threshold',
        'reward_rolling_window_days',
      }.contains(field);

  Future<void> _onSave(PricingConfig original) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autoValidate = AutovalidateMode.onUserInteraction);
      return;
    }

    setState(() => _submitting = true);

    final newConfig = PricingConfig(
      id: original.id,
      localRatePerKm:
          double.tryParse(_controllers['local_rate_per_km']!.text) ?? 0,
      localMinimumFee:
          double.tryParse(_controllers['local_minimum_fee']!.text) ?? 0,
      localRoundingIncrement: int.tryParse(
              _controllers['local_rounding_increment']!.text) ??
          0,
      regionalBaseFee:
          double.tryParse(_controllers['regional_base_fee']!.text) ?? 0,
      regionalMinimumFee:
          double.tryParse(_controllers['regional_minimum_fee']!.text) ?? 0,
      regionalRoundingIncrement: int.tryParse(
              _controllers['regional_rounding_increment']!.text) ??
          0,
      riderBaselinePercent:
          double.tryParse(_controllers['rider_baseline_percent']!.text) ?? 0,
      riderBonusPercent:
          double.tryParse(_controllers['rider_bonus_percent']!.text) ?? 0,
      dispatcherCompensationModel: _dispatcherModel,
      dispatcherFlatFee:
          double.tryParse(_controllers['dispatcher_flat_fee']!.text) ?? 0,
      dispatcherShiftAllowance: double.tryParse(
              _controllers['dispatcher_shift_allowance']!.text) ??
          0,
      dispatcherPercent:
          double.tryParse(_controllers['dispatcher_percent']!.text) ?? 0,
      rewardTier1Threshold:
          int.tryParse(_controllers['reward_tier1_threshold']!.text) ?? 0,
      rewardTier1DiscountPercent: double.tryParse(
              _controllers['reward_tier1_discount_percent']!.text) ??
          0,
      rewardTier2Threshold:
          int.tryParse(_controllers['reward_tier2_threshold']!.text) ?? 0,
      rewardRollingWindowDays:
          int.tryParse(_controllers['reward_rolling_window_days']!.text) ?? 0,
      updatedBy: original.updatedBy,
      createdAt: original.createdAt,
      updatedAt: original.updatedAt,
    );

    final repo = ref.read(pricingConfigRepositoryProvider);
    final result = await repo.update(newConfig);

    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(
      onSuccess: (_) {
        ref.invalidate(ownerPricingConfigProvider);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pricing configuration saved.')),
        );
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
    final configAsync = ref.watch(ownerPricingConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pricing configuration')),
      body: configAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => ErrorView(
          message: 'Could not load pricing config.',
          onRetry: () => ref.invalidate(ownerPricingConfigProvider),
        ),
        data: (config) {
          _ensureInitialized(config);
          return SafeArea(
            child: Form(
              key: _formKey,
              autovalidateMode: _autoValidate,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screenH),
                children: [
                  _section(
                    'Local delivery',
                    'Same-day deliveries within the branch\'s service area.',
                    [
                      _numField('local_rate_per_km', 'Rate per km', 'TZS', decimal: true),
                      _numField('local_minimum_fee', 'Minimum fee', 'TZS'),
                      _numField('local_rounding_increment', 'Rounding increment', 'TZS',
                          integer: true, hint: 'Round up to the next increment'),
                    ],
                  ),
                  _section(
                    'Regional delivery',
                    'ODS fee portion for out-of-area deliveries. Bus/cargo fare is added per delivery.',
                    [
                      _numField('regional_base_fee', 'Base fee', 'TZS'),
                      _numField('regional_minimum_fee', 'Minimum fee', 'TZS'),
                      _numField('regional_rounding_increment', 'Rounding increment',
                          'TZS', integer: true),
                    ],
                  ),
                  _section(
                    'Compensation',
                    'Rider earning percentages and dispatcher pay model.',
                    [
                      _numField('rider_baseline_percent', 'Rider baseline', '%',
                          decimal: true),
                      _numField('rider_bonus_percent', 'Rider bonus', '%',
                          decimal: true, hint: 'Additional-order bonus on top of baseline'),
                      _dispatcherModelField(),
                      if (_dispatcherModel ==
                          DispatcherCompensationModel.flatPerPackage)
                        _numField('dispatcher_flat_fee', 'Dispatcher fee per package', 'TZS'),
                      if (_dispatcherModel ==
                          DispatcherCompensationModel.shiftAllowance)
                        _numField('dispatcher_shift_allowance', 'Shift allowance', 'TZS'),
                      if (_dispatcherModel ==
                          DispatcherCompensationModel.percentOfFee)
                        _numField('dispatcher_percent', 'Dispatcher percent', '%',
                            decimal: true),
                    ],
                  ),
                  _section(
                    'Rewards',
                    'Distributor incentive thresholds and discounts.',
                    [
                      _numField('reward_tier1_threshold', 'Tier 1 threshold',
                          'deliveries', integer: true,
                          hint: 'Successful deliveries to unlock tier 1'),
                      _numField('reward_tier1_discount_percent',
                          'Tier 1 discount', '%', decimal: true),
                      _numField('reward_tier2_threshold', 'Tier 2 threshold',
                          'deliveries', integer: true,
                          hint: 'Successful deliveries to unlock tier 2'),
                      _numField('reward_rolling_window_days',
                          'Rolling window', 'days', integer: true),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Save changes',
                    onPressed: _submitting ? null : () => _onSave(config),
                    isLoading: _submitting,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _section(String title, String subtitle, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _numField(
    String field,
    String label,
    String? unit, {
    bool integer = false,
    bool decimal = false,
    String? hint,
  }) {
    final meta = _validatorsFor(field);
    return AppTextField(
      controller: _controllers[field]!,
      label: unit == null ? label : '$label ($unit)',
      hint: hint,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          integer && !decimal ? RegExp(r'\d') : RegExp(r'[\d.]'),
        ),
      ],
      validator: (v) {
        final text = v?.trim() ?? '';
        if (text.isEmpty) return '$label is required.';
        final parsed = integer ? int.tryParse(text) : double.tryParse(text);
        if (parsed == null) return 'Enter a valid number.';
        if (parsed < 0) return 'Must be non-negative.';
        if (meta['max'] != null && parsed > meta['max']!) {
          return 'Must be at most ${meta['max']}.';
        }
        return null;
      },
    );
  }

  Map<String, num?> _validatorsFor(String field) => switch (field) {
        'rider_baseline_percent' || 'rider_bonus_percent' ||
        'dispatcher_percent' || 'reward_tier1_discount_percent' =>
          {'max': 100},
        _ => {'max': null},
      };

  Widget _dispatcherModelField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Dispatcher compensation model',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        DropdownButtonFormField<DispatcherCompensationModel>(
          value: _dispatcherModel,
          decoration: const InputDecoration(),
          items: const [
            DropdownMenuItem(
              value: DispatcherCompensationModel.flatPerPackage,
              child: Text('Fixed amount per package'),
            ),
            DropdownMenuItem(
              value: DispatcherCompensationModel.shiftAllowance,
              child: Text('Shift allowance'),
            ),
            DropdownMenuItem(
              value: DispatcherCompensationModel.percentOfFee,
              child: Text('Percentage of fee'),
            ),
          ],
          onChanged: _submitting
              ? null
              : (v) {
                  if (v != null) setState(() => _dispatcherModel = v);
                },
        ),
      ],
    );
  }
}