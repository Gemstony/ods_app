import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/data/models/reward.dart';

Map<String, dynamic> _freshJson() => {
      'id': 1,
      'distributor_id': 42,
      'current_month': '2026-10',
      'monthly_count': 0,
      'tier1_available': false,
      'tier1_reached_at': null,
      'tier1_expires_at': null,
      'rolling_count': 0,
      'rolling_window_start': '2026-09-24T00:00:00+00:00',
      'tier2_available': false,
      'tier2_reached_at': null,
      'tier2_expires_at': null,
      'created_at': '2026-09-24T00:00:00+00:00',
      'updated_at': '2026-10-24T07:00:00+00:00',
    };

Map<String, dynamic> _tier1AvailableJson() => {
      ..._freshJson(),
      'monthly_count': 20,
      'tier1_available': true,
      'tier1_reached_at': '2026-10-24T07:00:00+00:00',
      'tier1_expires_at': DateTime.now()
          .add(const Duration(days: 30))
          .toIso8601String(),
    };

void main() {
  group('Reward.fromJson', () {
    test('parses a fresh reward record', () {
      final r = Reward.fromJson(_freshJson());
      expect(r.id, 1);
      expect(r.distributorId, 42);
      expect(r.currentMonth, '2026-10');
      expect(r.monthlyCount, 0);
      expect(r.tier1Available, isFalse);
      expect(r.rollingCount, 0);
      expect(r.tier2Available, isFalse);
      expect(r.hasAnyAvailable, isFalse);
    });

    test('parses tier1 available', () {
      final r = Reward.fromJson(_tier1AvailableJson());
      expect(r.monthlyCount, 20);
      expect(r.tier1Available, isTrue);
      expect(r.tier1ReachedAt, isNotNull);
      expect(r.tier1ExpiresAt, isNotNull);
      expect(r.isTier1Usable, isTrue);
      expect(r.hasAnyAvailable, isTrue);
    });

    test('parses both tiers available', () {
      final r = Reward.fromJson({
        ..._tier1AvailableJson(),
        'rolling_count': 50,
        'tier2_available': true,
        'tier2_reached_at': '2026-10-24T07:00:00+00:00',
        'tier2_expires_at':
            DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      });
      expect(r.isTier1Usable, isTrue);
      expect(r.isTier2Usable, isTrue);
      expect(r.hasAnyAvailable, isTrue);
    });
  });

  group('Reward tier usability', () {
    test('expired tier1 is not usable', () {
      final r = Reward.fromJson({
        ..._tier1AvailableJson(),
        'tier1_expires_at':
            DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      });
      expect(r.tier1Available, isTrue);
      expect(r.isTier1Usable, isFalse);
    });

    test('null tier1_expires_at means never expires', () {
      final r = Reward.fromJson({
        ..._freshJson(),
        'tier1_available': true,
        'tier1_expires_at': null,
      });
      expect(r.isTier1Usable, isTrue);
    });

    test('tier2 usability follows the same rules', () {
      final r = Reward.fromJson({
        ..._freshJson(),
        'rolling_count': 50,
        'tier2_available': true,
        'tier2_reached_at': '2026-10-24T07:00:00+00:00',
        'tier2_expires_at':
            DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      });
      expect(r.isTier2Usable, isTrue);
    });
  });

  group('Reward progress helpers', () {
    test('progressToTier1 is 0 when monthly count is 0', () {
      final r = Reward.fromJson(_freshJson());
      expect(r.progressToTier1(20), 0.0);
    });

    test('progressToTier1 is 1.0 when at threshold', () {
      final r = Reward.fromJson(_freshJson()..['monthly_count'] = 20);
      expect(r.progressToTier1(20), 1.0);
    });

    test('progressToTier1 is clamped at 1.0 for over threshold', () {
      final r = Reward.fromJson(_freshJson()..['monthly_count'] = 35);
      expect(r.progressToTier1(20), 1.0);
    });

    test('progressToTier1 scales correctly mid-progress', () {
      final r = Reward.fromJson(_freshJson()..['monthly_count'] = 10);
      expect(r.progressToTier1(20), 0.5);
    });

    test('progressToTier1 returns 0.0 for invalid threshold', () {
      final r = Reward.fromJson(_freshJson()..['monthly_count'] = 10);
      expect(r.progressToTier1(0), 0.0);
      expect(r.progressToTier1(-1), 0.0);
    });

    test('remainingForTier1 counts correctly', () {
      expect(
          Reward.fromJson(_freshJson()..['monthly_count'] = 0)
              .remainingForTier1(20),
          20);
      expect(
          Reward.fromJson(_freshJson()..['monthly_count'] = 15)
              .remainingForTier1(20),
          5);
      expect(
          Reward.fromJson(_freshJson()..['monthly_count'] = 20)
              .remainingForTier1(20),
          0);
      expect(
          Reward.fromJson(_freshJson()..['monthly_count'] = 25)
              .remainingForTier1(20),
          0);
    });

    test('remainingForTier2 works the same way', () {
      expect(
          Reward.fromJson(_freshJson()..['rolling_count'] = 30)
              .remainingForTier2(50),
          20);
    });
  });

  group('Reward round-trip', () {
    test('fromJson → toJson → fromJson preserves all fields', () {
      final original = Reward.fromJson(_tier1AvailableJson());
      final roundtripped = Reward.fromJson(original.toJson());
      expect(roundtripped.id, original.id);
      expect(roundtripped.distributorId, original.distributorId);
      expect(roundtripped.currentMonth, original.currentMonth);
      expect(roundtripped.monthlyCount, original.monthlyCount);
      expect(roundtripped.tier1Available, original.tier1Available);
      expect(roundtripped.rollingCount, original.rollingCount);
    });
  });

  group('Reward defensive parsing', () {
    test('accepts boolean as 1/0', () {
      final r = Reward.fromJson(_freshJson()
        ..['tier1_available'] = 1
        ..['tier2_available'] = 0);
      expect(r.tier1Available, isTrue);
      expect(r.tier2Available, isFalse);
    });

    test('accepts numeric strings for counts', () {
      final r = Reward.fromJson(_freshJson()
        ..['monthly_count'] = '15'
        ..['rolling_count'] = '30');
      expect(r.monthlyCount, 15);
      expect(r.rollingCount, 30);
    });
  });
}