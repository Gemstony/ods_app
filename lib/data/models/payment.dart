import '../../core/utils/json_helpers.dart';

/// Which stage of a payment this record represents.
enum PaymentStage {
  full,
  ods_fee,
  transport_fare;

  static PaymentStage fromString(String value) {
    return PaymentStage.values.firstWhere(
      (s) => s.name == value,
      orElse: () => PaymentStage.full,
    );
  }

  bool get isRegionalStage => this != PaymentStage.full;

  String get displayLabel => switch (this) {
        PaymentStage.full => 'Full payment',
        PaymentStage.ods_fee => 'ODS delivery fee',
        PaymentStage.transport_fare => 'Transport fare',
      };
}

enum PaymentMethod {
  clickpesa,
  cash,
  manual;

  static PaymentMethod fromString(String value) {
    return PaymentMethod.values.firstWhere(
      (m) => m.name == value,
      orElse: () => PaymentMethod.clickpesa,
    );
  }

  String get displayLabel => switch (this) {
        PaymentMethod.clickpesa => 'ClickPesa',
        PaymentMethod.cash => 'Cash',
        PaymentMethod.manual => 'Manual',
      };
}

enum PaymentStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
  refunded,
  expired,
  unknown;

  static PaymentStatus fromString(String value) {
    return PaymentStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => PaymentStatus.unknown,
    );
  }

  bool get isTerminal =>
      this == completed ||
      this == failed ||
      this == cancelled ||
      this == refunded ||
      this == expired;

  bool get isSuccess => this == completed;
  bool get isInFlight => this == pending || this == processing;

  String get displayLabel => switch (this) {
        PaymentStatus.pending => 'Pending',
        PaymentStatus.processing => 'Processing',
        PaymentStatus.completed => 'Completed',
        PaymentStatus.failed => 'Failed',
        PaymentStatus.cancelled => 'Cancelled',
        PaymentStatus.refunded => 'Refunded',
        PaymentStatus.expired => 'Expired',
        PaymentStatus.unknown => 'Unknown',
      };
}

/// USSD-side info carried only by the `POST /distributor/payments/initiate`
/// response (`PaymentController::paymentPayload(..., includeUssd: true)`).
///
/// Null on `show` / `refresh` responses — those reflect state, not the
/// initial prompt.
class PaymentUssd {
  final String providerStatus;
  final String message;

  const PaymentUssd({required this.providerStatus, required this.message});

  factory PaymentUssd.fromJson(Map<String, dynamic> json) => PaymentUssd(
        providerStatus: (json['provider_status'] as String?) ?? 'PENDING',
        message: (json['message'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'provider_status': providerStatus,
        'message': message,
      };
}

/// A single payment attempt (or its result).
class Payment {
  final int id;
  final int deliveryId;

  /// Status of the parent delivery at the moment this payment row was
  /// serialized. Null if the delivery relation wasn't loaded (rare).
  /// Useful for the client to short-circuit polling if the delivery is
  /// already `paid` (e.g., webhook arrived before we started polling).
  final String? deliveryStatusRaw;

  final PaymentStage stage;
  final double amount;
  final String currency;
  final PaymentMethod method;
  final PaymentStatus status;
  final String reference;
  final String? providerReference;
  final int initiatedBy;
  final DateTime initiatedAt;
  final DateTime? paidAt;
  final DateTime? failedAt;
  final DateTime? expiresAt;
  final String? failureReason;
  final Map<String, dynamic>? metadata;
  final PaymentUssd? ussd;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Payment({
    required this.id,
    required this.deliveryId,
    required this.stage,
    required this.amount,
    required this.currency,
    required this.method,
    required this.status,
    required this.reference,
    required this.initiatedBy,
    required this.initiatedAt,
    this.deliveryStatusRaw,
    this.providerReference,
    this.paidAt,
    this.failedAt,
    this.expiresAt,
    this.failureReason,
    this.metadata,
    this.ussd,
    this.createdAt,
    this.updatedAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    final rawUssd = json['ussd'];
    return Payment(
      id: asInt(json['id']),
      deliveryId: asInt(json['delivery_id']),
      deliveryStatusRaw: json['delivery_status'] as String?,
      stage: PaymentStage.fromString(json['stage'] as String),
      amount: asDouble(json['amount']),
      currency: json['currency'] as String? ?? 'TZS',
      method: PaymentMethod.fromString(json['method'] as String),
      status: PaymentStatus.fromString(json['status'] as String),
      reference: json['reference'] as String,
      providerReference: json['provider_reference'] as String?,
      initiatedBy: asInt(json['initiated_by']),
      initiatedAt: parseDate(json['initiated_at']) ?? DateTime.now(),
      paidAt: parseDate(json['paid_at']),
      failedAt: parseDate(json['failed_at']),
      expiresAt: parseDate(json['expires_at']),
      failureReason: json['failure_reason'] as String?,
      metadata: asMap(json['metadata']),
      ussd: rawUssd is Map
          ? PaymentUssd.fromJson(Map<String, dynamic>.from(rawUssd))
          : null,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'delivery_id': deliveryId,
        'delivery_status': deliveryStatusRaw,
        'stage': stage.name,
        'amount': amount,
        'currency': currency,
        'method': method.name,
        'status': status.name,
        'reference': reference,
        'provider_reference': providerReference,
        'initiated_by': initiatedBy,
        'initiated_at': initiatedAt.toIso8601String(),
        'paid_at': paidAt?.toIso8601String(),
        'failed_at': failedAt?.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'failure_reason': failureReason,
        'metadata': metadata,
        'ussd': ussd?.toJson(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  // ─── State helpers ───────────────────────────────────────
  bool get isCompleted => status.isSuccess;
  bool get isPending => status.isInFlight;
  bool get isFailed => status == PaymentStatus.failed;
  bool get isRefunded => status == PaymentStatus.refunded;
  bool get isRegionalStage => stage.isRegionalStage;
  bool get isTerminal => status.isTerminal;

  // ─── Display ─────────────────────────────────────────────
  String get amountLabel => '$currency ${amount.toStringAsFixed(0)}';
  String get stageLabel => stage.displayLabel;
  String get statusLabel => status.displayLabel;
  String get methodLabel => method.displayLabel;
}