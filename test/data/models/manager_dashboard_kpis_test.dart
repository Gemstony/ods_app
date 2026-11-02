import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/data/models/manager_dashboard_kpis.dart';

Map<String, dynamic> _fullJson() => {
      'branch': {
        'id': 5,
        'name': 'Kariakoo Branch',
        'code': 'KRK-01',
        'status': 'active',
      },
      'staff': {
        'total_active': 5,
        'receivers': 2,
        'riders': 3,
      },
      'deliveries': {
        'today_count': 12,
        'active_count': 3,
        'waiting_pickup': 2,
        'in_transit': 1,
        'delivered_today': 8,
      },
      'revenue': {'today_tsh': 24000.0},
      'generated_at': '2026-11-04T14:00:00+00:00',
    };

void main() {
  group('ManagerDashboardKpis.fromJson', () {
    test('parses all fields', () {
      final k = ManagerDashboardKpis.fromJson(_fullJson());
      expect(k.branch, isNotNull);
      expect(k.branch!.id, 5);
      expect(k.branch!.name, 'Kariakoo Branch');
      expect(k.branch!.code, 'KRK-01');
      expect(k.branch!.isActive, isTrue);
      expect(k.staff.totalActive, 5);
      expect(k.staff.receivers, 2);
      expect(k.staff.riders, 3);
      expect(k.deliveries.todayCount, 12);
      expect(k.deliveries.activeCount, 3);
      expect(k.deliveries.waitingPickup, 2);
      expect(k.deliveries.inTransit, 1);
      expect(k.deliveries.deliveredToday, 8);
      expect(k.revenue.todayTsh, 24000.0);
      expect(k.generatedAt, isNotNull);
    });

    test('handles null branch', () {
      final k = ManagerDashboardKpis.fromJson({
        'branch': null,
        'staff': {'total_active': 0},
        'deliveries': {},
        'revenue': {'today_tsh': 0},
      });
      expect(k.branch, isNull);
      expect(k.hasBranch, isFalse);
    });

    test('handles missing nested objects', () {
      final k = ManagerDashboardKpis.fromJson({});
      expect(k.branch, isNull);
      expect(k.staff.totalActive, 0);
      expect(k.deliveries.waitingPickup, 0);
      expect(k.revenue.todayTsh, 0);
      expect(k.generatedAt, isNull);
    });

    test('accepts integer values for decimal fields', () {
      final json = _fullJson();
      json['revenue'] = {'today_tsh': 24000};
      final k = ManagerDashboardKpis.fromJson(json);
      expect(k.revenue.todayTsh, 24000.0);
    });

    test('inactive branch sets isActive to false', () {
      final json = _fullJson();
      json['branch'] = {
        'id': 5,
        'name': 'Branch',
        'code': 'B-1',
        'status': 'inactive',
      };
      final k = ManagerDashboardKpis.fromJson(json);
      expect(k.branch!.isActive, isFalse);
    });
  });

  group('ManagerDashboardKpis.empty', () {
    test('returns valid zero-value with no branch', () {
      final k = ManagerDashboardKpis.empty();
      expect(k.branch, isNull);
      expect(k.hasBranch, isFalse);
      expect(k.staff.totalActive, 0);
      expect(k.deliveries.todayCount, 0);
      expect(k.revenue.todayTsh, 0);
    });
  });
}