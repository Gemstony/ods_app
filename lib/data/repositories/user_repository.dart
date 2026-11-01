import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_result.dart';
import '../models/auth/auth_user.dart';
import '../models/create_user_input.dart';

/// Owner-facing user management.
///
/// Covers: list (with filters), show, create, update, approve,
/// change status, reset password. All endpoints wrap in `role:owner`
/// middleware on the backend.
class UserRepository {
  final Dio _dio;

  UserRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  // ─── List ─────────────────────────────────────────────────
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

      return _extractList(response);
    });
  }

  // ─── Get one ──────────────────────────────────────────────
  Future<ApiResult<AuthUser>> get(int id) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '${ApiEndpoints.ownerUsers}/$id',
      );
      return AuthUser.fromJson(_extractData(response));
    });
  }

  // ─── Create ───────────────────────────────────────────────
  Future<ApiResult<AuthUser>> create(CreateUserInput input) {
    return ApiResult.guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.ownerUsers,
        data: input.toJson(),
      );
      return AuthUser.fromJson(_extractData(response));
    });
  }

  // ─── Update basic info ────────────────────────────────────
  ///
  /// Only mutable fields — email and role are immutable here.
  /// For Riders, always include all rider fields. For Receivers,
  /// `dispatcher_enabled` and `branch_id`. For Managers, `name` +
  /// `phone` only (branch change goes through assign-manager endpoint).
  Future<ApiResult<AuthUser>> update(
    int id, {
    required String name,
    required String phone,
    int? branchId,
    bool? dispatcherEnabled,
    String? nida,
    String? sex,
    String? dateOfBirth,
    String? vehicleType,
    String? vehicleColor,
    String? vehicleOwnership,
    String? plateNumber,
  }) {
    return ApiResult.guard(() async {
      final response = await _dio.put<Map<String, dynamic>>(
        '${ApiEndpoints.ownerUsers}/$id',
        data: {
          'name': name,
          'phone': phone,
          if (branchId != null) 'branch_id': branchId,
          if (dispatcherEnabled != null)
            'dispatcher_enabled': dispatcherEnabled,
          if (nida != null) 'nida': nida,
          if (sex != null) 'sex': sex,
          if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
          if (vehicleType != null) 'vehicle_type': vehicleType,
          if (vehicleColor != null) 'vehicle_color': vehicleColor,
          if (vehicleOwnership != null)
            'vehicle_ownership': vehicleOwnership,
          if (plateNumber != null) 'plate_number': plateNumber,
        },
      );
      return AuthUser.fromJson(_extractData(response));
    });
  }

  // ─── Approve pending account ──────────────────────────────
  Future<ApiResult<AuthUser>> approve(int id) {
    return ApiResult.guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '${ApiEndpoints.ownerUsers}/$id/approve',
      );
      return AuthUser.fromJson(_extractData(response));
    });
  }

  // ─── Change status ────────────────────────────────────────
  /// Valid transitions: active | suspended | deactivated.
  /// Pending → must use `approve()`.
  Future<ApiResult<AuthUser>> updateStatus(int id, String status) {
    return ApiResult.guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '${ApiEndpoints.ownerUsers}/$id/status',
        data: {'status': status},
      );
      return AuthUser.fromJson(_extractData(response));
    });
  }

  // ─── Reset password ───────────────────────────────────────
  Future<ApiResult<void>> resetPassword(
    int id, {
    required String password,
    required String passwordConfirmation,
  }) {
    return ApiResult.guard(() async {
      await _dio.post<Map<String, dynamic>>(
        '${ApiEndpoints.ownerUsers}/$id/reset-password',
        data: {
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );
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

  List<AuthUser> _extractList(Response<Map<String, dynamic>> response) {
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
        .map((j) => AuthUser.fromJson(Map<String, dynamic>.from(j)))
        .toList(growable: false);
  }
}