import '../../core/utils/json_helpers.dart';
import 'delivery_item.dart';

/// Which of the three ODS services this delivery belongs to.
///
/// Snake_case names match the backend's `service_type` values exactly, so
/// `.name` serializes straight to JSON without a lookup table.
enum ServiceType {
  receive,
  send,
  regional;

  static ServiceType fromString(String value) {
    return ServiceType.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ServiceType.receive,
    );
  }

  /// True for Receive and Send (both are local, same-day).
  /// False for Regional.
  bool get isLocal => this != ServiceType.regional;

  String get displayLabel => switch (this) {
        ServiceType.receive => 'Receive',
        ServiceType.send => 'Send',
        ServiceType.regional => 'Regional',
      };
}

/// The lifecycle states a delivery moves through.
///
/// Snake_case names match the backend's `status` values exactly. Local
/// (Receive/Send) deliveries skip `dispatched`; Regional deliveries skip
/// `accepted`. Both share all other states.
enum DeliveryStatus {
  pending_payment,
  paid,
  batched,
  assigned,
  accepted,
  picked_up,
  dispatched,
  delivered,
  cancelled,
  failed,
  expired,

  /// Fallback when the backend sends a status this client doesn't know yet.
  /// The Delivery model also stores the raw string so nothing is lost.
  unknown;

  static DeliveryStatus fromString(String value) {
    return DeliveryStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => DeliveryStatus.unknown,
    );
  }

  // ─── Lifecycle predicates ────────────────────────────────
  /// True when the delivery won't transition any further — either done or
  /// dead. Terminal states: delivered, cancelled, failed, expired.
  bool get isTerminal =>
      this == delivered ||
      this == cancelled ||
      this == failed ||
      this == expired;

  /// True when the delivery can still progress. Complement of [isTerminal].
  bool get isInProgress => !isTerminal;

  bool get isDelivered => this == delivered;
  bool get isCancelled => this == cancelled;

  /// True once payment has been received (any state past pending_payment).
  /// Does NOT imply the delivery is still active — a cancelled delivery is
  /// also "paid" if the cancellation happened after payment.
  bool get isPaid => this != pending_payment;

  /// True when a rider has been assigned (assigned → accepted → picked_up
  /// → dispatched). Useful for "show rider info" decisions.
  bool get hasRider =>
      this == assigned ||
      this == accepted ||
      this == picked_up ||
      this == dispatched;

  /// True once the rider has the package in hand.
  bool get isInTransit =>
      this == picked_up || this == dispatched;

  // ─── UI label ────────────────────────────────────────────
  /// Human-readable label for status chips and tables.
  String get displayLabel => switch (this) {
        DeliveryStatus.pending_payment => 'Awaiting payment',
        DeliveryStatus.paid => 'Ready for pickup',
        DeliveryStatus.batched => 'Batching',
        DeliveryStatus.assigned => 'Rider assigned',
        DeliveryStatus.accepted => 'Rider on the way',
        DeliveryStatus.picked_up => 'Picked up',
        DeliveryStatus.dispatched => 'Dispatched',
        DeliveryStatus.delivered => 'Delivered',
        DeliveryStatus.cancelled => 'Cancelled',
        DeliveryStatus.failed => 'Failed',
        DeliveryStatus.expired => 'Expired',
        DeliveryStatus.unknown => 'Unknown',
      };
}

/// A delivery request.
///
/// One class covers all three services (Receive / Send / Regional). Fields
/// that only apply to specific services are nullable — which fields are
/// required for which service is enforced by the backend's FormRequest,
/// not by this model.
///
/// **Pricing snapshot**: `distanceKm`, `ratePerKm`, `minimumFee`,
/// `roundingIncrement`, `calculatedFee`, `odsDeliveryFee`, and
/// `busCargoFare` are snapshotted at the moment payment is initiated. They
/// never change for a given delivery, even if the Owner later updates the
/// platform's pricing configuration.
class Delivery {
  final int id;
  final String trackingId;

  // ─── Core references ─────────────────────────────────────
  final int distributorId;
  final int? pickupBranchId;

  // ─── Service type + status ───────────────────────────────
  final ServiceType serviceType;
  final DeliveryStatus status;

  /// Raw status string from the backend. Preserved for debugging when
  /// [status] is [DeliveryStatus.unknown].
  final String rawStatus;

  // ─── Pickup location ─────────────────────────────────────
  final String? pickupAddress;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final String? pickupContactPhone;

  // ─── Destination location ────────────────────────────────
  final String? destinationAddress;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final String? destinationRegion;
  final String? destinationDistrict;
  final String? destinationBusStop;

  // ─── Recipient (Send + Regional) ─────────────────────────
  final String? recipientName;
  final String? recipientPhone;

