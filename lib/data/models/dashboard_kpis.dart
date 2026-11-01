import '../../core/utils/json_helpers.dart';

/// All KPIs shown on the Owner's Home tab.
///
/// Nested structure mirrors the backend response 1:1. Numeric fields use
/// `asInt` / `asDouble` for defensive parsing (JSON can deliver `500` or
/// `500.0` depending on column type).
class DashboardKpis {
  final BranchKpis branches;
  final UserKpis users;
  final DeliveryKpis deliveries;
  final RevenueKpis revenue;
  final PayableKpis payables;
  final int openDisputes;
  final DateTime? generatedAt;

  const DashboardKpis({
    required this.branches,
    required this.users,
    required this.deliveries,
    required this.revenue,
    required this.payables,
    required this.openDisputes,
    this.generatedAt,
  });

  factory DashboardKpis.fromJson(Map<String, dynamic> json) {
    return DashboardKpis(
      branches: BranchKpis.fromJson(
        asMap(json['branches']) ?? const {},
      ),
      users: UserKpis.fromJson(
        asMap(json['users']) ?? const {},
      ),
      deliveries: DeliveryKpis.fromJson(
        asMap(json['deliveries']) ?? const {},
      ),
      revenue: RevenueKpis.fromJson(
        asMap(json['revenue']) ?? const {},
      ),
      payables: PayableKpis.fromJson(
        asMap(json['payables']) ?? const {},
      ),
      openDisputes: asInt(asMap(json['disputes'])?['open_count'] ?? 0),
      generatedAt: parseDate(json['generated_at']),
    );
  }

  /// Convenience factory for tests and fakes — a fully-populated but
  /// all-zero instance. Useful wherever a valid `DashboardKpis` is needed
  /// without real data.
  factory DashboardKpis.empty() => const DashboardKpis(
        branches: BranchKpis(totalActive: 0),
        users: UserKpis(
          totalActive: 0,
          pendingApprovals: 0,
          managers: 0,
          riders: 0,
          receivers: 0,
          distributors: 0,
        ),
        deliveries: DeliveryKpis(
          todayCount: 0,
          todayDelivered: 0,
          activeCount: 0,
          thisWeekCount: 0,
        ),
        revenue: RevenueKpis(
          todayTsh: 0,
          thisWeekTsh: 0,
          thisMonthTsh: 0,
        ),
        payables: PayableKpis(
          riderEarningsPendingTsh: 0,
          dispatcherEarningsPendingTsh: 0,
          transportFareOwedTsh: 0,
        ),
        openDisputes: 0,
      );
}

class BranchKpis {
  final int totalActive;
  const BranchKpis({required this.totalActive});

  factory BranchKpis.fromJson(Map<String, dynamic> json) =>
      BranchKpis(totalActive: asInt(json['total_active'] ?? 0));
}

class UserKpis {
  final int totalActive;
  final int pendingApprovals;
  final int managers;
  final int riders;
  final int receivers;
  final int distributors;

  const UserKpis({
    required this.totalActive,
    required this.pendingApprovals,
    required this.managers,
    required this.riders,
    required this.receivers,
    required this.distributors,
  });

  factory UserKpis.fromJson(Map<String, dynamic> json) => UserKpis(
        totalActive: asInt(json['total_active'] ?? 0),
        pendingApprovals: asInt(json['pending_approvals'] ?? 0),
        managers: asInt(json['managers'] ?? 0),
        riders: asInt(json['riders'] ?? 0),
        receivers: asInt(json['receivers'] ?? 0),
        distributors: asInt(json['distributors'] ?? 0),
      );
}

class DeliveryKpis {
  final int todayCount;
  final int todayDelivered;
  final int activeCount;
  final int thisWeekCount;

  const DeliveryKpis({
    required this.todayCount,
    required this.todayDelivered,
    required this.activeCount,
    required this.thisWeekCount,
  });

  factory DeliveryKpis.fromJson(Map<String, dynamic> json) => DeliveryKpis(
        todayCount: asInt(json['today_count'] ?? 0),
        todayDelivered: asInt(json['today_delivered'] ?? 0),
        activeCount: asInt(json['active_count'] ?? 0),
        thisWeekCount: asInt(json['this_week_count'] ?? 0),
      );
}

class RevenueKpis {
  final double todayTsh;
  final double thisWeekTsh;
  final double thisMonthTsh;

  const RevenueKpis({
    required this.todayTsh,
    required this.thisWeekTsh,
    required this.thisMonthTsh,
  });

  factory RevenueKpis.fromJson(Map<String, dynamic> json) => RevenueKpis(
        todayTsh: asDouble(json['today_tsh'] ?? 0),
        thisWeekTsh: asDouble(json['this_week_tsh'] ?? 0),
        thisMonthTsh: asDouble(json['this_month_tsh'] ?? 0),
      );
}

class PayableKpis {
  final double riderEarningsPendingTsh;
  final double dispatcherEarningsPendingTsh;
  final double transportFareOwedTsh;

  const PayableKpis({
    required this.riderEarningsPendingTsh,
    required this.dispatcherEarningsPendingTsh,
    required this.transportFareOwedTsh,
  });

  factory PayableKpis.fromJson(Map<String, dynamic> json) => PayableKpis(
        riderEarningsPendingTsh:
            asDouble(json['rider_earnings_pending_tsh'] ?? 0),
        dispatcherEarningsPendingTsh:
            asDouble(json['dispatcher_earnings_pending_tsh'] ?? 0),
        transportFareOwedTsh: asDouble(json['transport_fare_owed_tsh'] ?? 0),
      );

  /// Total money currently owed to riders, dispatchers, and transport
  /// providers. The "you owe" number an Owner cares about.
  double get totalTsh =>
      riderEarningsPendingTsh +
      dispatcherEarningsPendingTsh +
      transportFareOwedTsh;
}