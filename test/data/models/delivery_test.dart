import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/data/models/delivery.dart';
import 'package:ods_app/data/models/delivery_item.dart';

/// Sample JSON for a Receive delivery (pickup branch → distributor).
/// All service-specific fields that don't apply are null.
Map<String, dynamic> _receiveJson() => {
      'id': 1,
      'tracking_id': 'ODS-20261024-ABC123',
      'distributor_id': 42,
      'pickup_branch_id': 5,
      'service_type': 'receive',
      'status': 'paid',
      'pickup_address': '123 Kariakoo Street, Dar es Salaam',
      'pickup_latitude': -6.7924,
      'pickup_longitude': 39.2083,
      'pickup_contact_phone': '0712345678',
      'destination_address': '456 Upanga Road, Dar es Salaam',
      'destination_latitude': -6.7890,
      'destination_longitude': 39.2200,
      'destination_region': null,
      'destination_district': null,
      'destination_bus_stop': null,
      'recipient_name': null,
      'recipient_phone': null,
      'distance_km': 3.2,
      'rate_per_km': 500.00,
      'minimum_fee': 1000.00,
      'rounding_increment': 500,
      'calculated_fee': 1600.00,
      'ods_delivery_fee': 2000.00,
      'bus_cargo_fare': null,
      'discount_amount': 0.00,
      'discount_reason': null,
      'total_amount': 2000.00,
      'currency': 'TZS',
      'rider_id': null,
      'assigned_at': null,
      'assignment_expires_at': null,
      'accepted_at': null,
      'picked_up_at': null,
      'delivered_at': null,
      'dispatcher_id': null,
      'dispatched_at': null,
      'batch_id': null,
      'batch_window_start': null,
      'batch_window_end': null,
      'assignment_group_id': null,
      'cancelled_at': null,
      'cancelled_by': null,
      'cancellation_reason': null,
      'notes': null,
      'created_at': '2026-10-24T07:00:00+00:00',
      'updated_at': '2026-10-24T07:00:00+00:00',
      'deleted_at': null,
    };

Map<String, dynamic> _sendJson() => {
      ..._receiveJson(),
      'id': 2,
      'tracking_id': 'ODS-20261024-DEF456',
      'service_type': 'send',
      'recipient_name': 'Jane Customer',
      'recipient_phone': '0755123456',
    };

Map<String, dynamic> _regionalJson() => {
      ..._receiveJson(),
      'id': 3,
      'tracking_id': 'ODS-20261024-GHI789',
      'service_type': 'regional',
      'destination_region': 'Arusha',
      'destination_district': 'Arusha City',
      'destination_bus_stop': 'Nairobi Road Station',
      'recipient_name': 'John Arusha',
      'recipient_phone': '0762345678',
      'bus_cargo_fare': 3500.00,
      'total_amount': 5500.00, // 2000 ODS + 3500 transport
    };

