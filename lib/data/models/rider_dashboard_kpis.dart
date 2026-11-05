import '../../core/utils/json_helpers.dart';

/// Rider dashboard KPIs — shape of `GET /rider/dashboard`.
///
/// Mirrors `RiderDashboardController::index` (Phase 8.1):
///   {
///     "tasks":    { "available", "active", "delivered_today",
///                   "delivered_this_month", "total_delivered" },
///     "earnings": { "this_month_tsh", "pending_tsh" },
///     "generated_at": iso8601
///   }
class RiderDashboardKpis {
  final RiderTaskKpis tasks;
  final RiderEarningKpis earnings;
  final DateTime? generatedAt;

  const RiderDashboardKpis({
    required this.tasks,
    required this.earnings,
    this.generatedAt,
  });

  factory RiderDashboardKpis.fromJson(Map<String, dynamic> json) {
    return RiderDashboardKpis(
      tasks: RiderTaskKpis.fromJson(asMap(json['tasks']) ?? const {}),
      earnings: RiderEarningKpis.fromJson(asMap(json['earnings']) ?? const {}),
      generatedAt: parseDate(json['generated_at']),
    );
  }

  factory RiderDashboardKpis.empty() {
    return const RiderDashboardKpis(
      tasks: RiderTaskKpis.empty(),
      earnings: RiderEarningKpis.empty(),
    );
  }
}

class RiderTaskKpis {
  final int available;
  final int active;
  final int deliveredToday;
  final int deliveredThisMonth;
  final int totalDelivered;

  const RiderTaskKpis({
    required this.available,
    required this.active,
    required this.deliveredToday,
    required this.deliveredThisMonth,
    required this.totalDelivered,
  });

  factory RiderTaskKpis.fromJson(Map<String, dynamic> json) {
    return RiderTaskKpis(
      available: asInt(json['available'] ?? 0),
      active: asInt(json['active'] ?? 0),
      deliveredToday: asInt(json['delivered_today'] ?? 0),
      deliveredThisMonth: asInt(json['delivered_this_month'] ?? 0),
      totalDelivered: asInt(json['total_delivered'] ?? 0),
    );
  }

  const RiderTaskKpis.empty()
      : available = 0,
        active = 0,
        deliveredToday = 0,
        deliveredThisMonth = 0,
        totalDelivered = 0;
}

class RiderEarningKpis {
  final double thisMonthTsh;
  final double pendingTsh;

  const RiderEarningKpis({
    required this.thisMonthTsh,
    required this.pendingTsh,
  });

  factory RiderEarningKpis.fromJson(Map<String, dynamic> json) {
    return RiderEarningKpis(
      thisMonthTsh: asDouble(json['this_month_tsh'] ?? 0),
      pendingTsh: asDouble(json['pending_tsh'] ?? 0),
    );
  }

  const RiderEarningKpis.empty()
      : thisMonthTsh = 0,
        pendingTsh = 0;
}   