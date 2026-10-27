import '../../core/utils/json_helpers.dart';

/// Categories of compensation the ODS ledger tracks.
///
/// Mirrors `App\Models\Earning` from Phase 2.4. Snapshot from the ODS
/// document:
///   - rider_baseline       → 80% of the applicable delivery fee
///   - rider_bonus          → +10% for additional-order bonuses
///   - dispatcher_flat      → fixed amount per dispatched package
///   - dispatcher_shift     → shift allowance (NOT tied to a delivery)
///   - dispatcher_percent   → approved % of a defined fee
///   - adjustment           → manual correction (positive or negative)
///
/// NOTE: regional transport fares are NEVER represented as earnings.
/// They live exclusively on `DispatcherTicket.transportFare` (Phase 9 / 11).
enum EarningType {
  rider_baseline,
  rider_bonus,
  dispatcher_flat,
  dispatcher_shift,
  dispatcher_percent,
  adjustment;

  static EarningType fromString(String value) {
    return EarningType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => EarningType.adjustment,
    );
  }

  bool get isRider => this == rider_baseline || this == rider_bonus;
  bool get isDispatcher =>
      this == dispatcher_flat ||
      this == dispatcher_shift ||
      this == dispatcher_percent;
  bool get isAdjustment => this == adjustment;

  String get displayLabel => switch (this) {
        EarningType.rider_baseline => 'Rider baseline',
        EarningType.rider_bonus => 'Rider bonus',
        EarningType.dispatcher_flat => 'Dispatcher (per package)',
        EarningType.dispatcher_shift => 'Dispatcher (shift)',
        EarningType.dispatcher_percent => 'Dispatcher (%)',
        EarningType.adjustment => 'Adjustment',
      };
}

enum EarningStatus {
  pending,
  approved,
  paid,
  cancelled,
  unknown;

  static EarningStatus fromString(String value) {
    return EarningStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => EarningStatus.unknown,
    );
  }

  String get displayLabel => switch (this) {
        EarningStatus.pending => 'Pending',
        EarningStatus.approved => 'Approved',
        EarningStatus.paid => 'Paid',
        EarningStatus.cancelled => 'Cancelled',
        EarningStatus.unknown => 'Unknown',
      };
}

/// A single compensation event in the rider/dispatcher ledger.
///
/// **Signed amount**: negative values represent clawbacks and adjustments.
/// The display helpers preserve sign so the UI renders `-TZS 500` for a
/// negative amount and `TZS 1,200` for a positive one.
class Earning {
  final int id;
  final int userId;

  /// Null for `dispatcher_shift` (not tied to a single delivery).
  final int? deliveryId;

  final EarningType type;
  final double amount;
  final String currency;
  final EarningStatus status;
  final DateTime earnedAt;
  final int? approvedBy;
  final DateTime? approvedAt;
  final int? payoutId;
  final DateTime? paidAt;
  final String? notes;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Earning({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.currency,
    required this.status,
    required this.earnedAt,
    this.deliveryId,
    this.approvedBy,
    this.approvedAt,
    this.payoutId,
    this.paidAt,
    this.notes,
    this.metadata,
    this.createdAt,
    this.updatedAt,
  });

  factory Earning.fromJson(Map<String, dynamic> json) {
    return Earning(
      id: asInt(json['id']),
      userId: asInt(json['user_id']),
      deliveryId:
          json['delivery_id'] == null ? null : asInt(json['delivery_id']),
      type: EarningType.fromString(json['type'] as String),
      amount: asDouble(json['amount']),
      currency: json['currency'] as String? ?? 'TZS',
      status: EarningStatus.fromString(json['status'] as String),
      earnedAt: parseDate(json['earned_at']) ?? DateTime.now(),
      approvedBy:
          json['approved_by'] == null ? null : asInt(json['approved_by']),
      approvedAt: parseDate(json['approved_at']),
      payoutId: json['payout_id'] == null ? null : asInt(json['payout_id']),
      paidAt: parseDate(json['paid_at']),
      notes: json['notes'] as String?,
      metadata: asMap(json['metadata']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'delivery_id': deliveryId,
        'type': type.name,
        'amount': amount,
        'currency': currency,
        'status': status.name,
        'earned_at': earnedAt.toIso8601String(),
        'approved_by': approvedBy,
        'approved_at': approvedAt?.toIso8601String(),
        'payout_id': payoutId,
        'paid_at': paidAt?.toIso8601String(),
        'notes': notes,
        'metadata': metadata,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  // ─── State helpers ───────────────────────────────────────
  bool get isRiderEarning => type.isRider;
  bool get isDispatcherEarning => type.isDispatcher;
  bool get isAdjustment => type.isAdjustment;

  bool get isPending => status == EarningStatus.pending;
  bool get isApproved => status == EarningStatus.approved;
  bool get isPaid => status == EarningStatus.paid;

  /// Sign helpers — because negative adjustments are legitimate.
  bool get isPositive => amount > 0;
  bool get isNegative => amount < 0;

  // ─── Display ─────────────────────────────────────────────
  /// e.g. "TZS 1,200" or "-TZS 250"
  String get amountLabel {
    final sign = amount < 0 ? '-' : '';
    return '$sign$currency ${amount.abs().toStringAsFixed(0)}';
  }

  String get typeLabel => type.displayLabel;
  String get statusLabel => status.displayLabel;
}