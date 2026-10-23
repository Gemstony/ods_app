import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_result.dart';

/// Minimal repository that pings `GET /api/v1/health`.
///
/// Its job right now is to prove the full stack works:
///   Dio (with interceptors) → ApiResult.guard → UI
///
/// Once Sub-phase 1.10 lights up the Laravel backend, this method will
/// return an `ApiSuccess` with `{app, version, env, database, time}`.
/// Until then, it returns a mapped `ApiFailure` (network / server) — which
/// is itself a valid verification of the error pipeline.
class HealthRepository {
  final Dio _dio;

  HealthRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  Future<ApiResult<Map<String, dynamic>>> check() {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.health,
      );

      final body = response.data;
      if (body == null || body['data'] is! Map) {
        throw StateError('Unexpected /health response shape: $body');
      }

      return Map<String, dynamic>.from(body['data'] as Map);
    });
  }
}