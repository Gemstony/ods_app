import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_result.dart';
import '../models/setting.dart';

/// Owner-facing settings management.
///
/// Methods:
///   list()               → GET /owner/settings, grouped by category
///   get(key)             → GET /owner/settings/{key}
///   updateOne(key, val)  → PUT /owner/settings/{key}
///   bulkUpdate(payload)  → PUT /owner/settings
class SettingsRepository {
  final Dio _dio;

  SettingsRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  Future<ApiResult<Map<String, List<Setting>>>> list() {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.ownerSettings,
      );

      final body = response.data;
      if (body == null) throw StateError('Empty response body');
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('Unexpected envelope shape: $body');
      }

      final grouped = <String, List<Setting>>{};
      data.forEach((category, items) {
        if (items is List) {
          grouped[category] = items
              .whereType<Map>()
              .map((j) => Setting.fromJson(Map<String, dynamic>.from(j)))
              .toList(growable: false);
        }
      });
      return grouped;
    });
  }

  Future<ApiResult<Setting>> get(String key) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '${ApiEndpoints.ownerSettings}/$key',
      );
      return Setting.fromJson(_extractData(response));
    });
  }

  Future<ApiResult<Setting>> updateOne(String key, dynamic value) {
    return ApiResult.guard(() async {
      final response = await _dio.put<Map<String, dynamic>>(
        '${ApiEndpoints.ownerSettings}/$key',
        data: {'value': value},
      );
      return Setting.fromJson(_extractData(response));
    });
  }

  /// Bulk update — atomic on the backend. Payload format:
  ///   {"settings": [{"key": "...", "value": ...}, ...]}
  Future<ApiResult<List<Setting>>> bulkUpdate(
    List<MapEntry<String, dynamic>> updates,
  ) {
    return ApiResult.guard(() async {
      final response = await _dio.put<Map<String, dynamic>>(
        ApiEndpoints.ownerSettings,
        data: {
          'settings': updates
              .map((e) => {'key': e.key, 'value': e.value})
              .toList(growable: false),
        },
      );

      final body = response.data;
      if (body == null) throw StateError('Empty response body');
      final data = body['data'];
      if (data is! List) {
        throw StateError('Unexpected envelope shape: $body');
      }
      return data
          .whereType<Map>()
          .map((j) => Setting.fromJson(Map<String, dynamic>.from(j)))
          .toList(growable: false);
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