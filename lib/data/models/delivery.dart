import '../../core/utils/json_helpers.dart';
import 'delivery_item.dart';
import 'dispatcher_ticket.dart';

/// Which of the three ODS services this delivery belongs to.
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

  bool get isLocal => this != ServiceType.regional;

  String get displayLabel => switch (this) {
        ServiceType.receive => 'Receive',
        ServiceType.send => 'Send',
        ServiceType.regional => 'Regional',
      };
}

/// The lifecycle states a delivery moves through.
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
  unknown;

  static DeliveryStatus fromString(String value) {
    return DeliveryStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => DeliveryStatus.unknown,
    );
  }

  bool get isTerminal =>
      this == delivered ||
      this == cancelled ||
      this == failed ||
      this == expired;

  bool get isInProgress => !isTerminal;

  bool get isDelivered => this == delivered;
  bool get isCancelled => this == cancelled;
  bool get isPaid => this != pending_payment;

  bool get hasRider =>
      this == assigned ||
      this == accepted ||
      this == picked_up ||
      this == dispatched;

  bool get isInTransit => this == picked_up || this == dispatched;

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

/// A delivery request. One class covers all three services.
class Delivery {
  final int id;
  final String trackingId;

  final int distributorId;
  final int? pickupBranchId;

  final ServiceType serviceType;
  final DeliveryStatus status;
  final String rawStatus;

  final String? pickupAddress;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final String? pickupContactPhone;

  final String? destinationAddress;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final String? destinationRegion;
  final String? destinationDistrict;
  final String? destinationBusStop;

  final String? recipientName;
  final String? recipientPhone;

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

  final int? riderId;
  final DateTime? assignedAt;
  final DateTime? assignmentExpiresAt;
  final DateTime? acceptedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;

  final int? dispatcherId;
  final DateTime? dispatchedAt;

  final String? batchId;
  final DateTime? batchWindowStart;
  final DateTime? batchWindowEnd;
  final String? assignmentGroupId;

  final DateTime? cancelledAt;
  final int? cancelledBy;
  final String? cancellationReason;

  final String? notes;
  final int? hoursAtBranch;

  final List<DeliveryItem>? items;

  /// Present only when the backend eager-loads the `dispatcherTicket`
  /// relation — Regional list / dispatch responses. Null everywhere else
  /// (Phase 9.3+).
  final DispatcherTicket? dispatcherTicket;

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
    this.hoursAtBranch,
    this.items,
    this.dispatcherTicket,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory Delivery.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'] as String;
    final rawTicket = json['dispatcher_ticket'];

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
      distanceKm:
          json['distance_km'] == null ? null : asDouble(json['distance_km']),
      ratePerKm:
          json['rate_per_km'] == null ? null : asDouble(json['rate_per_km']),
      minimumFee:
          json['minimum_fee'] == null ? null : asDouble(json['minimum_fee']),
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
      totalAmount:
          json['total_amount'] == null ? null : asDouble(json['total_amount']),
      currency: json['currency'] as String? ?? 'TZS',
      riderId: json['rider_id'] == null ? null : asInt(json['rider_id']),
      assignedAt: parseDate(json['assigned_at']),
      assignmentExpiresAt: parseDate(json['assignment_expires_at']),
      acceptedAt: parseDate(json['accepted_at']),
      pickedUpAt: parseDate(json['picked_up_at']),
      deliveredAt: parseDate(json['delivered_at']),
      dispatcherId:
          json['dispatcher_id'] == null ? null : asInt(json['dispatcher_id']),
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
      hoursAtBranch: json['hours_at_branch'] == null
          ? null
          : asInt(json['hours_at_branch']),
      items: asList(json['items'], DeliveryItem.fromJson),
      dispatcherTicket: rawTicket is Map
          ? DispatcherTicket.fromJson(Map<String, dynamic>.from(rawTicket))
          : null,
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
        'hours_at_branch': hoursAtBranch,
        'items': items?.map((i) => i.toJson()).toList(),
        'dispatcher_ticket': dispatcherTicket?.toJson(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
      };

  // ─── Service-type helpers ────────────────────────────────
  bool get isReceive => serviceType == ServiceType.receive;
  bool get isSend => serviceType == ServiceType.send;
  bool get isRegional => serviceType == ServiceType.regional;
  bool get isLocal => serviceType.isLocal;

  // ─── Status helpers ──────────────────────────────────────
  bool get isDelivered => status.isDelivered;
  bool get isCancelled => status.isCancelled;
  bool get isActive => status.isInProgress;
  bool get isPaid => status.isPaid;

  // ─── Display helpers ─────────────────────────────────────
  String get shortLabel => '${serviceType.displayLabel} · $trackingId';

  String get totalAmountLabel {
    if (totalAmount == null) return '—';
    return '$currency ${totalAmount!.toStringAsFixed(0)}';
  }

  String get feeSummaryLabel {
    if (isRegional && busCargoFare != null && odsDeliveryFee != null) {
      return '$currency ${odsDeliveryFee!.toStringAsFixed(0)} + '
          '${busCargoFare!.toStringAsFixed(0)} transport';
    }
    return totalAmountLabel;
  }

  String? get packageAge {
    if (hoursAtBranch == null) return null;
    final h = hoursAtBranch!;
    if (h < 4) return 'fresh';
    if (h <= 24) return 'aging';
    return 'stale';
  }
}