import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_result.dart';
import '../models/auth/auth_user.dart';

/// Read-only user listing for owner-facing pickers.
///
/// Phase 5.5 only needs `list()` — used by the manager picker on the
/// assign-manager sheet. Phase 5.6 extends this with `create()`,
/// `update()`, `approve()`, `updateStatus()`, `resetPassword()`.
class UserRepository {
  final Dio _dio;

  UserRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  /// GET /owner/users
  ///
  /// Supports role / status / branch_id / search filters and pagination.
  /// Returns `data.data` as [AuthUser] — the wire shape matches
  /// `/auth/me` exactly (same `UserResource` transformer on the backend).
  Future<ApiResult<List<AuthUser>>> list({
    String? role,
    String? status,
    int? branchId,
    String? search,
    int? perPage,
    int page = 1,
  }) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.ownerUsers,
        queryParameters: {
          if (role != null) 'role': role,
          if (status != null) 'status': status,
          if (branchId != null) 'branch_id': branchId,
          if (search != null) 'search': search,
          if (perPage != null) 'per_page': perPage,
          'page': page,
        },
      );

      final body = response.data;
      if (body == null) throw StateError('Empty response body');
      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) {
        throw StateError('Unexpected envelope shape: $body');
      }
      final raw = data['data'];
      if (raw is! List) {
        throw StateError('Expected list in data, got ${raw.runtimeType}');
      }

      return raw
          .whereType<Map>()
          .map((j) => AuthUser.fromJson(Map<String, dynamic>.from(j)))
          .toList(growable: false);
    });
  }
}