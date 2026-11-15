import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_result.dart';
import '../models/payment.dart';

class PaymentRepository {
  final Dio _dio;

  PaymentRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

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

  /// POST /distributor/payments/manual
  ///
  /// Records a manual payment (cash / manual). Delivery stays
  /// `pending_payment` until a Manager approves.
  Future<ApiResult<Payment>> manual({
    required int deliveryId,
    required String method, // 'cash' | 'manual'
    PaymentStage stage = PaymentStage.full,
    String? notes,
  }) {
    return ApiResult.guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.distributorPaymentsManual,
        data: {
          'delivery_id': deliveryId,
          'method': method,
          'stage': stage.name,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      return Payment.fromJson(_extractData(response));
    });
  }

  Future<ApiResult<Payment>> show(int paymentId) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '${ApiEndpoints.distributorPayments}/$paymentId',
      );
      return Payment.fromJson(_extractData(response));
    });
  }

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