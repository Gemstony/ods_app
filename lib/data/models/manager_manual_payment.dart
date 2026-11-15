import '../../core/utils/json_helpers.dart';

/// One pending manual payment as exposed by
/// `GET /manager/payments/pending` or `GET /owner/payments/pending`.
///
/// Wire shape mirrors `Manager\ManualPaymentController::index` /
/// `Owner\ManualPaymentController::index` items from Phase 13.7.
class ManagerManualPayment {
  final int id;
  final String reference;
  final double amount;
  final String currency;
  final String method; // 'cash' | 'manual'
  final String stage; // 'full' | 'ods_fee' | 'transport_fare'
  final String status; // 'pending'
  final DateTime? initiatedAt;
  final ManualPaymentDeliveryRef? delivery;
  final ManualPaymentUserRef? initiatedBy;

  const ManagerManualPayment({
    required this.id,
    required this.reference,
    required this.amount,
    required this.currency,
    required this.method,
    required this.stage,
    required this.status,
    this.initiatedAt,
    this.delivery,
    this.initiatedBy,
  });

  factory ManagerManualPayment.fromJson(Map<String, dynamic> json) {
    final rawDelivery = json['delivery'];
    final rawInitiator = json['initiated_by'];

    return ManagerManualPayment(
      id: asInt(json['id']),
      reference: (json['reference'] as String?) ?? '',
      amount: asDouble(json['amount'] ?? 0),
      currency: (json['currency'] as String?) ?? 'TZS',
      method: (json['method'] as String?) ?? 'cash',
      stage: (json['stage'] as String?) ?? 'full',
      status: (json['status'] as String?) ?? 'pending',
      initiatedAt: parseDate(json['initiated_at']),
      delivery: rawDelivery is Map
          ? ManualPaymentDeliveryRef.fromJson(
              Map<String, dynamic>.from(rawDelivery),
            )
          : null,
      initiatedBy: rawInitiator is Map
          ? ManualPaymentUserRef.fromJson(
              Map<String, dynamic>.from(rawInitiator),
            )
          : null,
    );
  }

  // ─── Display helpers ────────────────────────────────────
  String get amountLabel => '$currency ${amount.toStringAsFixed(0)}';

  String get methodLabel => switch (method) {
        'cash' => 'Cash',
        'manual' => 'Manual',
        _ => method,
      };

  String get stageLabel => switch (stage) {
        'full' => 'Full payment',
        'ods_fee' => 'ODS fee',
        'transport_fare' => 'Transport fare',
        _ => stage,
      };
}

class ManualPaymentDeliveryRef {
  final int id;
  final String trackingId;
  final String serviceType;
  final String status;

  const ManualPaymentDeliveryRef({
    required this.id,
    required this.trackingId,
    required this.serviceType,
    required this.status,
  });

  factory ManualPaymentDeliveryRef.fromJson(Map<String, dynamic> json) =>
      ManualPaymentDeliveryRef(
        id: asInt(json['id']),
        trackingId: (json['tracking_id'] as String?) ?? '',
        serviceType: (json['service_type'] as String?) ?? 'receive',
        status: (json['status'] as String?) ?? 'pending_payment',
      );
}

class ManualPaymentUserRef {
  final int id;
  final String name;

  const ManualPaymentUserRef({required this.id, required this.name});

  factory ManualPaymentUserRef.fromJson(Map<String, dynamic> json) =>
      ManualPaymentUserRef(
        id: asInt(json['id']),
        name: (json['name'] as String?) ?? 'Unknown',
      );
}