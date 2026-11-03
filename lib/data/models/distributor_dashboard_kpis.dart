import '../../core/utils/json_helpers.dart';
import 'delivery.dart';
import 'reward.dart';

/// Distributor dashboard KPIs — the customer's own-account snapshot.
///
/// Complements `DashboardKpis` (Owner, 5.4) and `ManagerDashboardKpis`
/// (Manager, 6.2) with a Distributor-specific view: their own delivery
/// counts, spend, rewards progress, and recent activity.
class DistributorDashboardKpis {
  final DistributorDeliveryKpis deliveries;
  final DistributorRevenueKpis revenue;
  final DistributorRewardKpis rewards;
  final List<Delivery> recentDeliveries;
  final DateTime? generatedAt;

  const DistributorDashboardKpis({
    required this.deliveries,
    required this.revenue,
    required this.rewards,
    required this.recentDeliveries,
    this.generatedAt,
  });

  factory DistributorDashboardKpis.fromJson(Map<String, dynamic> json) {
    final rawRewards = asMap(json['rewards']) ?? const {};
    final rawRecent = json['recent_deliveries'];

    return DistributorDashboardKpis(
      deliveries: DistributorDeliveryKpis.fromJson(
        asMap(json['deliveries']) ?? const {},
      ),
      revenue: DistributorRevenueKpis.fromJson(
        asMap(json['revenue']) ?? const {},
      ),
      rewards: DistributorRewardKpis.fromJson(rawRewards),
      recentDeliveries: rawRecent is List
          ? rawRecent
              .whereType<Map>()
              .map((j) => Delivery.fromJson(Map<String, dynamic>.from(j)))
              .toList(growable: false)
          : const [],
      generatedAt: parseDate(json['generated_at']),
    );
  }

  factory DistributorDashboardKpis.empty() {
    return DistributorDashboardKpis(
      deliveries: const DistributorDeliveryKpis(
        activeCount: 0,
        awaitingPaymentCount: 0,
        deliveredThisMonth: 0,
        totalThisMonth: 0,
      ),
      revenue: const DistributorRevenueKpis(spentThisMonthTsh: 0),
      rewards: DistributorRewardKpis.empty(),
      recentDeliveries: const [],
    );
  }
}

class DistributorDeliveryKpis {
  final int activeCount;
  final int awaitingPaymentCount;
  final int deliveredThisMonth;
  final int totalThisMonth;

  const DistributorDeliveryKpis({
    required this.activeCount,
    required this.awaitingPaymentCount,
    required this.deliveredThisMonth,
    required this.totalThisMonth,
  });

  factory DistributorDeliveryKpis.fromJson(Map<String, dynamic> json) =>
      DistributorDeliveryKpis(
        activeCount: asInt(json['active_count'] ?? 0),
        awaitingPaymentCount: asInt(json['awaiting_payment_count'] ?? 0),
        deliveredThisMonth: asInt(json['delivered_this_month'] ?? 0),
        totalThisMonth: asInt(json['total_this_month'] ?? 0),
      );
}

class DistributorRevenueKpis {
  final double spentThisMonthTsh;
  const DistributorRevenueKpis({required this.spentThisMonthTsh});

  factory DistributorRevenueKpis.fromJson(Map<String, dynamic> json) =>
      DistributorRevenueKpis(
        spentThisMonthTsh: asDouble(json['spent_this_month_tsh'] ?? 0),
      );
}

/// Rewards progress + thresholds, combined for UI consumption.
///
/// Wraps the existing [Reward] model (parsed from `rewards.progress`)
/// alongside the current `PricingConfig` thresholds (`rewards.thresholds`).
/// This lets the existing `RewardProgressCard` (4.7) render unchanged.
class DistributorRewardKpis {
  final Reward progress;
  final int tier1Threshold;
  final int tier2Threshold;
  final double tier1DiscountPercent;

  const DistributorRewardKpis({
    required this.progress,
    required this.tier1Threshold,
    required this.tier2Threshold,
    required this.tier1DiscountPercent,
  });

  factory DistributorRewardKpis.fromJson(Map<String, dynamic> json) {
    final rawProgress = asMap(json['progress']);
    final rawThresholds = asMap(json['thresholds']) ?? const {};

    // Use empty defaults when the `progress` map is missing entirely
    // (e.g., a malformed dashboard response). `Reward.fromJson({})`
    // would throw on required fields like `id` / `current_month`.
    final Reward progress;
    if (rawProgress == null || rawProgress.isEmpty) {
      progress = const Reward(
        id: 0,
        distributorId: 0,
        currentMonth: '',
        monthlyCount: 0,
        tier1Available: false,
        rollingCount: 0,
        tier2Available: false,
      );
    } else {
      progress = Reward.fromJson(Map<String, dynamic>.from(rawProgress));
    }

    return DistributorRewardKpis(
      progress: progress,
      tier1Threshold: asInt(rawThresholds['tier1'] ?? 20),
      tier2Threshold: asInt(rawThresholds['tier2'] ?? 50),
      tier1DiscountPercent: asDouble(
        rawThresholds['tier1_discount_percent'] ?? 50,
      ),
    );
  }

  factory DistributorRewardKpis.empty() {
    return const DistributorRewardKpis(
      progress: Reward(
        id: 0,
        distributorId: 0,
        currentMonth: '',
        monthlyCount: 0,
        tier1Available: false,
        rollingCount: 0,
        tier2Available: false,
      ),
      tier1Threshold: 20,
      tier2Threshold: 50,
      tier1DiscountPercent: 50,
    );
  }

  bool get hasAnyAvailable =>
      progress.isTier1Usable || progress.isTier2Usable;
}