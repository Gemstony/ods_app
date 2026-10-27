import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/data/models/pricing_config.dart';

Map<String, dynamic> _fullJson() => {
      'id': 1,
      'local_rate_per_km': 500.00,
      'local_minimum_fee': 1000.00,
      'local_rounding_increment': 500,
      'regional_base_fee': 0.00,
      'regional_minimum_fee': 0.00,
      'regional_rounding_increment': 500,
      'rider_baseline_percent': 80.00,
      'rider_bonus_percent': 10.00,
      'dispatcher_compensation_model': 'flat_per_package',
      'dispatcher_flat_fee': 500.00,
      'dispatcher_shift_allowance': 0.00,
      'dispatcher_percent': 0.00,
      'reward_tier1_threshold': 20,
      'reward_tier1_discount_percent': 50.00,
      'reward_tier2_threshold': 50,
      'reward_rolling_window_days': 30,
      'updated_by': null,
      'created_at': '2026-10-24T07:00:00+00:00',
      'updated_at': '2026-10-24T07:00:00+00:00',
    };

void main() {
  group('PricingConfig.fromJson', () {
    test('parses all fields', () {
      final config = PricingConfig.fromJson(_fullJson());

      expect(config.id, 1);
      expect(config.localRatePerKm, 500.00);
      expect(config.localMinimumFee, 1000.00);
      expect(config.localRoundingIncrement, 500);
      expect(config.riderBaselinePercent, 80.00);
      expect(config.riderBonusPercent, 10.00);
      expect(config.dispatcherCompensationModel,
          DispatcherCompensationModel.flatPerPackage);
      expect(config.rewardTier1Threshold, 20);
      expect(config.rewardTier2Threshold, 50);
      expect(config.rewardRollingWindowDays, 30);
    });

    test('parses all three dispatcher compensation models', () {
      expect(
        PricingConfig.fromJson(
          Map<String, dynamic>.from(_fullJson())
            ..['dispatcher_compensation_model'] = 'flat_per_package',
        ).dispatcherCompensationModel,
        DispatcherCompensationModel.flatPerPackage,
      );
      expect(
        PricingConfig.fromJson(
          Map<String, dynamic>.from(_fullJson())
            ..['dispatcher_compensation_model'] = 'shift_allowance',
        ).dispatcherCompensationModel,
        DispatcherCompensationModel.shiftAllowance,
      );
      expect(
        PricingConfig.fromJson(
          Map<String, dynamic>.from(_fullJson())
            ..['dispatcher_compensation_model'] = 'percent_of_fee',
        ).dispatcherCompensationModel,
        DispatcherCompensationModel.percentOfFee,
      );
    });

    test('falls back to flat_per_package for unknown model', () {
      final config = PricingConfig.fromJson(
        Map<String, dynamic>.from(_fullJson())
          ..['dispatcher_compensation_model'] = 'something_new',
      );
      expect(
        config.dispatcherCompensationModel,
        DispatcherCompensationModel.flatPerPackage,
      );
    });

    test('handles integer values returned for decimal columns', () {
      // Laravel sometimes serializes 500.00 as 500 (int) in some responses.
      final config = PricingConfig.fromJson(
        Map<String, dynamic>.from(_fullJson())
          ..['local_rate_per_km'] = 500
          ..['local_minimum_fee'] = 1000,
      );
      expect(config.localRatePerKm, 500.0);
      expect(config.localMinimumFee, 1000.0);
    });
  });

  group('PricingConfig round-trip', () {
    test('fromJson → toJson → fromJson preserves fields', () {
      final original = PricingConfig.fromJson(_fullJson());
      final roundtripped = PricingConfig.fromJson(original.toJson());

      expect(roundtripped.localRatePerKm, original.localRatePerKm);
      expect(
        roundtripped.dispatcherCompensationModel,
        original.dispatcherCompensationModel,
      );
      expect(roundtripped.rewardTier1Threshold, original.rewardTier1Threshold);
    });

    test('toJson serializes dispatcher model as snake_case', () {
      final config = PricingConfig.fromJson(_fullJson());
      expect(
        config.toJson()['dispatcher_compensation_model'],
        'flat_per_package',
      );
    });
  });

  group('PricingConfig helpers', () {
    test('riderEarningPercent and additionalOrderBonusPercent reflect fields',
        () {
      final config = PricingConfig.fromJson(_fullJson());
      expect(config.riderEarningPercent, 80.0);
      expect(config.additionalOrderBonusPercent, 10.0);
    });
  });
}