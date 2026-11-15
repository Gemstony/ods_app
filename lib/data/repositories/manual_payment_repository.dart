import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_result.dart';
import '../models/manager_manual_payment.dart';

/// Manager + Owner manual payment approval endpoints (Phase 13.7).
///
/// Both roles hit the same wire shape with different base paths:
///   - Manager: `/manager/payments/pending` + `/{id}/approve` + `/{id}/reject`
///   - Owner:   `/owner/payments/pending`   + `/{id}/approve` + `/{id}/reject`
class ManualPaymentRepository {
  final Dio _dio;

  ManualPaymentRepository({Dio? dio})
      : _dio = dio ?? ApiClient.instance.dio;

  /// GET /{manager|owner}/payments/pending
  Future<ApiResult<List<ManagerManualPayment>>> listPending({
    bool forOwner = false,
    int perPage = 20,
    int page = 1,
  }) {
    return ApiResult.guard(() async {
      final base = forOwner
          ? ApiEndpoints.ownerPayments
          : ApiEndpoints.managerPayments;

      final response = await _dio.get<Map<String, dynamic>>(
        '$base/pending',
        queryParameters: {
          'per_page': perPage,
          'page': page,
        },
      );

      final body = response.data;
      if (body == null) throw StateError('Empty response body');
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('Unexpected envelope shape: $body');
      }
      final raw = data['data'];
      if (raw is! List) {
        throw StateError('Expected list in data, got ${raw.runtimeType}');
      }
      return raw
          .whereType<Map>()
          .map((j) => ManagerManualPayment.fromJson(
                Map<String, dynamic>.from(j),
              ))
          .toList(growable: false);
    });
  }

  /// POST /{manager|owner}/payments/{id}/approve
  Future<ApiResult<void>> approve({
    required int paymentId,
    bool forOwner = false,
  }) {
    return ApiResult.guard(() async {
      final base = forOwner
          ? ApiEndpoints.ownerPayments
          : ApiEndpoints.managerPayments;

      final response = await _dio.post<Map<String, dynamic>>(
        '$base/$paymentId/approve',
      );

      _assertSuccess(response);
    });
  }

  /// POST /{manager|owner}/payments/{id}/reject
  Future<ApiResult<void>> reject({
    required int paymentId,
    required String reason,
    bool forOwner = false,
  }) {
    return ApiResult.guard(() async {
      final base = forOwner
          ? ApiEndpoints.ownerPayments
          : ApiEndpoints.managerPayments;

      final response = await _dio.post<Map<String, dynamic>>(
        '$base/$paymentId/reject',
        data: {'reason': reason},
      );

      _assertSuccess(response);
    });
  }

  // ─── Envelope helper ────────────────────────────────────
  void _assertSuccess(Response<Map<String, dynamic>> response) {
    final body = response.data;
    if (body == null) throw StateError('Empty response body');
    if (body['success'] != true) {
      throw StateError(
        (body['message'] as String?) ?? 'Request failed',
      );
    }
  }
}