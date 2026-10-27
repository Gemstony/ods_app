import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/network/api_interceptors.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/models/payment.dart';
import 'package:ods_app/data/repositories/payment_repository.dart';

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

Map<String, dynamic> _paymentJson({
  int id = 1,
  String stage = 'full',
  String status = 'pending',
  String reference = 'PAY-20261024-ABC123',
  double amount = 2000.00,
  String? providerReference,
  String? paidAt,
}) =>
    {
      'id': id,
      'delivery_id': 100,
      'stage': stage,
      'amount': amount,
      'currency': 'TZS',
      'method': 'clickpesa',
      'status': status,
      'reference': reference,
      'provider_reference': providerReference,
      'initiated_by': 42,
      'initiated_at': '2026-10-24T07:00:00+00:00',
      'paid_at': paidAt,
      'failed_at': null,
      'expires_at': null,
      'failure_reason': null,
      'metadata': null,
      'created_at': '2026-10-24T07:00:00+00:00',
      'updated_at': '2026-10-24T07:00:00+00:00',
    };

Map<String, dynamic> _successEnvelope(Map<String, dynamic> data) => {
      'success': true,
      'message': 'OK',
      'data': data,
    };

void main() {
  // ─── initiate() ────────────────────────────────────────────
  group('PaymentRepository.initiate', () {
    test('sends POST with delivery id and stage, returns payment', () async {
      final adapter = _CapturingAdapter(
        statusCode: 201,
        body: _successEnvelope(_paymentJson()),
      );
      final repo = PaymentRepository(dio: _dioWith(adapter));

      final result = await repo.initiate(deliveryId: 100);

      expect(result, isA<ApiSuccess<Payment>>());
      expect(result.dataOrNull!.status, PaymentStatus.pending);
      expect(result.dataOrNull!.amount, 2000.0);
      expect(adapter.lastRequest!.path, '/payments/initiate');
      expect(adapter.lastRequest!.method, 'POST');

      final sent = adapter.lastRequest!.data as Map<String, dynamic>;
      expect(sent['delivery_id'], 100);
      expect(sent['stage'], 'full');
      // Amount must NOT be sent — server computes it
      expect(sent.containsKey('amount'), isFalse);
    });

    test('sends regional stage correctly', () async {
      final adapter = _CapturingAdapter(
        statusCode: 201,
        body: _successEnvelope(_paymentJson(
          stage: 'transport_fare',
          amount: 3500.00,
        )),
      );
      final repo = PaymentRepository(dio: _dioWith(adapter));

      final result = await repo.initiate(
        deliveryId: 100,
        stage: PaymentStage.transport_fare,
      );

      final sent = adapter.lastRequest!.data as Map<String, dynamic>;
      expect(sent['stage'], 'transport_fare');
      expect(result.dataOrNull!.stage, PaymentStage.transport_fare);
      expect(result.dataOrNull!.amount, 3500.0);
    });

    test('maps 422 to validation failure', () async {
      final adapter = _CapturingAdapter(
        statusCode: 422,
        body: {
          'success': false,
          'message': 'Validation failed.',
          'errors': {
            'delivery_id': ['The delivery must be in pending_payment status.'],
          },
        },
      );
      final repo = PaymentRepository(dio: _dioWith(adapter));

      final result = await repo.initiate(deliveryId: 999);

      expect(result, isA<ApiFailure>());
      expect(
        result.failureOrNull!.fieldErrors['delivery_id'],
        contains('The delivery must be in pending_payment status.'),
      );
    });
  });

  // ─── status() ──────────────────────────────────────────────
  group('PaymentRepository.status', () {
    test('polls the payment reference', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope(_paymentJson(
          status: 'completed',
          providerReference: 'CP-REF-999',
          paidAt: '2026-10-24T07:02:00+00:00',
        )),
      );
      final repo = PaymentRepository(dio: _dioWith(adapter));

      final result = await repo.status('PAY-20261024-ABC123');

      expect(result, isA<ApiSuccess<Payment>>());
      expect(result.dataOrNull!.status, PaymentStatus.completed);
      expect(result.dataOrNull!.isCompleted, isTrue);
      expect(result.dataOrNull!.providerReference, 'CP-REF-999');
      expect(
        adapter.lastRequest!.path,
        '/payments/PAY-20261024-ABC123/status',
      );
      expect(adapter.lastRequest!.method, 'GET');
    });

    test('returns failed payment state', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope(_paymentJson(status: 'failed')),
      );
      final repo = PaymentRepository(dio: _dioWith(adapter));

      final result = await repo.status('PAY-ABC');

      expect(result.dataOrNull!.isFailed, isTrue);
    });

    test('maps 404 to notFound failure', () async {
      final adapter = _CapturingAdapter(
        statusCode: 404,
        body: {
          'success': false,
          'message': 'Payment not found.',
          'errors': null,
        },
      );
      final repo = PaymentRepository(dio: _dioWith(adapter));

      final result = await repo.status('PAY-UNKNOWN');

      expect(result.failureOrNull!.type.name, 'notFound');
    });
  });

  // ─── listForDelivery() ─────────────────────────────────────
  group('PaymentRepository.listForDelivery', () {
    test('sends delivery_id query param and parses list', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope({
          'data': [
            _paymentJson(id: 1, stage: 'ods_fee', amount: 2000.00),
            _paymentJson(id: 2, stage: 'transport_fare', amount: 3500.00),
          ],
        }),
      );
      final repo = PaymentRepository(dio: _dioWith(adapter));

      final result = await repo.listForDelivery(100);

      expect(result, isA<ApiSuccess<List<Payment>>>());
      final payments = result.dataOrNull!;
      expect(payments.length, 2);
      expect(payments[0].stage, PaymentStage.ods_fee);
      expect(payments[1].stage, PaymentStage.transport_fare);
      expect(adapter.lastRequest!.path, '/payments');
      expect(adapter.lastRequest!.queryParameters, {'delivery_id': 100});
    });

    test('returns empty list when no payments exist', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope({'data': <Map<String, dynamic>>[]}),
      );
      final repo = PaymentRepository(dio: _dioWith(adapter));

      final result = await repo.listForDelivery(100);

      expect(result.dataOrNull, isEmpty);
    });
  });
}