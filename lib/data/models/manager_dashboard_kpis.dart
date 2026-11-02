import '../../core/utils/json_helpers.dart';

/// Manager dashboard KPIs — operational snapshot for one branch.
///
/// Complements `DashboardKpis` (Owner's platform-wide view) with a
/// narrower, manager-focused set of metrics. See
/// `GET /manager/dashboard` in Phase 6.2 backend.
class ManagerDashboardKpis {
  /// Null when the manager has no branch assigned.
  final ManagerBranchRef? branch;
  final ManagerStaffKpis staff;
  final ManagerDeliveryKpis deliveries;
  final ManagerRevenueKpis revenue;
  final DateTime? generatedAt;

  const ManagerDashboardKpis({
    required this.branch,
    required this.staff,
    required this.deliveries,
    required this.revenue,
    this.generatedAt,
  });

  factory ManagerDashboardKpis.fromJson(Map<String, dynamic> json) {
    final branchJson = asMap(json['branch']);
    return ManagerDashboardKpis(
      branch: branchJson == null
          ? null
          : ManagerBranchRef.fromJson(branchJson),
      staff: ManagerStaffKpis.fromJson(asMap(json['staff']) ?? const {}),
      deliveries:
          ManagerDeliveryKpis.fromJson(asMap(json['deliveries']) ?? const {}),
      revenue: ManagerRevenueKpis.fromJson(asMap(json['revenue']) ?? const {}),
      generatedAt: parseDate(json['generated_at']),
    );
  }

  factory ManagerDashboardKpis.empty() => const ManagerDashboardKpis(
        branch: null,
        staff: ManagerStaffKpis(totalActive: 0, receivers: 0, riders: 0),
        deliveries: ManagerDeliveryKpis(
          todayCount: 0,
          activeCount: 0,
          waitingPickup: 0,
          inTransit: 0,
          deliveredToday: 0,
        ),
        revenue: ManagerRevenueKpis(todayTsh: 0),
      );

  bool get hasBranch => branch != null;
}

class ManagerBranchRef {
  final int id;
  final String name;
  final String code;
  final String status;

  const ManagerBranchRef({
    required this.id,
    required this.name,
    required this.code,
    required this.status,
  });

  factory ManagerBranchRef.fromJson(Map<String, dynamic> json) =>
      ManagerBranchRef(
        id: asInt(json['id'] ?? 0),
        name: (json['name'] as String?) ?? '',
        code: (json['code'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'unknown',
      );

  bool get isActive => status == 'active';
}

class ManagerStaffKpis {
  final int totalActive;
  final int receivers;
  final int riders;

  const ManagerStaffKpis({
    required this.totalActive,
    required this.receivers,
    required this.riders,
  });

  factory ManagerStaffKpis.fromJson(Map<String, dynamic> json) =>
      ManagerStaffKpis(
        totalActive: asInt(json['total_active'] ?? 0),
        receivers: asInt(json['receivers'] ?? 0),
        riders: asInt(json['riders'] ?? 0),
      );
}

class ManagerDeliveryKpis {
  final int todayCount;
  final int activeCount;
  final int waitingPickup;
  final int inTransit;
  final int deliveredToday;

  const ManagerDeliveryKpis({
    required this.todayCount,
    required this.activeCount,
    required this.waitingPickup,
    required this.inTransit,
    required this.deliveredToday,
  });

  factory ManagerDeliveryKpis.fromJson(Map<String, dynamic> json) =>
      ManagerDeliveryKpis(
        todayCount: asInt(json['today_count'] ?? 0),
        activeCount: asInt(json['active_count'] ?? 0),
        waitingPickup: asInt(json['waiting_pickup'] ?? 0),
        inTransit: asInt(json['in_transit'] ?? 0),
        deliveredToday: asInt(json['delivered_today'] ?? 0),
      );
}

class ManagerRevenueKpis {
  final double todayTsh;
  const ManagerRevenueKpis({required this.todayTsh});

  factory ManagerRevenueKpis.fromJson(Map<String, dynamic> json) =>
      ManagerRevenueKpis(todayTsh: asDouble(json['today_tsh'] ?? 0));
}