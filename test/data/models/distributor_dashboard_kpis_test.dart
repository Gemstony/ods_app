import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/data/models/distributor_dashboard_kpis.dart';

Map<String, dynamic> _fullJson() => {
      'deliveries': {
        'active_count': 3,
        'awaiting_payment_count': 1,
        'delivered_this_month': 5,
        'total_this_month': 9,
      },
      'revenue': {'spent_this_month_tsh': 15000.0},
      'rewards': {
        'progress': {
          'id': 1,
          'distributor_id': 42,
          'current_month': '2026-11',
          'monthly_count': 5,
          'tier1_available': false,
          'tier1_reached_at': null,
          'tier1_expires_at': null,
          'rolling_count': 45,
          'rolling_window_start': '2026-10-04T00:00:00+00:00',
          'tier2_available': false,
          'tier2_reached_at': null,
          'tier2_expires_at': null,
        },
        'thresholds': {
          'tier1': 20,
          'tier2': 50,
          'tier1_discount_percent': 50.0,
        },
      },
      'recent_deliveries': <Map<String, dynamic>>[],
      'generated_at': '2026-11-04T14:00:00+00:00',
    };

void main() {
  group('DistributorDashboardKpis.fromJson', () {
    test('parses all fields', () {
      final k = DistributorDashboardKpis.fromJson(_fullJson());
      expect(k.deliveries.activeCount, 3);
      expect(k.deliveries.awaitingPaymentCount, 1);
      expect(k.deliveries.deliveredThisMonth, 5);
      expect(k.deliveries.totalThisMonth, 9);
      expect(k.revenue.spentThisMonthTsh, 15000.0);
      expect(k.rewards.progress.monthlyCount, 5);
      expect(k.rewards.progress.rollingCount, 45);
      expect(k.rewards.tier1Threshold, 20);
      expect(k.rewards.tier2Threshold, 50);
      expect(k.rewards.tier1DiscountPercent, 50.0);
      expect(k.recentDeliveries, isEmpty);
      expect(k.generatedAt, isNotNull);
    });

    test('handles missing nested objects', () {
      final k = DistributorDashboardKpis.fromJson({});
      expect(k.deliveries.activeCount, 0);
      expect(k.revenue.spentThisMonthTsh, 0);
      expect(k.rewards.tier1Threshold, 20);
      expect(k.recentDeliveries, isEmpty);
    });

    test('accepts integer values for decimal fields', () {
      final json = _fullJson();
      json['revenue'] = {'spent_this_month_tsh': 15000};
      final k = DistributorDashboardKpis.fromJson(json);
      expect(k.revenue.spentThisMonthTsh, 15000.0);
    });

    test('rewards hasAnyAvailable returns true when tier is usable', () {
      final json = _fullJson();
      final rewards = json['rewards'] as Map<String, dynamic>;
      final progress = rewards['progress'] as Map<String, dynamic>;
      progress['tier1_available'] = true;
      progress['tier1_expires_at'] =
          DateTime.now().add(const Duration(days: 30)).toIso8601String();

      final k = DistributorDashboardKpis.fromJson(json);
      expect(k.rewards.hasAnyAvailable, isTrue);
    });
  });

  group('DistributorDashboardKpis.empty', () {
    test('returns valid zeroed instance', () {
      final k = DistributorDashboardKpis.empty();
      expect(k.deliveries.activeCount, 0);
      expect(k.revenue.spentThisMonthTsh, 0);
      expect(k.rewards.tier1Threshold, 20);
      expect(k.recentDeliveries, isEmpty);
    });
  });
} 