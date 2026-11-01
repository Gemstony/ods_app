import '../../core/utils/json_helpers.dart';

/// Detailed financial overview for the Owner's Finance tab.
///
/// Complements `DashboardKpis` (5.4) with a deeper breakdown. See
/// `GET /owner/finance/summary` in Phase 5.8 backend.
class FinanceSummary {
  final RevenueSummary revenue;
  final PayablesSummary payables;
  final PayoutsSummary payouts;
  final TransportPaidSummary transportPaid;
  final ExpensesSummary expenses;
  final ReconciliationSummary reconciliation;
  final List<RecentPayout> recentPayouts;
  final DateTime? generatedAt;

  const FinanceSummary({
    required this.revenue,
    required this.payables,
    required this.payouts,
    required this.transportPaid,
    required this.expenses,
    required this.reconciliation,
    required this.recentPayouts,
    this.generatedAt,
  });

  factory FinanceSummary.fromJson(Map<String, dynamic> json) {
    final rawPayouts = json['recent_payouts'];
    return FinanceSummary(
      revenue: RevenueSummary.fromJson(asMap(json['revenue']) ?? const {}),
      payables: PayablesSummary.fromJson(asMap(json['payables']) ?? const {}),
      payouts: PayoutsSummary.fromJson(asMap(json['payouts']) ?? const {}),
      transportPaid: TransportPaidSummary.fromJson(
        asMap(json['transport_paid']) ?? const {},
      ),
      expenses: ExpensesSummary.fromJson(asMap(json['expenses']) ?? const {}),
      reconciliation: ReconciliationSummary.fromJson(
        asMap(json['reconciliation']) ?? const {},
      ),
      recentPayouts: rawPayouts is List
          ? rawPayouts
              .whereType<Map>()
              .map((j) => RecentPayout.fromJson(Map<String, dynamic>.from(j)))
              .toList(growable: false)
          : const [],
      generatedAt: parseDate(json['generated_at']),
    );
  }

  /// Convenience for tests + empty states.
  factory FinanceSummary.empty() => const FinanceSummary(
        revenue: RevenueSummary(
          todayTsh: 0, thisWeekTsh: 0, thisMonthTsh: 0, allTimeTsh: 0,
        ),
        payables: PayablesSummary(
          riderPendingTsh: 0, riderApprovedTsh: 0,
          dispatcherPendingTsh: 0, dispatcherApprovedTsh: 0,
          transportFareOwedTsh: 0,
        ),
        payouts: PayoutsSummary(
          thisMonthCount: 0, thisMonthTsh: 0,
          pendingCount: 0, pendingTsh: 0,
        ),
        transportPaid: TransportPaidSummary(thisMonthTsh: 0),
        expenses: ExpensesSummary(thisMonthTsh: 0, allTimeTsh: 0),
        reconciliation: ReconciliationSummary(
          revenueThisMonthTsh: 0,
          minusPayoutsThisMonthTsh: 0,
          minusTransportPaidThisMonthTsh: 0,
          minusExpensesThisMonthTsh: 0,
          operatingSurplusTsh: 0,
        ),
        recentPayouts: [],
      );
}

class RevenueSummary {
  final double todayTsh;
  final double thisWeekTsh;
  final double thisMonthTsh;
  final double allTimeTsh;

  const RevenueSummary({
    required this.todayTsh,
    required this.thisWeekTsh,
    required this.thisMonthTsh,
    required this.allTimeTsh,
  });

  factory RevenueSummary.fromJson(Map<String, dynamic> json) => RevenueSummary(
        todayTsh: asDouble(json['today_tsh'] ?? 0),
        thisWeekTsh: asDouble(json['this_week_tsh'] ?? 0),
        thisMonthTsh: asDouble(json['this_month_tsh'] ?? 0),
        allTimeTsh: asDouble(json['all_time_tsh'] ?? 0),
      );
}

class PayablesSummary {
  final double riderPendingTsh;
  final double riderApprovedTsh;
  final double dispatcherPendingTsh;
  final double dispatcherApprovedTsh;
  final double transportFareOwedTsh;

  const PayablesSummary({
    required this.riderPendingTsh,
    required this.riderApprovedTsh,
    required this.dispatcherPendingTsh,
    required this.dispatcherApprovedTsh,
    required this.transportFareOwedTsh,
  });

