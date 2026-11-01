import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_result.dart';
import '../models/pricing_config.dart';

/// Singleton pricing configuration for the whole platform.
class PricingConfigRepository {
  final Dio _dio;

  PricingConfigRepository({Dio? dio})
      : _dio = dio ?? ApiClient.instance.dio;

  Future<ApiResult<PricingConfig>> get() {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.ownerPricingConfig,
      );
      return PricingConfig.fromJson(_extractData(response));
    });
  }

  /// Full replace. All 16 fields required.
  Future<ApiResult<PricingConfig>> update(PricingConfig newConfig) {
    return ApiResult.guard(() async {
      final response = await _dio.put<Map<String, dynamic>>(
        ApiEndpoints.ownerPricingConfig,
        data: newConfig.toUpdatePayload(),
      );
      return PricingConfig.fromJson(_extractData(response));
    });
  }

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