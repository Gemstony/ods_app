import '../../core/utils/json_helpers.dart';

/// Status of a payout batch (money leaving ODS).
///
/// Mirrors `App\Models\Payout` from Phase 2. `paid` and `cancelled` are
/// terminal; `pending` and `processing` are in-flight.
enum PayoutStatus {
  pending,
  processing,
  paid,
  failed,
  cancelled,
  unknown;

  static PayoutStatus fromString(String value) {
    return PayoutStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => PayoutStatus.unknown,
    );
  }

  bool get isPending => this == pending || this == processing;
  bool get isPaid => this == paid;
  bool get isFailed => this == failed;
  bool get isTerminal =>
      this == paid || this == failed || this == cancelled;

  String get displayLabel => switch (this) {
        PayoutStatus.pending => 'Pending',
        PayoutStatus.processing => 'Processing',
        PayoutStatus.paid => 'Paid',
        PayoutStatus.failed => 'Failed',
        PayoutStatus.cancelled => 'Cancelled',
        PayoutStatus.unknown => 'Unknown',
      };
}

/// How the payout was disbursed.
enum PayoutMethod {
  mobile,
  bank,
  cash;

  static PayoutMethod fromString(String value) {
    return PayoutMethod.values.firstWhere(
      (m) => m.name == value,
      orElse: () => PayoutMethod.mobile,
    );
  }

  String get displayLabel => switch (this) {
        PayoutMethod.mobile => 'Mobile money',
        PayoutMethod.bank => 'Bank transfer',
        PayoutMethod.cash => 'Cash',
      };
}

/// A payout batch — earnings grouped and paid to a user.
///
/// The backend's `PayoutResource` (Phase 11.4) also includes nested
/// `user`, `processed_by`, and `earnings`. Those are parsed at the
/// wrapper level (`OwnerPayoutEntry` in `ledger_entries.dart`), not here
/// — this model is the pure payout row.
class Payout {
  final int id;
  final int userId;
  final double amount;
  final String currency;
  final PayoutMethod method;
  final String? reference;
  final PayoutStatus status;
  final DateTime? requestedAt;
  final DateTime? processedAt;
  final int? processedBy;
  final String? failureReason;
  final String? notes;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Payout({
    required this.id,
    required this.userId,
    required this.amount,
    required this.currency,
    required this.method,
    required this.status,
    this.reference,
    this.requestedAt,
    this.processedAt,
    this.processedBy,
    this.failureReason,
    this.notes,
    this.metadata,
    this.createdAt,
    this.updatedAt,
  });

  factory Payout.fromJson(Map<String, dynamic> json) {
    return Payout(
      id: asInt(json['id']),
      userId: asInt(json['user_id']),
      amount: asDouble(json['amount']),
      currency: json['currency'] as String? ?? 'TZS',
      method: PayoutMethod.fromString((json['method'] as String?) ?? 'mobile'),
      reference: json['reference'] as String?,
      status: PayoutStatus.fromString((json['status'] as String?) ?? 'unknown'),
      requestedAt: parseDate(json['requested_at']),
      processedAt: parseDate(json['processed_at']),
      processedBy: json['processed_by'] == null
          ? null
          : asInt(json['processed_by']),
      failureReason: json['failure_reason'] as String?,
      notes: json['notes'] as String?,
      metadata: asMap(json['metadata']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'amount': amount,
        'currency': currency,
        'method': method.name,
        'reference': reference,
        'status': status.name,
        'requested_at': requestedAt?.toIso8601String(),
        'processed_at': processedAt?.toIso8601String(),
        'processed_by': processedBy,
        'failure_reason': failureReason,
        'notes': notes,
        'metadata': metadata,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  // ─── State helpers ───────────────────────────────────────
  bool get isPaid => status.isPaid;
  bool get isPending => status.isPending;
  bool get isFailed => status.isFailed;
  bool get isTerminal => status.isTerminal;

  // ─── Display ─────────────────────────────────────────────
  String get amountLabel => '$currency ${amount.toStringAsFixed(0)}';
  String get statusLabel => status.displayLabel;
  String get methodLabel => method.displayLabel;
}