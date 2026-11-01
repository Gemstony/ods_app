import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../models/dashboard_kpis.dart';

/// Fetches the Owner's dashboard KPIs.
///
/// Only the Owner role can access this endpoint — backend enforces via
/// `role:owner` middleware. Non-Owner calls will surface a 403.
class DashboardRepository {
  final Dio _dio;

  DashboardRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  /// GET /owner/dashboard
  Future<ApiResult<DashboardKpis>> getKpis() {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/owner/dashboard',
      );

      final body = response.data;
      if (body == null) throw StateError('Empty response body');
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('Unexpected envelope shape: $body');
      }

      return DashboardKpis.fromJson(data);
    });
  }
}