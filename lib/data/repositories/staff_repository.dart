import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_result.dart';
import '../models/auth/auth_user.dart';
import '../models/create_user_input.dart';

/// Manager's staff management for their own branch.
///
/// All endpoints are scoped to `manager.branch_id` on the backend —
/// cross-branch access returns 404 (not 403) so branch existence isn't
/// leaked. See `App\Http\Controllers\Api\V1\Manager\ManagerStaffController`
/// in Phase 6.1 for the server-side contract.
///
/// Staff = Receivers and Riders only. Manager cannot create another
/// Manager or an Owner; the backend returns 422 if `role` is anything
/// else.
class StaffRepository {
  final Dio _dio;

  StaffRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  // ─── List ─────────────────────────────────────────────────
  Future<ApiResult<List<AuthUser>>> list({
    String? role,
    String? status,
    String? search,
    int? perPage,
    int page = 1,
  }) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.managerStaff,
        queryParameters: {
          if (role != null) 'role': role,
          if (status != null) 'status': status,
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
        '${ApiEndpoints.managerStaff}/$id',
      );
      return AuthUser.fromJson(_extractData(response));
    });
  }

  // ─── Create ───────────────────────────────────────────────
  ///
  /// The [CreateUserInput] must have `role` set to `receiver` or `rider`.
  /// `branchId` is left null — the server forces it to the manager's
  /// branch.
  Future<ApiResult<AuthUser>> create(CreateUserInput input) {
    return ApiResult.guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.managerStaff,
        data: input.toJson(),
      );
      return AuthUser.fromJson(_extractData(response));
    });
  }

  // ─── Update ───────────────────────────────────────────────
  ///
  /// Password changes are NOT part of update — use [resetPassword].
  /// Only `name`, `phone`, and role-specific fields are mutable here.
  Future<ApiResult<AuthUser>> update(
    int id, {
    required String name,
    required String phone,
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
        '${ApiEndpoints.managerStaff}/$id',
        data: {
          'name': name,
          'phone': phone,
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

  // ─── Status ───────────────────────────────────────────────
  /// `active` | `suspended` | `deactivated`.
  Future<ApiResult<AuthUser>> updateStatus(int id, String status) {
    return ApiResult.guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '${ApiEndpoints.managerStaff}/$id/status',
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
        '${ApiEndpoints.managerStaff}/$id/reset-password',
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