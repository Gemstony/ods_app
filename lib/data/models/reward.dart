import '../../core/utils/json_helpers.dart';

/// A distributor's progress toward the two ODS reward tiers.
///
/// Mirrors `App\Models\Reward` from Phase 2.5. One row per distributor.
///
/// Tier 1: 20 successful monthly services → 50% off eligible delivery.
/// Tier 2: 50 successful requests in the rolling window → free delivery.
///
/// The progress helpers take the threshold as a parameter — the model
/// doesn't know the current `PricingConfig`. Screens pass it from a
/// `pricingConfigProvider` (Phase 13) so the thresholds stay configurable.
class Reward {
  final int id;
  final int distributorId;
  final String currentMonth;
  final int monthlyCount;
  final bool tier1Available;
  final DateTime? tier1ReachedAt;
  final DateTime? tier1ExpiresAt;
  final int rollingCount;
  final DateTime? rollingWindowStart;
  final bool tier2Available;
  final DateTime? tier2ReachedAt;
  final DateTime? tier2ExpiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Reward({
    required this.id,
    required this.distributorId,
    required this.currentMonth,
    required this.monthlyCount,
    required this.tier1Available,
    required this.rollingCount,
    required this.tier2Available,
    this.tier1ReachedAt,
    this.tier1ExpiresAt,
    this.rollingWindowStart,
    this.tier2ReachedAt,
    this.tier2ExpiresAt,
    this.createdAt,
    this.updatedAt,
  });

  factory Reward.fromJson(Map<String, dynamic> json) {
    return Reward(
      id: asInt(json['id']),
      distributorId: asInt(json['distributor_id']),
      currentMonth: json['current_month'] as String,
      monthlyCount: asInt(json['monthly_count']),
      tier1Available: asBool(json['tier1_available']),
      tier1ReachedAt: parseDate(json['tier1_reached_at']),
      tier1ExpiresAt: parseDate(json['tier1_expires_at']),
      rollingCount: asInt(json['rolling_count']),
      rollingWindowStart: parseDate(json['rolling_window_start']),
      tier2Available: asBool(json['tier2_available']),
      tier2ReachedAt: parseDate(json['tier2_reached_at']),
      tier2ExpiresAt: parseDate(json['tier2_expires_at']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'distributor_id': distributorId,
        'current_month': currentMonth,
        'monthly_count': monthlyCount,
        'tier1_available': tier1Available,
        'tier1_reached_at': tier1ReachedAt?.toIso8601String(),
        'tier1_expires_at': tier1ExpiresAt?.toIso8601String(),
        'rolling_count': rollingCount,
        'rolling_window_start': rollingWindowStart?.toIso8601String(),
        'tier2_available': tier2Available,
        'tier2_reached_at': tier2ReachedAt?.toIso8601String(),
        'tier2_expires_at': tier2ExpiresAt?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  // ─── Availability (flag + not expired) ──────────────────
  bool get isTier1Usable =>
      tier1Available &&
      (tier1ExpiresAt == null || !tier1ExpiresAt!.isBefore(DateTime.now()));

  bool get isTier2Usable =>
      tier2Available &&
      (tier2ExpiresAt == null || !tier2ExpiresAt!.isBefore(DateTime.now()));

  bool get hasAnyAvailable => isTier1Usable || isTier2Usable;

  // ─── Progress helpers (threshold provided by caller) ────
  /// Fraction of the way to tier 1 (0.0–1.0, capped).
  double progressToTier1(int threshold) {
    if (threshold <= 0) return 0.0;
    return (monthlyCount / threshold).clamp(0.0, 1.0);
  }

  double progressToTier2(int threshold) {
    if (threshold <= 0) return 0.0;
    return (rollingCount / threshold).clamp(0.0, 1.0);
  }

  /// How many more successful deliveries are needed this month to unlock
  /// tier 1. Returns 0 if already at or past threshold.
  int remainingForTier1(int threshold) {
    if (monthlyCount >= threshold) return 0;
    return threshold - monthlyCount;
  }

  int remainingForTier2(int threshold) {
    if (rollingCount >= threshold) return 0;
    return threshold - rollingCount;
  }
}