import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_result.dart';
import '../models/auth/auth_login_result.dart';
import '../models/auth/auth_user.dart';

/// Talks to every `/api/v1/auth/*` endpoint.
///
/// All methods return `ApiResult<T>` — success wraps the parsed model,
/// failure wraps the mapped `Failure` (already user-safe). The Dio
/// interceptor chain from 1.4 handles `DioException → AppException`, and
/// `ApiResult.guard` converts any escaped exception into a `Failure`.
///
/// Never catches exceptions itself — that's `ApiResult.guard`'s job.
class AuthRepository {
  final Dio _dio;

  AuthRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  // ─── Login ────────────────────────────────────────────────
  /// POST /auth/login
  ///
  /// Returns the user + tokens on success. On failure:
  ///   - 422 → `Failure.validation` with `fieldErrors`
  ///   - 401 → `Failure.client` with "Invalid email or password."
  ///   - 403 → `Failure.client` with the server's pending/suspended/deactivated message
  ///   - 429 → `Failure.client` with the rate-limit message
  Future<ApiResult<AuthLoginResult>> login({
    required String email,
    required String password,
  }) {
    return ApiResult.guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.login,
        data: {'email': email, 'password': password},
      );

      final data = _extractData(response);
      return AuthLoginResult.fromJson(data);
    });
  }

  // ─── Refresh ──────────────────────────────────────────────
  /// POST /auth/refresh
  ///
  /// Rotates the token pair. The caller is responsible for persisting the
  /// new tokens (Sub-phase 3.2 wires this into the interceptor chain).
  ///
  /// On failure (401 for invalid/expired/revoked token), the caller should
  /// treat the session as signed out.
  Future<ApiResult<AuthLoginResult>> refresh({
    required String refreshToken,
  }) {
    return ApiResult.guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.refresh,
        data: {'refresh_token': refreshToken},
      );

      final data = _extractData(response);
      return AuthLoginResult.fromJson(data);
    });
  }

  // ─── Logout (this device) ────────────────────────────────
  /// POST /auth/logout
  ///
  /// Revokes the given refresh token (if provided) and best-effort
  /// invalidates the current access token on the server.
  ///
  /// No client state changes here — the caller clears the session and
  /// secure storage after this succeeds.
  Future<ApiResult<void>> logout({String? refreshToken}) {
    return ApiResult.guard(() async {
      await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.logout,
        data: refreshToken == null
            ? const <String, dynamic>{}
            : {'refresh_token': refreshToken},
      );
    });
  }

  // ─── Logout (all devices) ────────────────────────────────
  /// POST /auth/logout-all
  ///
  /// Revokes every active refresh token for the current user.
  Future<ApiResult<void>> logoutAll() {
    return ApiResult.guard(() async {
      await _dio.post<Map<String, dynamic>>(ApiEndpoints.logoutAll);
    });
  }

  // ─── Me ───────────────────────────────────────────────────
  /// GET /auth/me
  ///
  /// Fetches the current user (permissions included). Used on startup to
  /// verify the persisted access token is still valid, and on manual
  /// profile refresh.
  Future<ApiResult<AuthUser>> me() {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(ApiEndpoints.me);
      final data = _extractData(response);
      return AuthUser.fromJson(data);
    });
  }

  // ─── Envelope extraction ──────────────────────────────────
  /// Validates the standard `{success, message, data}` envelope from the
  /// backend and returns `data`. Throws a descriptive `AppException` if
  /// the envelope is malformed — `ApiResult.guard` converts that to a
  /// `Failure.unknown`, which is what should happen.
  Map<String, dynamic> _extractData(Response<Map<String, dynamic>> response) {
    final body = response.data;
    if (body == null) {
      throw StateError('Empty response body');
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw StateError('Unexpected envelope shape: $body');
    }
    return data;
  }

  // ─── Register Distributor ─────────────────────────────────
  /// POST /auth/register/distributor
  ///
  /// Self-service registration. The created account is `pending` — the
  /// user cannot log in until an administrator approves it. The returned
  /// [AuthUser] reflects this (its `status` will be `pending`).
  ///
  /// On failure:
  ///   - 422 → `Failure.validation` with `fieldErrors` (duplicate email /
  ///           phone / distributor_id, weak password, mismatched confirm)
  ///   - 429 → `Failure.client` with the rate-limit message
  Future<ApiResult<AuthUser>> registerDistributor({
    required String name,
    required String distributorId,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
  }) {
    return ApiResult.guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.registerDistributor,
        data: {
          'name': name,
          'distributor_id': distributorId,
          'email': email,
          'phone': phone,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );

      final data = _extractData(response);
      return AuthUser.fromJson(data);
    });
  }
}
