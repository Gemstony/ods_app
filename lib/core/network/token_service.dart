import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../utils/logger.dart';
import '../../data/local/secure_storage.dart';
import '../../data/models/auth/auth_login_result.dart';
import '../../data/models/auth/auth_tokens.dart';
import '../../data/models/auth/auth_user.dart';
import 'api_endpoints.dart';

/// Centralised token lifecycle: read, persist, clear, refresh.
///
/// Uses its own Dio instance (with **no interceptors**) for refresh calls.
/// That isolation guarantees no refresh-on-refresh recursion — the
/// RefreshInterceptor can never see its own refresh attempt.
///
/// Interceptors, `AuthRepository`, and `SessionNotifier` all delegate to
/// this class. One place to change the storage keys or the refresh
/// endpoint, one place to debug token state.
class TokenService {
  TokenService({
    required SecureStorageInterface storage,
    Dio? refreshDio,
  })  : _storage = storage,
        _refreshDio = refreshDio ?? _buildRefreshDio();

  final SecureStorageInterface _storage;
  final Dio _refreshDio;

  // Storage keys — mirrors 1.8's StorageKeys but scoped to this class.
  static const _kAccessToken  = 'ods.auth.access_token';
  static const _kRefreshToken = 'ods.auth.refresh_token';
  static const _kUserId       = 'ods.auth.user_id';
  static const _kRole         = 'ods.auth.role';
  static const _kDisplayName  = 'ods.auth.display_name';

  static Dio _buildRefreshDio() {
    return Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      validateStatus: (s) => s != null && s < 400,
    ));
  }

  // ─── Reads ─────────────────────────────────────────────────
  Future<String?> getAccessToken()  => _storage.read(_kAccessToken);
  Future<String?> getRefreshToken() => _storage.read(_kRefreshToken);

  // ─── Persistence ───────────────────────────────────────────
  Future<void> persistSession({
    required AuthUser user,
    required AuthTokens tokens,
  }) async {
    await _storage.write(_kAccessToken, tokens.accessToken);
    await _storage.write(_kRefreshToken, tokens.refreshToken);
    await _storage.write(_kUserId, user.id.toString());
    await _storage.write(_kRole, user.role);
    await _storage.write(_kDisplayName, user.name);
  }

  Future<void> clearTokens() async {
    await _storage.delete(_kAccessToken);
    await _storage.delete(_kRefreshToken);
    await _storage.delete(_kUserId);
    await _storage.delete(_kRole);
    await _storage.delete(_kDisplayName);
  }

    /// Returns the currently-stored access + refresh tokens as an
  /// [AuthTokens] object, or `null` if either is missing.
  ///
  /// The `expiresIn` field is a placeholder (3600) because the true value
  /// is only known at issue time and isn't needed by any code path that
  /// reads restored tokens. If a future screen needs accurate expiry, add
  /// a `ods.auth.access_expires_at` key and populate it on every
  /// `persistSession`.
  Future<AuthTokens?> getStoredTokens() async {
    final access = await getAccessToken();
    final refresh = await getRefreshToken();
    if (access == null || refresh == null) return null;
    return AuthTokens(
      accessToken: access,
      refreshToken: refresh,
      tokenType: 'bearer',
      expiresIn: 3600,
    );
  }

  // ─── Refresh ───────────────────────────────────────────────
  /// Attempts to rotate the token pair using the stored refresh token.
  ///
  /// Returns the new login result on success, or `null` on any failure
  /// (no refresh token stored, network error, 401 from the backend,
  /// unexpected envelope). The caller is responsible for persisting the
  /// new tokens — this method is purely a network operation.
  Future<AuthLoginResult?> refresh() async {
    final rawRefreshToken = await getRefreshToken();
    if (rawRefreshToken == null || rawRefreshToken.isEmpty) {
      return null;
    }

    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        ApiEndpoints.refresh,
        data: {'refresh_token': rawRefreshToken},
      );

      final body = response.data;
      if (body == null) return null;
      final data = body['data'];
      if (data is! Map<String, dynamic>) return null;

      return AuthLoginResult.fromJson(data);
    } catch (e, st) {
      AppLogger.w('Token refresh failed', error: e, stackTrace: st);
      return null;
    }
  }
}