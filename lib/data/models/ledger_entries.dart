import '../../core/utils/json_helpers.dart';
import 'earning.dart';
import 'payment.dart';
import 'payout.dart';

/// Minimal delivery reference embedded in ledger responses.
class DeliveryRef {
  final int id;
  final String trackingId;
  final String status;
  final String? serviceType;
  final int? distributorId;
  final double? totalAmount;

  const DeliveryRef({
    required this.id,
    required this.trackingId,
    required this.status,
    this.serviceType,
    this.distributorId,
    this.totalAmount,
  });

  factory DeliveryRef.fromJson(Map<String, dynamic> json) => DeliveryRef(
        id: asInt(json['id']),
        trackingId: json['tracking_id'] as String,
        status: json['status'] as String,
        serviceType: json['service_type'] as String?,
        distributorId: json['distributor_id'] == null
            ? null
            : asInt(json['distributor_id']),
        totalAmount: json['total_amount'] == null
            ? null
            : asDouble(json['total_amount']),
      );
}

/// Minimal user reference embedded in ledger responses.
class UserRef {
  final int id;
  final String name;
  final String? email;

  const UserRef({required this.id, required this.name, this.email});

  factory UserRef.fromJson(Map<String, dynamic> json) => UserRef(
        id: asInt(json['id']),
        name: json['name'] as String,
        email: json['email'] as String?,
      );
}

// ═══════════════════════════════════════════════════════════════
// Owner payment entry — Payment + optional nested delivery/initiator
// ═══════════════════════════════════════════════════════════════

class OwnerPaymentEntry {
  final Payment payment;
  final DeliveryRef? delivery;
  final UserRef? initiator;

  const OwnerPaymentEntry({
    required this.payment,
    this.delivery,
    this.initiator,
  });

  factory OwnerPaymentEntry.fromJson(Map<String, dynamic> json) {
    final rawDelivery = json['delivery'];
    final rawInitiator = json['initiated_by'];
    return OwnerPaymentEntry(
      payment: Payment.fromJson(json),
      delivery: rawDelivery is Map
          ? DeliveryRef.fromJson(Map<String, dynamic>.from(rawDelivery))
          : null,
      initiator: rawInitiator is Map
          ? UserRef.fromJson(Map<String, dynamic>.from(rawInitiator))
          : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Owner earning entry — Earning + optional nested user/delivery
// ═══════════════════════════════════════════════════════════════

class OwnerEarningEntry {
  final Earning earning;
  final UserRef? user;
  final DeliveryRef? delivery;

  const OwnerEarningEntry({
    required this.earning,
    this.user,
    this.delivery,
  });

  factory OwnerEarningEntry.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    final rawDelivery = json['delivery'];
    return OwnerEarningEntry(
      earning: Earning.fromJson(json),
      user: rawUser is Map
          ? UserRef.fromJson(Map<String, dynamic>.from(rawUser))
          : null,
      delivery: rawDelivery is Map
          ? DeliveryRef.fromJson(Map<String, dynamic>.from(rawDelivery))
          : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Owner payout entry — Payout + optional nested user/earnings
// ═══════════════════════════════════════════════════════════════

/// Minimal earning reference embedded in a payout detail response.
class EarningRef {
  final int id;
  final int deliveryId;
  final String type;
  final double amount;
  final String status;

  const EarningRef({
    required this.id,
    required this.deliveryId,
    required this.type,
    required this.amount,
    required this.status,
  });

  factory EarningRef.fromJson(Map<String, dynamic> json) => EarningRef(
        id: asInt(json['id']),
        deliveryId: asInt(json['delivery_id']),
        type: json['type'] as String,
        amount: asDouble(json['amount']),
        status: json['status'] as String,
      );
}

class OwnerPayoutEntry {
  final Payout payout;
  final UserRef? user;
  final UserRef? processedBy;
  final List<EarningRef> earnings;

  const OwnerPayoutEntry({
    required this.payout,
    this.user,
    this.processedBy,
    this.earnings = const [],
  });

  factory OwnerPayoutEntry.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    final rawProcessedBy = json['processed_by'];
    final rawEarnings = json['earnings'];

    return OwnerPayoutEntry(
      payout: Payout.fromJson(json),
      user: rawUser is Map
          ? UserRef.fromJson(Map<String, dynamic>.from(rawUser))
          : null,
      processedBy: rawProcessedBy is Map
          ? UserRef.fromJson(Map<String, dynamic>.from(rawProcessedBy))
          : null,
      earnings: rawEarnings is List
          ? rawEarnings
              .whereType<Map>()
              .map((j) => EarningRef.fromJson(Map<String, dynamic>.from(j)))
              .toList(growable: false)
          : const [],
    );
  }
}