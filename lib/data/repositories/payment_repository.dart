import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_result.dart';
import '../models/payment.dart';

/// Talks to `/api/v1/distributor/payments/*` (Phase 11.2 backend).
///
/// Flow:
///   1. `POST initiate` → backend creates Payment row, calls ClickPesa
///      to push a USSD prompt to the given phone.
///   2. `POST refresh` polls the current state — the backend queries
///      ClickPesa and applies any state transition.
///   3. When terminal (completed / failed), caller stops polling.
///
/// `GET show` is a lightweight read (no provider call) — useful for
/// rendering known state without touching ClickPesa.
class PaymentRepository {
  final Dio _dio;

  PaymentRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  /// POST /distributor/payments/initiate
  ///
  /// Client must NOT send an amount — the backend computes it from the
  /// delivery + PricingConfig. `phoneNumber` is optional; when absent the
  /// backend uses the authenticated distributor's account phone.
  Future<ApiResult<Payment>> initiate({
    required int deliveryId,
    String? phoneNumber,
    PaymentStage stage = PaymentStage.full,
  }) {
    return ApiResult.guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.distributorPaymentsInitiate,
        data: {
          'delivery_id': deliveryId,
          if (phoneNumber != null && phoneNumber.isNotEmpty)
            'phone_number': phoneNumber,
          'stage': stage.name,
        },
      );
      return Payment.fromJson(_extractData(response));
    });
  }

  /// GET /distributor/payments/{id}
  ///
  /// Read-only — never touches ClickPesa. Use for display.
  Future<ApiResult<Payment>> show(int paymentId) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '${ApiEndpoints.distributorPayments}/$paymentId',
      );
      return Payment.fromJson(_extractData(response));
    });
  }

  /// POST /distributor/payments/{id}/refresh
  ///
  /// Asks the backend to query ClickPesa and apply the current state.
  /// Safe to call repeatedly — the backend is idempotent per payment.
  Future<ApiResult<Payment>> refresh(int paymentId) {
    return ApiResult.guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '${ApiEndpoints.distributorPayments}/$paymentId/refresh',
      );
      return Payment.fromJson(_extractData(response));
    });
  }

  // ─── Envelope ────────────────────────────────────────────
  Map<String, dynamic> _extractData(Response<Map<String, dynamic>> response) {
    final body = response.data;
    if (body == null) throw StateError('Empty response body');
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw StateError('Unexpected envelope shape: $body');
    }
    return data;
  }
}