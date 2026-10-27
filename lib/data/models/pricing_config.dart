import '../../core/utils/json_helpers.dart';

/// The three ways the Owner can compensate Regional Dispatcher Agents,
/// as defined by the ODS document.
enum DispatcherCompensationModel {
  flatPerPackage,
  shiftAllowance,
  percentOfFee;

  /// Maps the backend's snake_case values to the enum.
  static DispatcherCompensationModel fromString(String value) {
    return switch (value) {
      'flat_per_package' => DispatcherCompensationModel.flatPerPackage,
      'shift_allowance' => DispatcherCompensationModel.shiftAllowance,
      'percent_of_fee' => DispatcherCompensationModel.percentOfFee,
      _ => DispatcherCompensationModel.flatPerPackage,
    };
  }

  /// Serializes back to the backend's snake_case.
  String toBackendString() {
    return switch (this) {
      DispatcherCompensationModel.flatPerPackage => 'flat_per_package',
      DispatcherCompensationModel.shiftAllowance => 'shift_allowance',
      DispatcherCompensationModel.percentOfFee => 'percent_of_fee',
    };
  }
}

/// The singleton pricing configuration for the whole platform.
///
/// Mirrors `App\Models\PricingConfig` from Phase 2.4. Each delivery snapshots
/// its relevant values at creation time (`Delivery.ratePerKm` etc. in 4.2),
/// so changing this config **never** alters historical fees.
class PricingConfig {
  final int id;

  // ─── Local delivery ──────────────────────────────────────
  final double localRatePerKm;
  final double localMinimumFee;
  final int localRoundingIncrement;

  // ─── Regional delivery (ODS portion) ─────────────────────
  final double regionalBaseFee;
  final double regionalMinimumFee;
  final int regionalRoundingIncrement;

  // ─── Compensation ────────────────────────────────────────
  final double riderBaselinePercent;
  final double riderBonusPercent;
  final DispatcherCompensationModel dispatcherCompensationModel;
  final double dispatcherFlatFee;
  final double dispatcherShiftAllowance;
  final double dispatcherPercent;

  // ─── Rewards ─────────────────────────────────────────────
  final int rewardTier1Threshold;
  final double rewardTier1DiscountPercent;
  final int rewardTier2Threshold;
  final int rewardRollingWindowDays;

  // ─── Audit ───────────────────────────────────────────────
  final int? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PricingConfig({
    required this.id,
    required this.localRatePerKm,
    required this.localMinimumFee,
    required this.localRoundingIncrement,
    required this.regionalBaseFee,
    required this.regionalMinimumFee,
    required this.regionalRoundingIncrement,
    required this.riderBaselinePercent,
    required this.riderBonusPercent,
    required this.dispatcherCompensationModel,
    required this.dispatcherFlatFee,
    required this.dispatcherShiftAllowance,
    required this.dispatcherPercent,
    required this.rewardTier1Threshold,
    required this.rewardTier1DiscountPercent,
    required this.rewardTier2Threshold,
    required this.rewardRollingWindowDays,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory PricingConfig.fromJson(Map<String, dynamic> json) {
    return PricingConfig(
      id: asInt(json['id']),
      localRatePerKm: asDouble(json['local_rate_per_km']),
      localMinimumFee: asDouble(json['local_minimum_fee']),
      localRoundingIncrement: asInt(json['local_rounding_increment']),
      regionalBaseFee: asDouble(json['regional_base_fee']),
      regionalMinimumFee: asDouble(json['regional_minimum_fee']),
      regionalRoundingIncrement: asInt(json['regional_rounding_increment']),
      riderBaselinePercent: asDouble(json['rider_baseline_percent']),
      riderBonusPercent: asDouble(json['rider_bonus_percent']),
      dispatcherCompensationModel: DispatcherCompensationModel.fromString(
        json['dispatcher_compensation_model'] as String,
      ),
      dispatcherFlatFee: asDouble(json['dispatcher_flat_fee']),
      dispatcherShiftAllowance: asDouble(json['dispatcher_shift_allowance']),
      dispatcherPercent: asDouble(json['dispatcher_percent']),
      rewardTier1Threshold: asInt(json['reward_tier1_threshold']),
      rewardTier1DiscountPercent:
          asDouble(json['reward_tier1_discount_percent']),
      rewardTier2Threshold: asInt(json['reward_tier2_threshold']),
      rewardRollingWindowDays: asInt(json['reward_rolling_window_days']),
      updatedBy: json['updated_by'] == null ? null : asInt(json['updated_by']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'local_rate_per_km': localRatePerKm,
        'local_minimum_fee': localMinimumFee,
        'local_rounding_increment': localRoundingIncrement,
        'regional_base_fee': regionalBaseFee,
        'regional_minimum_fee': regionalMinimumFee,
        'regional_rounding_increment': regionalRoundingIncrement,
        'rider_baseline_percent': riderBaselinePercent,
        'rider_bonus_percent': riderBonusPercent,
        'dispatcher_compensation_model':
            dispatcherCompensationModel.toBackendString(),
        'dispatcher_flat_fee': dispatcherFlatFee,
        'dispatcher_shift_allowance': dispatcherShiftAllowance,
        'dispatcher_percent': dispatcherPercent,
        'reward_tier1_threshold': rewardTier1Threshold,
        'reward_tier1_discount_percent': rewardTier1DiscountPercent,
        'reward_tier2_threshold': rewardTier2Threshold,
        'reward_rolling_window_days': rewardRollingWindowDays,
        'updated_by': updatedBy,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  // ─── Helpers ─────────────────────────────────────────────
  /// What percentage the rider keeps of the delivery fee (80 by default).
  double get riderEarningPercent => riderBaselinePercent;

  /// Total percentage of an additional-order bonus on top of the baseline
  /// (10 by default — separate line item).
  double get additionalOrderBonusPercent => riderBonusPercent;
}