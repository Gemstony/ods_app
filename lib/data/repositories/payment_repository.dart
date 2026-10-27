import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_result.dart';
import '../models/payment.dart';

/// Talks to every `/api/v1/payments/*` endpoint.
///
/// Flow (from the ODS document, Phase 11 implements the backend side):
///   1. Distributor creates a delivery in `pending_payment` status.
///   2. App calls [initiate] → server creates a Payment row and pushes a
///      ClickPesa USSD request to the distributor's phone.
///   3. App polls [status] every few seconds until the payment is
///      `completed` or `failed`.
///   4. When `completed`, the server updates the delivery to `paid`.
///
/// Regional deliveries use two stages (`ods_fee` and `transport_fare`).
/// Local deliveries use `full` only.
class PaymentRepository {
  final Dio _dio;

  PaymentRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  // ─── Initiate ─────────────────────────────────────────────
  /// POST /payments/initiate
  ///
  /// Starts the payment flow for [deliveryId] at the given [stage].
  /// The response carries the authoritative amount (computed by the
  /// server from `PricingConfig` + the delivery) and the reference the
  /// caller should poll with [status].
  ///
  /// The caller must not send an amount — the server ignores any
  /// client-supplied amount to prevent tampering.
  Future<ApiResult<Payment>> initiate({
    required int deliveryId,
    PaymentStage stage = PaymentStage.full,
  }) {
    return ApiResult.guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.paymentsInitiate,
        data: {
          'delivery_id': deliveryId,
          'stage': stage.name,
        },
      );

      return Payment.fromJson(_extractData(response));
    });
  }

  // ─── Poll status ──────────────────────────────────────────
  /// GET /payments/{reference}/status
  ///
  /// Fetches the current state of a payment by reference. Safe to call
  /// repeatedly — the backend is read-only for this endpoint and the
  /// ClickPesa webhook (Phase 11) is what actually transitions the state.
  ///
  /// A completed payment will also have had its delivery updated to
  /// `paid` server-side, so callers should re-fetch the delivery after
  /// seeing `status.isCompleted == true`.
  Future<ApiResult<Payment>> status(String reference) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '${ApiEndpoints.payments}/$reference/status',
      );

      return Payment.fromJson(_extractData(response));
    });
  }

  // ─── List for delivery ────────────────────────────────────
  /// GET /payments?delivery_id={id}
  ///
  /// Returns all payment attempts for a delivery. Useful on the delivery
  /// detail screen (Regional deliveries have two stages; failed attempts
  /// are also shown so the distributor can see what happened).
  Future<ApiResult<List<Payment>>> listForDelivery(int deliveryId) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.payments,
        queryParameters: {'delivery_id': deliveryId},
      );

      final data = _extractData(response);
      return _extractList(data, Payment.fromJson);
    });
  }

  // ─── Envelope helpers ────────────────────────────────────
  Map<String, dynamic> _extractData(Response<Map<String, dynamic>> response) {
    final body = response.data;
    if (body == null) throw StateError('Empty response body');
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw StateError('Unexpected envelope shape: $body');
    }
    return data;
  }

  List<T> _extractList<T>(
    Map<String, dynamic> data,
    T Function(Map<String, dynamic> json) itemFromJson,
  ) {
    final raw = data['data'] ?? data;
    if (raw is! List) {
      throw StateError('Expected list in data, got ${raw.runtimeType}');
    }
    return raw
        .whereType<Map>()
        .map((j) => itemFromJson(Map<String, dynamic>.from(j)))
        .toList(growable: false);
  }
}