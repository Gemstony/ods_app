import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/data/models/finance_summary.dart';

Map<String, dynamic> _fullJson() => {
      'revenue': {
        'today_tsh': 24000.0,
        'this_week_tsh': 156000.0,
        'this_month_tsh': 892000.0,
        'all_time_tsh': 5000000.0,
      },
      'payables': {
        'rider_pending_tsh': 30000.0,
        'rider_approved_tsh': 15000.0,
        'dispatcher_pending_tsh': 8000.0,
        'dispatcher_approved_tsh': 2000.0,
        'transport_fare_owed_tsh': 45000.0,
      },
      'payouts': {
        'this_month_count': 12,
        'this_month_tsh': 250000.0,
        'pending_count': 3,
        'pending_tsh': 45000.0,
      },
      'transport_paid': {'this_month_tsh': 35000.0},
      'expenses': {'this_month_tsh': 75000.0, 'all_time_tsh': 300000.0},
      'reconciliation': {
        'revenue_this_month_tsh': 892000.0,
        'minus_payouts_this_month_tsh': 250000.0,
        'minus_transport_paid_this_month_tsh': 35000.0,
        'minus_expenses_this_month_tsh': 75000.0,
        'operating_surplus_tsh': 532000.0,
      },
      'recent_payouts': [
        {
          'id': 1,
          'user_name': 'Jane Rider',
          'amount': 50000.0,
          'currency': 'TZS',
          'status': 'paid',
          'reference': 'PO-20261101-ABC',
          'requested_at': '2026-11-01T09:00:00+00:00',
          'processed_at': '2026-11-01T10:00:00+00:00',
        },
      ],
      'generated_at': '2026-11-04T14:00:00+00:00',
    };

void main() {
  group('FinanceSummary.fromJson', () {
    test('parses all nested summaries', () {
      final s = FinanceSummary.fromJson(_fullJson());
      expect(s.revenue.todayTsh, 24000);
      expect(s.revenue.thisWeekTsh, 156000);
      expect(s.revenue.thisMonthTsh, 892000);
      expect(s.revenue.allTimeTsh, 5000000);
      expect(s.payables.riderPendingTsh, 30000);
      expect(s.payables.riderApprovedTsh, 15000);
      expect(s.payables.dispatcherPendingTsh, 8000);
      expect(s.payables.dispatcherApprovedTsh, 2000);
      expect(s.payables.transportFareOwedTsh, 45000);
      expect(s.payouts.thisMonthCount, 12);
      expect(s.payouts.thisMonthTsh, 250000);
      expect(s.payouts.pendingCount, 3);
      expect(s.payouts.pendingTsh, 45000);
      expect(s.transportPaid.thisMonthTsh, 35000);
      expect(s.expenses.thisMonthTsh, 75000);
      expect(s.expenses.allTimeTsh, 300000);
      expect(s.reconciliation.operatingSurplusTsh, 532000);
      expect(s.recentPayouts.length, 1);
      expect(s.recentPayouts.first.userName, 'Jane Rider');
      expect(s.generatedAt, isNotNull);
    });

    test('handles missing nested objects', () {
      final s = FinanceSummary.fromJson({});
      expect(s.revenue.todayTsh, 0);
      expect(s.payables.riderPendingTsh, 0);
      expect(s.payouts.thisMonthCount, 0);
      expect(s.reconciliation.operatingSurplusTsh, 0);
      expect(s.recentPayouts, isEmpty);
      expect(s.generatedAt, isNull);
    });

    test('accepts integer values for decimal fields', () {
      final json = _fullJson();
      json['revenue'] = {
        'today_tsh': 24000,
        'this_week_tsh': 156000,
        'this_month_tsh': 892000,
        'all_time_tsh': 5000000,
      };
      final s = FinanceSummary.fromJson(json);
      expect(s.revenue.todayTsh, 24000.0);
    });

    test('parses negative operating surplus', () {
      final json = _fullJson();
      json['reconciliation'] = {
        'revenue_this_month_tsh': 5000.0,
        'minus_payouts_this_month_tsh': 20000.0,
        'minus_transport_paid_this_month_tsh': 0.0,
        'minus_expenses_this_month_tsh': 0.0,
        'operating_surplus_tsh': -15000.0,
      };
      final s = FinanceSummary.fromJson(json);
      expect(s.reconciliation.operatingSurplusTsh, -15000);
      expect(s.reconciliation.isPositive, isFalse);
    });

    test('empty recent_payouts array parses as []', () {
      final json = _fullJson();
      json['recent_payouts'] = <Map<String, dynamic>>[];
      final s = FinanceSummary.fromJson(json);
      expect(s.recentPayouts, isEmpty);
    });
  });

  group('PayablesSummary totals', () {
    test('totalTsh sums all five components', () {
      const p = PayablesSummary(
        riderPendingTsh: 30000,
        riderApprovedTsh: 15000,
        dispatcherPendingTsh: 8000,
        dispatcherApprovedTsh: 2000,
        transportFareOwedTsh: 45000,
      );
      expect(p.totalTsh, 100000);
    });

    test('totalRiderTsh and totalDispatcherTsh', () {
      const p = PayablesSummary(
        riderPendingTsh: 30000,
        riderApprovedTsh: 15000,
        dispatcherPendingTsh: 8000,
        dispatcherApprovedTsh: 2000,
        transportFareOwedTsh: 45000,
      );
      expect(p.totalRiderTsh, 45000);
      expect(p.totalDispatcherTsh, 10000);
    });

    test('all-zero sums to zero', () {
      const p = PayablesSummary(
        riderPendingTsh: 0,
        riderApprovedTsh: 0,
        dispatcherPendingTsh: 0,
        dispatcherApprovedTsh: 0,
        transportFareOwedTsh: 0,
      );
      expect(p.totalTsh, 0);
    });
  });

  group('FinanceSummary.empty', () {
    test('returns a valid zero-value summary', () {
      final s = FinanceSummary.empty();
      expect(s.revenue.todayTsh, 0);
      expect(s.payables.totalTsh, 0);
      expect(s.payouts.thisMonthCount, 0);
      expect(s.reconciliation.isPositive, isTrue); // 0 is >= 0
      expect(s.recentPayouts, isEmpty);
    });
  });

  group('RecentPayout.fromJson', () {
    test('parses all fields', () {
      final p = RecentPayout.fromJson({
        'id': 1,
        'user_name': 'Jane',
        'amount': 50000.0,
        'currency': 'TZS',
        'status': 'paid',
        'reference': 'PO-20261101-ABC',
        'requested_at': '2026-11-01T09:00:00+00:00',
        'processed_at': '2026-11-01T10:00:00+00:00',
      });
      expect(p.id, 1);
      expect(p.userName, 'Jane');
      expect(p.amount, 50000);
      expect(p.status, 'paid');
      expect(p.reference, 'PO-20261101-ABC');
      expect(p.requestedAt, isNotNull);
      expect(p.processedAt, isNotNull);
    });

    test('handles missing optional timestamps', () {
      final p = RecentPayout.fromJson({
        'id': 1,
        'user_name': 'Jane',
        'amount': 50000.0,
        'currency': 'TZS',
        'status': 'pending',
        'reference': 'PO-1',
      });
      expect(p.requestedAt, isNull);
      expect(p.processedAt, isNull);
    });
  });
}