void main() {
  // ─── Service type enum ────────────────────────────────────
  group('ServiceType', () {
    test('fromString maps all three services', () {
      expect(ServiceType.fromString('receive'), ServiceType.receive);
      expect(ServiceType.fromString('send'), ServiceType.send);
      expect(ServiceType.fromString('regional'), ServiceType.regional);
    });

    test('fromString falls back to receive on unknown', () {
      expect(ServiceType.fromString('unknown'), ServiceType.receive);
    });

    test('isLocal is true for receive and send, false for regional', () {
      expect(ServiceType.receive.isLocal, isTrue);
      expect(ServiceType.send.isLocal, isTrue);
      expect(ServiceType.regional.isLocal, isFalse);
    });

    test('displayLabel returns human-readable strings', () {
      expect(ServiceType.receive.displayLabel, 'Receive');
      expect(ServiceType.send.displayLabel, 'Send');
      expect(ServiceType.regional.displayLabel, 'Regional');
    });

    test('name serializes to the backend snake_case', () {
      expect(ServiceType.receive.name, 'receive');
      expect(ServiceType.send.name, 'send');
      expect(ServiceType.regional.name, 'regional');
    });
  });

  // ─── Delivery status enum ─────────────────────────────────
  group('DeliveryStatus', () {
    test('fromString maps all 11 statuses', () {
      const values = [
        'pending_payment', 'paid', 'batched', 'assigned', 'accepted',
        'picked_up', 'dispatched', 'delivered', 'cancelled', 'failed',
        'expired',
      ];
      for (final v in values) {
        final parsed = DeliveryStatus.fromString(v);
        expect(parsed.name, v,
            reason: 'Status $v should map to ${parsed.name}');
        expect(parsed, isNot(DeliveryStatus.unknown));
      }
    });

    test('fromString returns unknown for unrecognized status', () {
      expect(DeliveryStatus.fromString('refunded'), DeliveryStatus.unknown);
      expect(DeliveryStatus.fromString(''), DeliveryStatus.unknown);
    });

    test('isTerminal covers delivered, cancelled, failed, expired', () {
      expect(DeliveryStatus.delivered.isTerminal, isTrue);
      expect(DeliveryStatus.cancelled.isTerminal, isTrue);
      expect(DeliveryStatus.failed.isTerminal, isTrue);
      expect(DeliveryStatus.expired.isTerminal, isTrue);
      expect(DeliveryStatus.paid.isTerminal, isFalse);
      expect(DeliveryStatus.assigned.isTerminal, isFalse);
    });

    test('isInProgress is complement of isTerminal', () {
      for (final s in DeliveryStatus.values) {
        expect(s.isInProgress, !s.isTerminal,
            reason: '${s.name} has inconsistent terminal/progress flags');
      }
    });

    test('isPaid is true for anything past pending_payment', () {
      expect(DeliveryStatus.pending_payment.isPaid, isFalse);
      expect(DeliveryStatus.paid.isPaid, isTrue);
      expect(DeliveryStatus.assigned.isPaid, isTrue);
      expect(DeliveryStatus.delivered.isPaid, isTrue);
      // Note: a cancelled delivery is "paid" if cancellation happened
      // after payment — the enum can't know that, so it stays true.
      expect(DeliveryStatus.cancelled.isPaid, isTrue);
    });

    test('hasRider is true for assigned and later (excluding terminal)', () {
      expect(DeliveryStatus.assigned.hasRider, isTrue);
      expect(DeliveryStatus.accepted.hasRider, isTrue);
      expect(DeliveryStatus.picked_up.hasRider, isTrue);
      expect(DeliveryStatus.dispatched.hasRider, isTrue);
      expect(DeliveryStatus.paid.hasRider, isFalse);
      expect(DeliveryStatus.batched.hasRider, isFalse);
    });

    test('isInTransit only for picked_up and dispatched', () {
      expect(DeliveryStatus.picked_up.isInTransit, isTrue);
      expect(DeliveryStatus.dispatched.isInTransit, isTrue);
      expect(DeliveryStatus.assigned.isInTransit, isFalse);
      expect(DeliveryStatus.delivered.isInTransit, isFalse);
    });

    test('displayLabel returns human-readable text', () {
      expect(DeliveryStatus.pending_payment.displayLabel, 'Awaiting payment');
      expect(DeliveryStatus.delivered.displayLabel, 'Delivered');
      expect(DeliveryStatus.dispatched.displayLabel, 'Dispatched');
      expect(DeliveryStatus.unknown.displayLabel, 'Unknown');
    });
  });

  // ─── Delivery.fromJson ────────────────────────────────────
  group('Delivery.fromJson — Receive', () {
    test('parses all core fields', () {
      final d = Delivery.fromJson(_receiveJson());

      expect(d.id, 1);
      expect(d.trackingId, 'ODS-20261024-ABC123');
      expect(d.distributorId, 42);
      expect(d.pickupBranchId, 5);
      expect(d.serviceType, ServiceType.receive);
      expect(d.status, DeliveryStatus.paid);
      expect(d.rawStatus, 'paid');
      expect(d.isReceive, isTrue);
      expect(d.isLocal, isTrue);
      expect(d.isRegional, isFalse);
    });

    test('parses pricing snapshot', () {
      final d = Delivery.fromJson(_receiveJson());

      expect(d.distanceKm, 3.2);
      expect(d.ratePerKm, 500.0);
      expect(d.minimumFee, 1000.0);
      expect(d.roundingIncrement, 500);
      expect(d.calculatedFee, 1600.0);
      expect(d.odsDeliveryFee, 2000.0);
      expect(d.busCargoFare, isNull);
      expect(d.discountAmount, 0.0);
      expect(d.totalAmount, 2000.0);
      expect(d.currency, 'TZS');
    });

    test('null rider/dispatcher/timestamps on unpaid delivery', () {
      final d = Delivery.fromJson(_receiveJson());
      expect(d.riderId, isNull);
      expect(d.assignedAt, isNull);
      expect(d.deliveredAt, isNull);
      expect(d.dispatcherId, isNull);
    });

    test('recipient fields are null for Receive service', () {
      final d = Delivery.fromJson(_receiveJson());
      expect(d.recipientName, isNull);
      expect(d.recipientPhone, isNull);
    });
  });

  group('Delivery.fromJson — Send', () {
    test('has recipient details', () {
      final d = Delivery.fromJson(_sendJson());
      expect(d.isSend, isTrue);
      expect(d.isLocal, isTrue);
      expect(d.recipientName, 'Jane Customer');
      expect(d.recipientPhone, '0755123456');
    });

    test('has same pricing shape as Receive', () {
      final d = Delivery.fromJson(_sendJson());
      expect(d.odsDeliveryFee, 2000.0);
      expect(d.busCargoFare, isNull);
      expect(d.totalAmount, 2000.0);
    });
  });

  group('Delivery.fromJson — Regional', () {
    test('has destination region and bus stop', () {
      final d = Delivery.fromJson(_regionalJson());
      expect(d.isRegional, isTrue);
      expect(d.isLocal, isFalse);
      expect(d.destinationRegion, 'Arusha');
      expect(d.destinationDistrict, 'Arusha City');
      expect(d.destinationBusStop, 'Nairobi Road Station');
    });

    test('has both ODS fee and bus fare', () {
      final d = Delivery.fromJson(_regionalJson());
      expect(d.odsDeliveryFee, 2000.0);
      expect(d.busCargoFare, 3500.0);
      expect(d.totalAmount, 5500.0);
    });

    test('feeSummaryLabel shows both components for regional', () {
      final d = Delivery.fromJson(_regionalJson());
      expect(d.feeSummaryLabel, 'TZS 2000 + 3500 transport');
    });
  });

  // ─── Status helpers on Delivery ───────────────────────────
  group('Delivery status helpers delegate to enum', () {
    test('isDelivered, isCancelled, isActive', () {
      final paid = Delivery.fromJson(_receiveJson()..['status'] = 'paid');
      expect(paid.isDelivered, isFalse);
      expect(paid.isCancelled, isFalse);
      expect(paid.isActive, isTrue);
      expect(paid.isPaid, isTrue);

      final delivered =
          Delivery.fromJson(_receiveJson()..['status'] = 'delivered');
      expect(delivered.isDelivered, isTrue);
      expect(delivered.isActive, isFalse);

      final cancelled =
          Delivery.fromJson(_receiveJson()..['status'] = 'cancelled');
      expect(cancelled.isCancelled, isTrue);
      expect(cancelled.isActive, isFalse);
    });
  });

  // ─── Unknown status ───────────────────────────────────────
  group('Delivery with unknown status', () {
    test('status falls back to unknown but rawStatus preserved', () {
      final d = Delivery.fromJson(_receiveJson()..['status'] = 'refunded');
      expect(d.status, DeliveryStatus.unknown);
      expect(d.rawStatus, 'refunded');
      expect(d.isActive, isTrue); // unknown is not terminal
    });

    test('toJson writes back the raw status, not "unknown"', () {
      final d = Delivery.fromJson(_receiveJson()..['status'] = 'refunded');
      expect(d.toJson()['status'], 'refunded');
    });
  });

  // ─── Items ────────────────────────────────────────────────
  group('Delivery items', () {
    test('null items when response omits the field', () {
      final d = Delivery.fromJson(_receiveJson());
      expect(d.items, isNull);
    });

    test('parses items array when present', () {
      final json = _receiveJson()
        ..['items'] = [
          {
            'id': 1,
            'delivery_id': 1,
            'exgo_order_id': null,
            'product_name': 'Salmon Oil',
            'product_code': 'SLM-001',
            'quantity': 2,
            'notes': null,
            'sort_order': 0,
            'created_at': '2026-10-24T07:00:00+00:00',
            'updated_at': '2026-10-24T07:00:00+00:00',
          },
          {
            'id': 2,
            'delivery_id': 1,
            'exgo_order_id': null,
            'product_name': 'Cal-Mag',
            'product_code': 'CLM-002',
            'quantity': 1,
            'notes': null,
            'sort_order': 1,
            'created_at': '2026-10-24T07:00:00+00:00',
            'updated_at': '2026-10-24T07:00:00+00:00',
          },
        ];
      final d = Delivery.fromJson(json);
      expect(d.items, isNotNull);
      expect(d.items!.length, 2);
      expect(d.items!.first.productName, 'Salmon Oil');
    });

    test('empty items array parses as []', () {
      final json = _receiveJson()..['items'] = <Map<String, dynamic>>[];
      final d = Delivery.fromJson(json);
      expect(d.items, isNotNull);
      expect(d.items!.isEmpty, isTrue);
    });
  });

  // ─── Integer-as-decimal defensive parsing ─────────────────
  group('Delivery defensive numeric parsing', () {
    test('accepts integer values for decimal fields', () {
      final json = _receiveJson()
        ..['distance_km'] = 3
        ..['rate_per_km'] = 500
        ..['total_amount'] = 2000;
      final d = Delivery.fromJson(json);
      expect(d.distanceKm, 3.0);
      expect(d.ratePerKm, 500.0);
      expect(d.totalAmount, 2000.0);
    });

    test('accepts string values for numeric ids', () {
      final json = _receiveJson()
        ..['id'] = '1'
        ..['distributor_id'] = '42'
        ..['pickup_branch_id'] = '5';
      final d = Delivery.fromJson(json);
      expect(d.id, 1);
      expect(d.distributorId, 42);
      expect(d.pickupBranchId, 5);
    });
  });

  // ─── Round-trip ───────────────────────────────────────────
  group('Delivery round-trip', () {
    test('receive: fromJson → toJson → fromJson preserves fields', () {
      final original = Delivery.fromJson(_receiveJson());
      final roundtripped = Delivery.fromJson(original.toJson());

      expect(roundtripped.id, original.id);
      expect(roundtripped.trackingId, original.trackingId);
      expect(roundtripped.serviceType, original.serviceType);
      expect(roundtripped.status, original.status);
      expect(roundtripped.odsDeliveryFee, original.odsDeliveryFee);
      expect(roundtripped.totalAmount, original.totalAmount);
    });

    test('regional: preserves bus cargo fare across round-trip', () {
      final original = Delivery.fromJson(_regionalJson());
      final roundtripped = Delivery.fromJson(original.toJson());

      expect(roundtripped.isRegional, isTrue);
      expect(roundtripped.busCargoFare, original.busCargoFare);
      expect(roundtripped.destinationRegion, original.destinationRegion);
      expect(roundtripped.destinationBusStop, original.destinationBusStop);
    });
  });

  // ─── Display helpers ──────────────────────────────────────
  group('Delivery display helpers', () {
    test('shortLabel shows service and tracking id', () {
      final d = Delivery.fromJson(_receiveJson());
      expect(d.shortLabel, 'Receive · ODS-20261024-ABC123');
    });

    test('totalAmountLabel handles null', () {
      final d = Delivery.fromJson(_receiveJson()..['total_amount'] = null);
      expect(d.totalAmountLabel, '—');
    });

    test('totalAmountLabel formats with currency', () {
      final d = Delivery.fromJson(_receiveJson());
      expect(d.totalAmountLabel, 'TZS 2000');
    });

    test('feeSummaryLabel for receive shows total only', () {
      final d = Delivery.fromJson(_receiveJson());
      expect(d.feeSummaryLabel, 'TZS 2000');
    });

    test('feeSummaryLabel for regional splits ODS vs transport', () {
      final d = Delivery.fromJson(_regionalJson());
      expect(d.feeSummaryLabel, 'TZS 2000 + 3500 transport');
    });
  });
}