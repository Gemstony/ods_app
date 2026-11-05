import 'package:dio/dio.dart';
import 'package:ods_app/data/models/manager_dashboard_kpis.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../models/dashboard_kpis.dart';
import '../models/distributor_dashboard_kpis.dart';
import '../models/rider_dashboard_kpis.dart';

/// Fetches dashboard KPIs, one method per role.
///
/// Backend `role:*` middleware enforces the role — non-matching calls
/// surface as 403. Each method unwraps the standard `{ success, data }`
/// envelope and hands the inner map to the role-specific model.
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

  /// GET /distributor/dashboard
  Future<ApiResult<DistributorDashboardKpis>> getDistributorKpis() {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/distributor/dashboard',
      );

      final body = response.data;
      if (body == null) throw StateError('Empty response body');
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('Unexpected envelope shape: $body');
      }

      return DistributorDashboardKpis.fromJson(data);
    });
  }

  /// GET /manager/dashboard
  Future<ApiResult<ManagerDashboardKpis>> getManagerKpis() {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/manager/dashboard',
      );

      final body = response.data;
      if (body == null) throw StateError('Empty response body');
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('Unexpected envelope shape: $body');
      }

      return ManagerDashboardKpis.fromJson(data);
    });
  }

  /// GET /rider/dashboard
  Future<ApiResult<RiderDashboardKpis>> getRiderKpis() {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/rider/dashboard',
      );

      final body = response.data;
      if (body == null) throw StateError('Empty response body');
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('Unexpected envelope shape: $body');
      }

      return RiderDashboardKpis.fromJson(data);
    });
  }
}