import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/data/models/dashboard_kpis.dart';

Map<String, dynamic> _fullJson() => {
      'branches': {'total_active': 5},
      'users': {
        'total_active': 59,
        'pending_approvals': 3,
        'managers': 5,
        'riders': 12,
        'receivers': 8,
        'distributors': 34,
      },
      'deliveries': {
        'today_count': 12,
        'today_delivered': 8,
        'active_count': 15,
        'this_week_count': 87,
      },
      'revenue': {
        'today_tsh': 24000.00,
        'this_week_tsh': 156000.00,
        'this_month_tsh': 892000.00,
      },
      'payables': {
        'rider_earnings_pending_tsh': 30000.00,
        'dispatcher_earnings_pending_tsh': 15000.00,
        'transport_fare_owed_tsh': 45000.00,
      },
      'disputes': {'open_count': 2},
      'generated_at': '2026-11-01T10:30:00+00:00',
    };

void main() {
  group('DashboardKpis.fromJson', () {
    test('parses all nested KPIs', () {
      final kpis = DashboardKpis.fromJson(_fullJson());

      expect(kpis.branches.totalActive, 5);
      expect(kpis.users.totalActive, 59);
      expect(kpis.users.pendingApprovals, 3);
      expect(kpis.users.managers, 5);
      expect(kpis.users.riders, 12);
      expect(kpis.users.receivers, 8);
      expect(kpis.users.distributors, 34);
      expect(kpis.deliveries.todayCount, 12);
      expect(kpis.deliveries.todayDelivered, 8);
      expect(kpis.deliveries.activeCount, 15);
      expect(kpis.deliveries.thisWeekCount, 87);
      expect(kpis.revenue.todayTsh, 24000.0);
      expect(kpis.revenue.thisWeekTsh, 156000.0);
      expect(kpis.revenue.thisMonthTsh, 892000.0);
      expect(kpis.payables.riderEarningsPendingTsh, 30000.0);
      expect(kpis.payables.dispatcherEarningsPendingTsh, 15000.0);
      expect(kpis.payables.transportFareOwedTsh, 45000.0);
      expect(kpis.openDisputes, 2);
      expect(kpis.generatedAt, isNotNull);
    });

    test('handles missing nested objects gracefully', () {
      final kpis = DashboardKpis.fromJson({});

      expect(kpis.branches.totalActive, 0);
      expect(kpis.users.totalActive, 0);
      expect(kpis.users.pendingApprovals, 0);
      expect(kpis.deliveries.todayCount, 0);
      expect(kpis.revenue.todayTsh, 0);
      expect(kpis.payables.totalTsh, 0);
      expect(kpis.openDisputes, 0);
      expect(kpis.generatedAt, isNull);
    });

    test('accepts integer values for decimal fields', () {
      final json = _fullJson();
      json['revenue'] = {
        'today_tsh': 24000, // int instead of double
        'this_week_tsh': 156000,
        'this_month_tsh': 892000,
      };
      final kpis = DashboardKpis.fromJson(json);
      expect(kpis.revenue.todayTsh, 24000.0);
    });

    test('accepts string values for numeric fields', () {
      final json = _fullJson();
      json['branches'] = {'total_active': '5'};
      final kpis = DashboardKpis.fromJson(json);
      expect(kpis.branches.totalActive, 5);
    });
  });

  group('PayableKpis.totalTsh', () {
    test('sums all three payables components', () {
      const payables = PayableKpis(
        riderEarningsPendingTsh: 30000,
        dispatcherEarningsPendingTsh: 15000,
        transportFareOwedTsh: 45000,
      );
      expect(payables.totalTsh, 90000.0);
    });

    test('returns 0 for empty payables', () {
      const payables = PayableKpis(
        riderEarningsPendingTsh: 0,
        dispatcherEarningsPendingTsh: 0,
        transportFareOwedTsh: 0,
      );
      expect(payables.totalTsh, 0.0);
    });
  });

  group('DashboardKpis.empty', () {
    test('returns a valid zero-value instance', () {
      final kpis = DashboardKpis.empty();
      expect(kpis.branches.totalActive, 0);
      expect(kpis.users.totalActive, 0);
      expect(kpis.users.pendingApprovals, 0);
      expect(kpis.deliveries.todayCount, 0);
      expect(kpis.revenue.todayTsh, 0);
      expect(kpis.payables.totalTsh, 0);
      expect(kpis.openDisputes, 0);
      expect(kpis.generatedAt, isNull);
    });
  });
}