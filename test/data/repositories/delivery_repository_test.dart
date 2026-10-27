import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/network/api_interceptors.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/models/delivery.dart';
import 'package:ods_app/data/models/delivery_input.dart';
import 'package:ods_app/data/repositories/delivery_repository.dart';

class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter({required this.statusCode, required this.body});
  final int statusCode;
  final Map<String, dynamic>? body;

  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(_CapturingAdapter adapter) {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:8000/api/v1',
    validateStatus: (s) => s != null && s < 400,
  ));
  dio.httpClientAdapter = adapter;
  dio.interceptors.add(ErrorMappingInterceptor());
  return dio;
}

Map<String, dynamic> _deliveryJson({
  int id = 1,
  String trackingId = 'ODS-20261024-ABC123',
  String serviceType = 'receive',
  String status = 'paid',
}) =>
    {
      'id': id,
      'tracking_id': trackingId,
      'distributor_id': 42,
      'pickup_branch_id': 5,
      'service_type': serviceType,
      'status': status,
      'pickup_address': '123 Kariakoo',
      'pickup_latitude': -6.79,
      'pickup_longitude': 39.20,
      'pickup_contact_phone': '0712345678',
      'destination_address': '456 Upanga',
      'destination_latitude': -6.78,
      'destination_longitude': 39.22,
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

Map<String, dynamic> _successEnvelope(Map<String, dynamic> data) => {
      'success': true,
      'message': 'OK',
      'data': data,
    };

void main() {
  // ─── listMine() ────────────────────────────────────────────
  group('DeliveryRepository.listMine', () {
    test('calls /distributor/deliveries with no filters', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope({
          'data': [_deliveryJson()],
        }),
      );
      final repo = DeliveryRepository(dio: _dioWith(adapter));

      final result = await repo.listMine();

      expect(result, isA<ApiSuccess<List<Delivery>>>());
      expect(result.dataOrNull!.length, 1);
      expect(adapter.lastRequest!.path, '/distributor/deliveries');
      expect(adapter.lastRequest!.method, 'GET');
    });

    test('sends status and service_type filters', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope({'data': <Map<String, dynamic>>[]}),
      );
      final repo = DeliveryRepository(dio: _dioWith(adapter));

      await repo.listMine(
        status: DeliveryStatus.delivered,
        serviceType: ServiceType.regional,
        limit: 10,
      );

      expect(adapter.lastRequest!.queryParameters, {
        'status': 'delivered',
        'service_type': 'regional',
        'limit': 10,
      });
    });

    test('returns empty list when no deliveries', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope({'data': <Map<String, dynamic>>[]}),
      );
      final repo = DeliveryRepository(dio: _dioWith(adapter));

      final result = await repo.listMine();

      expect(result.dataOrNull, isEmpty);
    });
  });

  // ─── getMine() ─────────────────────────────────────────────
  group('DeliveryRepository.getMine', () {
    test('calls /distributor/deliveries/{id}', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope(_deliveryJson(id: 42)),
      );
      final repo = DeliveryRepository(dio: _dioWith(adapter));

      final result = await repo.getMine(42);

      expect(result, isA<ApiSuccess<Delivery>>());
      expect(result.dataOrNull!.id, 42);
      expect(adapter.lastRequest!.path, '/distributor/deliveries/42');
    });

    test('maps 404 to notFound failure', () async {
      final adapter = _CapturingAdapter(
        statusCode: 404,
        body: {
          'success': false,
          'message': 'Delivery not found.',
          'errors': null,
        },
      );
      final repo = DeliveryRepository(dio: _dioWith(adapter));

      final result = await repo.getMine(999);

      expect(result.failureOrNull!.type.name, 'notFound');
    });
  });

  // ─── create() ──────────────────────────────────────────────
  group('DeliveryRepository.create', () {
    test('sends POST with serialized items and pickup info', () async {
      final adapter = _CapturingAdapter(
        statusCode: 201,
        body: _successEnvelope(_deliveryJson()),
      );
      final repo = DeliveryRepository(dio: _dioWith(adapter));

      final input = CreateDeliveryInput(
        serviceType: ServiceType.receive,
        pickupBranchId: 5,
        pickupContactPhone: '0712345678',
        destinationAddress: '456 Upanga',
        destinationLatitude: -6.78,
        destinationLongitude: 39.22,
        items: const [
          DeliveryItemInput(
            productName: 'Salmon Oil',
            productCode: 'SLM-001',
            quantity: 2,
          ),
          DeliveryItemInput(exgoOrderId: 'EXGO-12345'),
        ],
      );

      final result = await repo.create(input);

      expect(result, isA<ApiSuccess<Delivery>>());
      expect(adapter.lastRequest!.path, '/distributor/deliveries');
      expect(adapter.lastRequest!.method, 'POST');

      final sent = adapter.lastRequest!.data as Map<String, dynamic>;
      expect(sent['service_type'], 'receive');
      expect(sent['pickup_branch_id'], 5);
      expect(sent['pickup_contact_phone'], '0712345678');
      expect(sent['destination_address'], '456 Upanga');

      final items = sent['items'] as List;
      expect(items.length, 2);
      expect((items[0] as Map)['product_name'], 'Salmon Oil');
      expect((items[0] as Map)['quantity'], 2);
      expect((items[1] as Map)['exgo_order_id'], 'EXGO-12345');
      // EXGO item has no product fields — those keys must not be present
      expect((items[1] as Map).containsKey('product_name'), isFalse);
    });

    test('regional delivery payload includes destination region', () async {
      final adapter = _CapturingAdapter(
        statusCode: 201,
        body: _successEnvelope(_deliveryJson(serviceType: 'regional')),
      );
      final repo = DeliveryRepository(dio: _dioWith(adapter));

      final input = CreateDeliveryInput(
        serviceType: ServiceType.regional,
        pickupBranchId: 5,
        recipientName: 'Jane Doe',
        recipientPhone: '0755123456',
        destinationRegion: 'Arusha',
        destinationDistrict: 'Arusha City',
        destinationBusStop: 'Nairobi Road Station',
        items: const [
          DeliveryItemInput(
            productName: 'Full Motion',
            productCode: 'FLM-003',
            quantity: 1,
          ),
        ],
      );

      await repo.create(input);

      final sent = adapter.lastRequest!.data as Map<String, dynamic>;
      expect(sent['service_type'], 'regional');
      expect(sent['destination_region'], 'Arusha');
      expect(sent['destination_district'], 'Arusha City');
      expect(sent['destination_bus_stop'], 'Nairobi Road Station');
      expect(sent['recipient_name'], 'Jane Doe');
      expect(sent['recipient_phone'], '0755123456');
    });

    test('returns validation failure with field errors on 422', () async {
      final adapter = _CapturingAdapter(
        statusCode: 422,
        body: {
          'success': false,
          'message': 'Validation failed.',
          'errors': {
            'pickup_branch_id': ['The pickup branch is required.'],
          },
        },
      );
      final repo = DeliveryRepository(dio: _dioWith(adapter));

      final result = await repo.create(
        const CreateDeliveryInput(
          serviceType: ServiceType.receive,
          items: [DeliveryItemInput(productName: 'X', quantity: 1)],
        ),
      );

      expect(result, isA<ApiFailure>());
      expect(
        result.failureOrNull!.fieldErrors['pickup_branch_id'],
        contains('The pickup branch is required.'),
      );
    });
  });

  // ─── pricePreview() ────────────────────────────────────────
  group('DeliveryRepository.pricePreview', () {
    test('parses a local fee preview', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope({
          'service_type': 'receive',
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
        }),
      );
      final repo = DeliveryRepository(dio: _dioWith(adapter));

      final result = await repo.pricePreview(
        const PricePreviewInput(
          serviceType: ServiceType.receive,
          pickupBranchId: 5,
          destinationLatitude: -6.78,
          destinationLongitude: 39.22,
        ),
      );

      expect(result, isA<ApiSuccess<PricePreviewResult>>());
      final preview = result.dataOrNull!;
      expect(preview.distanceKm, 3.2);
      expect(preview.odsDeliveryFee, 2000.0);
      expect(preview.totalAmount, 2000.0);
      expect(preview.busCargoFare, isNull);
      expect(preview.isRegional, isFalse);
      expect(preview.hasDiscount, isFalse);
      expect(preview.totalLabel, 'TZS 2000');
      expect(preview.distanceLabel, '3.2 km');
      expect(preview.busFareLabel, isNull);
    });

    test('parses a regional fee preview with bus fare and discount',
        () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope({
          'service_type': 'regional',
          'distance_km': 500.0,
          'rate_per_km': 0.00,
          'minimum_fee': 0.00,
          'rounding_increment': 500,
          'calculated_fee': 2000.00,
          'ods_delivery_fee': 2000.00,
          'bus_cargo_fare': 3500.00,
          'discount_amount': 1000.00,
          'discount_reason': 'Tier 1 reward (50% off)',
          'total_amount': 4500.00,
          'currency': 'TZS',
        }),
      );
      final repo = DeliveryRepository(dio: _dioWith(adapter));

      final result = await repo.pricePreview(
        const PricePreviewInput(
          serviceType: ServiceType.regional,
          pickupBranchId: 5,
          destinationRegion: 'Arusha',
          applyReward: true,
        ),
      );

      final preview = result.dataOrNull!;
      expect(preview.isRegional, isTrue);
      expect(preview.busCargoFare, 3500.0);
      expect(preview.hasDiscount, isTrue);
      expect(preview.discountReason, 'Tier 1 reward (50% off)');
      expect(preview.busFareLabel, 'TZS 3500');
      expect(preview.totalAmount, 4500.0);
    });

    test('sends apply_reward flag in payload', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope({
          'service_type': 'receive',
          'distance_km': 1.0,
          'rate_per_km': 500,
          'minimum_fee': 1000,
          'rounding_increment': 500,
          'calculated_fee': 1000,
          'ods_delivery_fee': 1000,
          'bus_cargo_fare': null,
          'discount_amount': 500,
          'discount_reason': 'Reward',
          'total_amount': 500,
          'currency': 'TZS',
        }),
      );
      final repo = DeliveryRepository(dio: _dioWith(adapter));

      await repo.pricePreview(
        const PricePreviewInput(
          serviceType: ServiceType.receive,
          pickupBranchId: 5,
          destinationLatitude: -6.78,
          destinationLongitude: 39.22,
          applyReward: true,
        ),
      );

      final sent = adapter.lastRequest!.data as Map<String, dynamic>;
      expect(sent['apply_reward'], isTrue);
      expect(sent['service_type'], 'receive');
    });
  });

  // ─── listForBranch() ───────────────────────────────────────
  group('DeliveryRepository.listForBranch', () {
    test('calls /manager/deliveries', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope({
          'data': [_deliveryJson()],
        }),
      );
      final repo = DeliveryRepository(dio: _dioWith(adapter));

      final result = await repo.listForBranch(status: DeliveryStatus.paid);

      expect(result, isA<ApiSuccess<List<Delivery>>>());
      expect(adapter.lastRequest!.path, '/manager/deliveries');
      expect(adapter.lastRequest!.queryParameters['status'], 'paid');
    });
  });

  // ─── listForRider() ────────────────────────────────────────
  group('DeliveryRepository.listForRider', () {
    test('calls /rider/tasks with optional status', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope({
          'data': [_deliveryJson(status: 'assigned')],
        }),
      );
      final repo = DeliveryRepository(dio: _dioWith(adapter));

      final result = await repo.listForRider(status: DeliveryStatus.assigned);

      expect(result.dataOrNull!.first.status, DeliveryStatus.assigned);
      expect(adapter.lastRequest!.path, '/rider/tasks');
      expect(adapter.lastRequest!.queryParameters['status'], 'assigned');
    });
  });

  // ─── acceptTask() ──────────────────────────────────────────
  group('DeliveryRepository.acceptTask', () {
    test('sends PATCH and parses updated delivery', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope(_deliveryJson(status: 'accepted')),
      );
      final repo = DeliveryRepository(dio: _dioWith(adapter));

      final result = await repo.acceptTask(42);

      expect(result, isA<ApiSuccess<Delivery>>());
      expect(result.dataOrNull!.status, DeliveryStatus.accepted);
      expect(adapter.lastRequest!.path, '/rider/tasks/42/accept');
      expect(adapter.lastRequest!.method, 'PATCH');
    });
  });

  // ─── pickupTask() ──────────────────────────────────────────
  group('DeliveryRepository.pickupTask', () {
    test('sends PATCH and parses picked_up delivery', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope(_deliveryJson(status: 'picked_up')),
      );
      final repo = DeliveryRepository(dio: _dioWith(adapter));

      final result = await repo.pickupTask(42);

      expect(result.dataOrNull!.status, DeliveryStatus.picked_up);
      expect(adapter.lastRequest!.path, '/rider/tasks/42/pickup');
    });
  });

  // ─── deliverTask() ─────────────────────────────────────────
  group('DeliveryRepository.deliverTask', () {
    test('sends verification code with PATCH', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope(_deliveryJson(status: 'delivered')),
      );
      final repo = DeliveryRepository(dio: _dioWith(adapter));

      final result = await repo.deliverTask(
        id: 42,
        verificationCode: '123456',
      );

      expect(result.dataOrNull!.status, DeliveryStatus.delivered);
      expect(adapter.lastRequest!.path, '/rider/tasks/42/deliver');
      expect(adapter.lastRequest!.method, 'PATCH');
      final sent = adapter.lastRequest!.data as Map<String, dynamic>;
      expect(sent['verification_code'], '123456');
    });

    test('returns validation failure on wrong code (422)', () async {
      final adapter = _CapturingAdapter(
        statusCode: 422,
        body: {
          'success': false,
          'message': 'Validation failed.',
          'errors': {
            'verification_code': ['The verification code is invalid.'],
          },
        },
      );
      final repo = DeliveryRepository(dio: _dioWith(adapter));

      final result = await repo.deliverTask(
        id: 42,
        verificationCode: '999999',
      );

      expect(result, isA<ApiFailure>());
      expect(
        result.failureOrNull!.fieldErrors['verification_code'],
        contains('The verification code is invalid.'),
      );
    });
  });
}