  factory PayablesSummary.fromJson(Map<String, dynamic> json) =>
      PayablesSummary(
        riderPendingTsh: asDouble(json['rider_pending_tsh'] ?? 0),
        riderApprovedTsh: asDouble(json['rider_approved_tsh'] ?? 0),
        dispatcherPendingTsh: asDouble(json['dispatcher_pending_tsh'] ?? 0),
        dispatcherApprovedTsh: asDouble(json['dispatcher_approved_tsh'] ?? 0),
        transportFareOwedTsh: asDouble(json['transport_fare_owed_tsh'] ?? 0),
      );

  /// Money ODS currently owes across all categories.
  double get totalTsh =>
      riderPendingTsh +
      riderApprovedTsh +
      dispatcherPendingTsh +
      dispatcherApprovedTsh +
      transportFareOwedTsh;

  /// Rider earnings owed (pending + approved, not yet paid out).
  double get totalRiderTsh => riderPendingTsh + riderApprovedTsh;

  /// Dispatcher earnings owed (pending + approved, not yet paid out).
  double get totalDispatcherTsh =>
      dispatcherPendingTsh + dispatcherApprovedTsh;
}

class PayoutsSummary {
  final int thisMonthCount;
  final double thisMonthTsh;
  final int pendingCount;
  final double pendingTsh;

  const PayoutsSummary({
    required this.thisMonthCount,
    required this.thisMonthTsh,
    required this.pendingCount,
    required this.pendingTsh,
  });

  factory PayoutsSummary.fromJson(Map<String, dynamic> json) => PayoutsSummary(
        thisMonthCount: asInt(json['this_month_count'] ?? 0),
        thisMonthTsh: asDouble(json['this_month_tsh'] ?? 0),
        pendingCount: asInt(json['pending_count'] ?? 0),
        pendingTsh: asDouble(json['pending_tsh'] ?? 0),
      );
}

class TransportPaidSummary {
  final double thisMonthTsh;
  const TransportPaidSummary({required this.thisMonthTsh});

  factory TransportPaidSummary.fromJson(Map<String, dynamic> json) =>
      TransportPaidSummary(thisMonthTsh: asDouble(json['this_month_tsh'] ?? 0));
}

class ExpensesSummary {
  final double thisMonthTsh;
  final double allTimeTsh;
  const ExpensesSummary({required this.thisMonthTsh, required this.allTimeTsh});

  factory ExpensesSummary.fromJson(Map<String, dynamic> json) => ExpensesSummary(
        thisMonthTsh: asDouble(json['this_month_tsh'] ?? 0),
        allTimeTsh: asDouble(json['all_time_tsh'] ?? 0),
      );
}

class ReconciliationSummary {
  final double revenueThisMonthTsh;
  final double minusPayoutsThisMonthTsh;
  final double minusTransportPaidThisMonthTsh;
  final double minusExpensesThisMonthTsh;
  final double operatingSurplusTsh;

  const ReconciliationSummary({
    required this.revenueThisMonthTsh,
    required this.minusPayoutsThisMonthTsh,
    required this.minusTransportPaidThisMonthTsh,
    required this.minusExpensesThisMonthTsh,
    required this.operatingSurplusTsh,
  });

  factory ReconciliationSummary.fromJson(Map<String, dynamic> json) =>
      ReconciliationSummary(
        revenueThisMonthTsh:
            asDouble(json['revenue_this_month_tsh'] ?? 0),
        minusPayoutsThisMonthTsh:
            asDouble(json['minus_payouts_this_month_tsh'] ?? 0),
        minusTransportPaidThisMonthTsh:
            asDouble(json['minus_transport_paid_this_month_tsh'] ?? 0),
        minusExpensesThisMonthTsh:
            asDouble(json['minus_expenses_this_month_tsh'] ?? 0),
        operatingSurplusTsh:
            asDouble(json['operating_surplus_tsh'] ?? 0),
      );

  bool get isPositive => operatingSurplusTsh >= 0;
}

class RecentPayout {
  final int id;
  final String userName;
  final double amount;
  final String currency;
  final String status;
  final String reference;
  final DateTime? requestedAt;
  final DateTime? processedAt;

  const RecentPayout({
    required this.id,
    required this.userName,
    required this.amount,
    required this.currency,
    required this.status,
    required this.reference,
    this.requestedAt,
    this.processedAt,
  });

  factory RecentPayout.fromJson(Map<String, dynamic> json) => RecentPayout(
        id: asInt(json['id'] ?? 0),
        userName: (json['user_name'] as String?) ?? 'Unknown',
        amount: asDouble(json['amount'] ?? 0),
        currency: (json['currency'] as String?) ?? 'TZS',
        status: (json['status'] as String?) ?? 'unknown',
        reference: (json['reference'] as String?) ?? '',
        requestedAt: parseDate(json['requested_at']),
        processedAt: parseDate(json['processed_at']),
      );
}