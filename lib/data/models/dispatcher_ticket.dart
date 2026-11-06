import '../../core/utils/json_helpers.dart';

/// A bus/cargo dispatch ticket for a regional delivery.
///
/// Mirrors `App\Http\Resources\DispatcherTicketResource` (Phase 9.1).
///
/// IMPORTANT: `transportFare` is money owed to the provider — never
/// dispatcher income. Dispatcher compensation is tracked separately in
/// the earnings ledger (Phase 11).
class DispatcherTicket {
  final int id;
  final int deliveryId;
  final int dispatcherId;
  final String providerName;
  final String providerType; // 'bus' | 'cargo' | 'other'
  final String ticketNumber;
  final String routeFrom;
  final String routeTo;
  final double? transportFare;
  final String currency;
  final DateTime? issuedAt;
  final DateTime? providerConfirmedAt;
  final int? providerConfirmedBy;
  final String? ticketImagePath;
  final String? notes;

  // Nested dispatcher reference, when eager-loaded by the backend.
  final String? dispatcherName;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DispatcherTicket({
    required this.id,
    required this.deliveryId,
    required this.dispatcherId,
    required this.providerName,
    required this.providerType,
    required this.ticketNumber,
    required this.routeFrom,
    required this.routeTo,
    required this.currency,
    this.transportFare,
    this.issuedAt,
    this.providerConfirmedAt,
    this.providerConfirmedBy,
    this.ticketImagePath,
    this.notes,
    this.dispatcherName,
    this.createdAt,
    this.updatedAt,
  });

  factory DispatcherTicket.fromJson(Map<String, dynamic> json) {
    final rawDispatcher = json['dispatcher'];
    return DispatcherTicket(
      id: asInt(json['id']),
      deliveryId: asInt(json['delivery_id']),
      dispatcherId: asInt(json['dispatcher_id']),
      providerName: json['provider_name'] as String,
      providerType: json['provider_type'] as String,
      ticketNumber: json['ticket_number'] as String,
      routeFrom: json['route_from'] as String,
      routeTo: json['route_to'] as String,
      transportFare: json['transport_fare'] == null
          ? null
          : asDouble(json['transport_fare']),
      currency: json['currency'] as String? ?? 'TZS',
      issuedAt: parseDate(json['issued_at']),
      providerConfirmedAt: parseDate(json['provider_confirmed_at']),
      providerConfirmedBy: json['provider_confirmed_by'] == null
          ? null
          : asInt(json['provider_confirmed_by']),
      ticketImagePath: json['ticket_image_path'] as String?,
      notes: json['notes'] as String?,
      dispatcherName: rawDispatcher is Map
          ? rawDispatcher['name'] as String?
          : null,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'delivery_id': deliveryId,
        'dispatcher_id': dispatcherId,
        'provider_name': providerName,
        'provider_type': providerType,
        'ticket_number': ticketNumber,
        'route_from': routeFrom,
        'route_to': routeTo,
        'transport_fare': transportFare,
        'currency': currency,
        'issued_at': issuedAt?.toIso8601String(),
        'provider_confirmed_at': providerConfirmedAt?.toIso8601String(),
        'provider_confirmed_by': providerConfirmedBy,
        'ticket_image_path': ticketImagePath,
        'notes': notes,
        'dispatcher_name': dispatcherName,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  bool get isConfirmed => providerConfirmedAt != null;

  String get providerTypeLabel => switch (providerType) {
        'bus' => 'Bus',
        'cargo' => 'Cargo',
        'other' => 'Other',
        _ => providerType,
      };

  String get transportFareLabel {
    if (transportFare == null) return '—';
    return '$currency ${transportFare!.toStringAsFixed(0)}';
  }
}