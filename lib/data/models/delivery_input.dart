import 'delivery.dart';

/// A single item in a delivery creation payload.
///
/// Either an EXGO order reference (M-Commerce) or a manually-entered
/// product (WhatsApp order). Both can be set if the app verified EXGO
/// details AND the user supplied them. The backend accepts any combination.
class DeliveryItemInput {
  final String? exgoOrderId;
  final String? productName;
  final String? productCode;
  final int? quantity;
  final String? notes;

  const DeliveryItemInput({
    this.exgoOrderId,
    this.productName,
    this.productCode,
    this.quantity,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      if (exgoOrderId != null) 'exgo_order_id': exgoOrderId,
      if (productName != null) 'product_name': productName,
      if (productCode != null) 'product_code': productCode,
      if (quantity != null) 'quantity': quantity,
      if (notes != null) 'notes': notes,
    };
  }
}

/// The payload sent to `POST /distributor/deliveries`.
///
/// One class covers all three services. Fields irrelevant to the chosen
/// `serviceType` are simply null and omitted from JSON:
///
///   Receive:  pickupBranchId ✓, pickupContactPhone ✓, recipient ✗
///   Send:     pickupBranchId ✗, pickupAddress + coords ✓, recipient ✓
///   Regional: pickupBranchId ✓, destinationRegion/district/busStop ✓, recipient ✓
///
/// Validation of which fields are required per service is enforced by the
/// backend's FormRequest. The Flutter UI validates the same fields via
/// `Form` validators before calling `create()`.
class CreateDeliveryInput {
  final ServiceType serviceType;
  final List<DeliveryItemInput> items;

  final int? pickupBranchId;
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

  final String? notes;

  const CreateDeliveryInput({
    required this.serviceType,
    required this.items,
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
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'service_type': serviceType.name,
      'items': items.map((i) => i.toJson()).toList(),
      if (pickupBranchId != null) 'pickup_branch_id': pickupBranchId,
      if (pickupAddress != null) 'pickup_address': pickupAddress,
      if (pickupLatitude != null) 'pickup_latitude': pickupLatitude,
      if (pickupLongitude != null) 'pickup_longitude': pickupLongitude,
      if (pickupContactPhone != null)
        'pickup_contact_phone': pickupContactPhone,
      if (destinationAddress != null) 'destination_address': destinationAddress,
      if (destinationLatitude != null)
        'destination_latitude': destinationLatitude,
      if (destinationLongitude != null)
        'destination_longitude': destinationLongitude,
      if (destinationRegion != null) 'destination_region': destinationRegion,
      if (destinationDistrict != null)
        'destination_district': destinationDistrict,
      if (destinationBusStop != null) 'destination_bus_stop': destinationBusStop,
      if (recipientName != null) 'recipient_name': recipientName,
      if (recipientPhone != null) 'recipient_phone': recipientPhone,
      if (notes != null) 'notes': notes,
    };
  }
}

/// The payload sent to `POST /distributor/deliveries/price-preview`.
///
/// Minimal data needed for the backend to compute the fee: service type,
/// pickup branch (for distance baseline) or pickup coords (for Send),
/// destination coords, and whether a reward discount should apply.
class PricePreviewInput {
  final ServiceType serviceType;
  final int? pickupBranchId;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final String? destinationRegion;
  final String? destinationDistrict;

  /// Set to true when the distributor has an active tier-1 or tier-2
  /// reward and wants the discount applied. Backend recomputes eligibility.
  final bool applyReward;

  const PricePreviewInput({
    required this.serviceType,
    this.pickupBranchId,
    this.pickupLatitude,
    this.pickupLongitude,
    this.destinationLatitude,
    this.destinationLongitude,
    this.destinationRegion,
    this.destinationDistrict,
    this.applyReward = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'service_type': serviceType.name,
      if (pickupBranchId != null) 'pickup_branch_id': pickupBranchId,
      if (pickupLatitude != null) 'pickup_latitude': pickupLatitude,
      if (pickupLongitude != null) 'pickup_longitude': pickupLongitude,
      if (destinationLatitude != null)
        'destination_latitude': destinationLatitude,
      if (destinationLongitude != null)
        'destination_longitude': destinationLongitude,
      if (destinationRegion != null) 'destination_region': destinationRegion,
      if (destinationDistrict != null)
        'destination_district': destinationDistrict,
      'apply_reward': applyReward,
    };
  }
}

/// The response from `POST /distributor/deliveries/price-preview`.
///
/// A read-only projection of the pricing math — the fee, its components,
/// and any applied discount. Screens show this to the distributor before
/// they confirm and pay.
class PricePreviewResult {
  final ServiceType serviceType;
  final double distanceKm;
  final double ratePerKm;
  final double minimumFee;
  final int roundingIncrement;
  final double calculatedFee;
  final double odsDeliveryFee;
  final double? busCargoFare;
  final double discountAmount;
  final String? discountReason;
  final double totalAmount;
  final String currency;

  const PricePreviewResult({
    required this.serviceType,
    required this.distanceKm,
    required this.ratePerKm,
    required this.minimumFee,
    required this.roundingIncrement,
    required this.calculatedFee,
    required this.odsDeliveryFee,
    required this.discountAmount,
    required this.totalAmount,
    required this.currency,
    this.busCargoFare,
    this.discountReason,
  });

  factory PricePreviewResult.fromJson(Map<String, dynamic> json) {
    return PricePreviewResult(
      serviceType: ServiceType.fromString(json['service_type'] as String),
      distanceKm: _asDouble(json['distance_km']),
      ratePerKm: _asDouble(json['rate_per_km']),
      minimumFee: _asDouble(json['minimum_fee']),
      roundingIncrement: _asInt(json['rounding_increment']),
      calculatedFee: _asDouble(json['calculated_fee']),
      odsDeliveryFee: _asDouble(json['ods_delivery_fee']),
      busCargoFare: json['bus_cargo_fare'] == null
          ? null
          : _asDouble(json['bus_cargo_fare']),
      discountAmount: json['discount_amount'] == null
          ? 0.0
          : _asDouble(json['discount_amount']),
      discountReason: json['discount_reason'] as String?,
      totalAmount: _asDouble(json['total_amount']),
      currency: json['currency'] as String? ?? 'TZS',
    );
  }

  // ─── Display ─────────────────────────────────────────────
  bool get isRegional => serviceType == ServiceType.regional;

  bool get hasDiscount => discountAmount > 0;

  String get totalLabel => '$currency ${totalAmount.toStringAsFixed(0)}';

  String get odsFeeLabel => '$currency ${odsDeliveryFee.toStringAsFixed(0)}';

  String? get busFareLabel => busCargoFare == null
      ? null
      : '$currency ${busCargoFare!.toStringAsFixed(0)}';

  String get distanceLabel => '${distanceKm.toStringAsFixed(1)} km';

  // ─── Defensive numeric parsing ───────────────────────────
  static double _asDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.parse(v);
    throw FormatException('Cannot parse double from $v');
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.parse(v);
    if (v is double) return v.toInt();
    throw FormatException('Cannot parse int from $v');
  }
}