  // ─── Pricing snapshot ────────────────────────────────────
  final double? distanceKm;
  final double? ratePerKm;
  final double? minimumFee;
  final int? roundingIncrement;
  final double? calculatedFee;
  final double? odsDeliveryFee;
  final double? busCargoFare;
  final double discountAmount;
  final String? discountReason;
  final double? totalAmount;
  final String currency;

  // ─── Assignment ──────────────────────────────────────────
  final int? riderId;
  final DateTime? assignedAt;
  final DateTime? assignmentExpiresAt;
  final DateTime? acceptedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;

  // ─── Regional dispatch ───────────────────────────────────
  final int? dispatcherId;
  final DateTime? dispatchedAt;

  // ─── Batching (populated by Phase 10) ────────────────────
  final String? batchId;
  final DateTime? batchWindowStart;
  final DateTime? batchWindowEnd;
  final String? assignmentGroupId;

  // ─── Cancellation ────────────────────────────────────────
  final DateTime? cancelledAt;
  final int? cancelledBy;
  final String? cancellationReason;

  // ─── Extras ──────────────────────────────────────────────
  final String? notes;

  // ─── Items (nullable — only included when backend loads them) ─
  final List<DeliveryItem>? items;

  // ─── Metadata ────────────────────────────────────────────
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  const Delivery({
    required this.id,
    required this.trackingId,
    required this.distributorId,
    required this.serviceType,
    required this.status,
    required this.rawStatus,
    required this.discountAmount,
    required this.currency,
    this.pickupBranchId,
    this.pickupAddress,
    this.pickupLatitude,
    this.pickupLongitude,
    this.pickupContactPhone,
    this.destinationAddress,
    this.destinationLatitude,
    this.destinationLongitude,
    this.destinationRegion,
    this.destinationDistrict,
    this.destinationBusStop,
    this.recipientName,
    this.recipientPhone,
    this.distanceKm,
    this.ratePerKm,
    this.minimumFee,
    this.roundingIncrement,
    this.calculatedFee,
    this.odsDeliveryFee,
    this.busCargoFare,
    this.discountReason,
    this.totalAmount,
    this.riderId,
    this.assignedAt,
    this.assignmentExpiresAt,
    this.acceptedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.dispatcherId,
    this.dispatchedAt,
    this.batchId,
    this.batchWindowStart,
    this.batchWindowEnd,
    this.assignmentGroupId,
    this.cancelledAt,
    this.cancelledBy,
    this.cancellationReason,
    this.notes,
    this.items,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory Delivery.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'] as String;
    return Delivery(
      id: asInt(json['id']),
      trackingId: json['tracking_id'] as String,
      distributorId: asInt(json['distributor_id']),
      pickupBranchId: json['pickup_branch_id'] == null
          ? null
          : asInt(json['pickup_branch_id']),
      serviceType: ServiceType.fromString(json['service_type'] as String),
      status: DeliveryStatus.fromString(rawStatus),
      rawStatus: rawStatus,
      pickupAddress: json['pickup_address'] as String?,
      pickupLatitude: json['pickup_latitude'] == null
          ? null
          : asDouble(json['pickup_latitude']),
      pickupLongitude: json['pickup_longitude'] == null
          ? null
          : asDouble(json['pickup_longitude']),
      pickupContactPhone: json['pickup_contact_phone'] as String?,
      destinationAddress: json['destination_address'] as String?,
      destinationLatitude: json['destination_latitude'] == null
          ? null
          : asDouble(json['destination_latitude']),
      destinationLongitude: json['destination_longitude'] == null
          ? null
          : asDouble(json['destination_longitude']),
      destinationRegion: json['destination_region'] as String?,
      destinationDistrict: json['destination_district'] as String?,
      destinationBusStop: json['destination_bus_stop'] as String?,
      recipientName: json['recipient_name'] as String?,
      recipientPhone: json['recipient_phone'] as String?,
      distanceKm: json['distance_km'] == null
          ? null
          : asDouble(json['distance_km']),
      ratePerKm: json['rate_per_km'] == null
          ? null
          : asDouble(json['rate_per_km']),
      minimumFee: json['minimum_fee'] == null
          ? null
          : asDouble(json['minimum_fee']),
      roundingIncrement: json['rounding_increment'] == null
          ? null
          : asInt(json['rounding_increment']),
      calculatedFee: json['calculated_fee'] == null
          ? null
          : asDouble(json['calculated_fee']),
      odsDeliveryFee: json['ods_delivery_fee'] == null
          ? null
          : asDouble(json['ods_delivery_fee']),
      busCargoFare: json['bus_cargo_fare'] == null
          ? null
          : asDouble(json['bus_cargo_fare']),
      discountAmount: json['discount_amount'] == null
          ? 0.0
          : asDouble(json['discount_amount']),
      discountReason: json['discount_reason'] as String?,
      totalAmount: json['total_amount'] == null
          ? null
          : asDouble(json['total_amount']),
      currency: json['currency'] as String? ?? 'TZS',
      riderId: json['rider_id'] == null ? null : asInt(json['rider_id']),
      assignedAt: parseDate(json['assigned_at']),
      assignmentExpiresAt: parseDate(json['assignment_expires_at']),
      acceptedAt: parseDate(json['accepted_at']),
      pickedUpAt: parseDate(json['picked_up_at']),
      deliveredAt: parseDate(json['delivered_at']),
      dispatcherId: json['dispatcher_id'] == null
          ? null
          : asInt(json['dispatcher_id']),
      dispatchedAt: parseDate(json['dispatched_at']),
      batchId: json['batch_id'] as String?,
      batchWindowStart: parseDate(json['batch_window_start']),
      batchWindowEnd: parseDate(json['batch_window_end']),
      assignmentGroupId: json['assignment_group_id'] as String?,
      cancelledAt: parseDate(json['cancelled_at']),
      cancelledBy:
          json['cancelled_by'] == null ? null : asInt(json['cancelled_by']),
      cancellationReason: json['cancellation_reason'] as String?,
      notes: json['notes'] as String?,
      items: asList(json['items'], DeliveryItem.fromJson),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      deletedAt: parseDate(json['deleted_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tracking_id': trackingId,
        'distributor_id': distributorId,
        'pickup_branch_id': pickupBranchId,
        'service_type': serviceType.name,
        'status': rawStatus,
        'pickup_address': pickupAddress,
        'pickup_latitude': pickupLatitude,
        'pickup_longitude': pickupLongitude,
        'pickup_contact_phone': pickupContactPhone,
        'destination_address': destinationAddress,
        'destination_latitude': destinationLatitude,
        'destination_longitude': destinationLongitude,
        'destination_region': destinationRegion,
        'destination_district': destinationDistrict,
        'destination_bus_stop': destinationBusStop,
        'recipient_name': recipientName,
        'recipient_phone': recipientPhone,
        'distance_km': distanceKm,
        'rate_per_km': ratePerKm,
        'minimum_fee': minimumFee,
        'rounding_increment': roundingIncrement,
        'calculated_fee': calculatedFee,
        'ods_delivery_fee': odsDeliveryFee,
        'bus_cargo_fare': busCargoFare,
        'discount_amount': discountAmount,
        'discount_reason': discountReason,
        'total_amount': totalAmount,
        'currency': currency,
        'rider_id': riderId,
        'assigned_at': assignedAt?.toIso8601String(),
        'assignment_expires_at': assignmentExpiresAt?.toIso8601String(),
        'accepted_at': acceptedAt?.toIso8601String(),
        'picked_up_at': pickedUpAt?.toIso8601String(),
        'delivered_at': deliveredAt?.toIso8601String(),
        'dispatcher_id': dispatcherId,
        'dispatched_at': dispatchedAt?.toIso8601String(),
        'batch_id': batchId,
        'batch_window_start': batchWindowStart?.toIso8601String(),
        'batch_window_end': batchWindowEnd?.toIso8601String(),
        'assignment_group_id': assignmentGroupId,
        'cancelled_at': cancelledAt?.toIso8601String(),
        'cancelled_by': cancelledBy,
        'cancellation_reason': cancellationReason,
        'notes': notes,
        'items': items?.map((i) => i.toJson()).toList(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
      };

  // ─── Service-type helpers ────────────────────────────────
  bool get isReceive => serviceType == ServiceType.receive;
  bool get isSend => serviceType == ServiceType.send;
  bool get isRegional => serviceType == ServiceType.regional;
  bool get isLocal => serviceType.isLocal;

  // ─── Status helpers (delegates to enum) ──────────────────
  bool get isDelivered => status.isDelivered;
  bool get isCancelled => status.isCancelled;
  bool get isActive => status.isInProgress;
  bool get isPaid => status.isPaid;

  // ─── Display helpers ─────────────────────────────────────
  /// e.g. "Receive · ODS-20261024-ABC123"
  String get shortLabel => '${serviceType.displayLabel} · $trackingId';

  /// Formatted fee for list tiles. Null-safe (returns "—" if unset).
  String get totalAmountLabel {
    if (totalAmount == null) return '—';
    return '${currency} ${totalAmount!.toStringAsFixed(0)}';
  }

  /// The fee the distributor pays for this delivery. Regional deliveries
  /// add `busCargoFare` on top; local deliveries don't.
  String get feeSummaryLabel {
    if (isRegional && busCargoFare != null && odsDeliveryFee != null) {
      return '${currency} ${odsDeliveryFee!.toStringAsFixed(0)} + '
          '${busCargoFare!.toStringAsFixed(0)} transport';
    }
    return totalAmountLabel;
  }
}