import 'package:dio/dio.dart';

import '../errors/app_exception.dart';
import '../utils/logger.dart';
import 'token_service.dart';

// ─────────────────────────────────────────────────────────────────────
// Auth header interceptor
// ─────────────────────────────────────────────────────────────────────

/// Attaches the current bearer token to every outgoing request.
///
/// Skips auth-establishment endpoints (`/auth/login`, `/auth/register/*`,
/// `/auth/refresh`) — those don't need or want an existing token.
class AuthHeaderInterceptor extends Interceptor {
  AuthHeaderInterceptor(this._tokenService);

  final TokenService _tokenService;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final path = options.path;

    final isAuthEstablishmentPath = path.contains('/auth/login') ||
        path.contains('/auth/register/') ||
        path.contains('/auth/refresh');

    if (isAuthEstablishmentPath) {
      return handler.next(options);
    }

    final token = await _tokenService.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }
}

// ─────────────────────────────────────────────────────────────────────
// Refresh interceptor
// ─────────────────────────────────────────────────────────────────────

/// Catches auth failures on protected endpoints, refreshes the token pair
/// via [TokenService], and retries the original request once.
///
/// Detection is intentionally ordering-agnostic: it accepts EITHER
///   - a mapped `AppException` of type `auth` in `err.error` (if
///     `ErrorMappingInterceptor` ran before this one), OR
///   - a raw 401 / 403 status code (if it ran after).
/// This makes the interceptor correct under any Dio version's traversal
/// order (Dio 5.x differs from the docs).
///
/// Concurrency: single-flight lock — the first 401 starts a refresh,
/// subsequent 401s await the same Future. Exactly one HTTP call to
/// `/auth/refresh` per 401 storm.
///
/// On refresh failure, calls [onSessionExpired] so the app can clear state
/// and redirect to login. The original error is propagated to the caller.
class RefreshInterceptor extends Interceptor {
  RefreshInterceptor({
    required TokenService tokenService,
    required Dio dio,
    void Function()? onSessionExpired,
  })  : _tokenService = tokenService,
        _dio = dio,
        _onSessionExpired = onSessionExpired;

  final TokenService _tokenService;
  final Dio _dio;
  final void Function()? _onSessionExpired;

  /// Single-flight lock. Non-null while a refresh is in progress.
  Future<bool>? _refreshInFlight;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;

    // ─── Skip: refresh endpoint itself ────────────────────────
    // If /auth/refresh returns an error, the session is truly dead.
    // Don't recurse; let it propagate.
    if (options.path.contains('/auth/refresh')) {
      return handler.next(err);
    }

    // ─── Skip: already retried once ───────────────────────────
    if (options.extra[_kAuthRetriedKey] == true) {
      return handler.next(err);
    }

    // ─── Skip: auth-establishment endpoints ───────────────────
    // On /auth/login and /auth/register/*, a 401/403 means
    // "wrong credentials" or "email already registered" — NOT session
    // expiry. Refreshing would be pointless and would mask the real
    // error the UI needs to show.
    if (options.path.contains('/auth/login') ||
        options.path.contains('/auth/register/')) {
      return handler.next(err);
    }

    // ─── Detect auth error — mapped OR raw status ─────────────
    //
    // Depending on Dio's interceptor ordering (which varies between
    // versions and is the reverse of what the docs claim for Dio 5.x),
    // this interceptor may run before or after ErrorMappingInterceptor.
    //
    //   - If ErrorMapping ran first: err.error is an AppException.
    //   - If ErrorMapping ran after: err.error is null; the raw status
    //     code is still on err.response.
    //
    // Accept either signal. This makes the interceptor robust against
    // interceptor-ordering changes without relying on a specific order.
    final statusCode = err.response?.statusCode;
    final cause = err.error;
    final isMappedAuthError =
        cause is AppException && cause.type == AppExceptionType.auth;
    final isRawAuthError = statusCode == 401 || statusCode == 403;

    if (!(isMappedAuthError || isRawAuthError)) {
      return handler.next(err);
    }

    // ─── Attempt refresh (single-flight) ──────────────────────
    final refreshed = await _refreshSingleFlight();
    if (!refreshed) {
      _onSessionExpired?.call();
      return handler.next(err);
    }

    // ─── Retry the original request once ──────────────────────
    final newToken = await _tokenService.getAccessToken();
    if (newToken == null || newToken.isEmpty) {
      _onSessionExpired?.call();
      return handler.next(err);
    }

    final retryOptions = options.copyWith(
      headers: {
        ...options.headers,
        'Authorization': 'Bearer $newToken',
      },
      extra: {...options.extra, _kAuthRetriedKey: true},
    );

    try {
      // fetch() bypasses the interceptor chain → no infinite loop.
      final response = await _dio.fetch(retryOptions);
      return handler.resolve(response);
    } on DioException catch (e, st) {
      // Retry failed. If it 401'd again, our fresh token was rejected
      // server-side → treat as session dead.
      if (e.response?.statusCode == 401) {
        _onSessionExpired?.call();
      }
      // fetch() bypasses interceptors, so e.error is NOT an AppException.
      // Map the raw error so callers still see a typed error.
      final mapped = e.error is AppException
          ? e.error as AppException
          : ErrorMappingInterceptor.mapDioException(e);
      AppLogger.w(
        'Retry after refresh failed: ${mapped.message}',
        error: mapped,
        stackTrace: st,
      );
      return handler.next(DioException(
        requestOptions: e.requestOptions,
        response: e.response,
        type: e.type,
        error: mapped,
        stackTrace: e.stackTrace,
      ));
    } catch (e, st) {
      AppLogger.w('Retry after refresh threw', error: e, stackTrace: st);
      return handler.next(err);
    }
  }

  // ─── Single-flight refresh ─────────────────────────────────
  Future<bool> _refreshSingleFlight() {
    if (_refreshInFlight != null) {
      return _refreshInFlight!;
    }
    _refreshInFlight = _doRefresh();
    return _refreshInFlight!.whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _doRefresh() async {
    final result = await _tokenService.refresh();
    if (result == null) return false;

    await _tokenService.persistSession(
      user: result.user,
      tokens: result.tokens,
    );
    return true;
  }

  static const _kAuthRetriedKey = '_authRetried';
}

// ─────────────────────────────────────────────────────────────────────
// Error mapping interceptor
// ─────────────────────────────────────────────────────────────────────

/// Converts every [DioException] into an [AppException], so downstream
/// layers (repositories, `ApiResult.guard`) see one error type.
///
/// The mapped [AppException] is stored in [DioException.error] so
/// `ApiResult.guard` can catch it via its `on AppException` clause, and
/// so `RefreshInterceptor` can inspect `cause.type` (though it also
/// accepts raw status codes as a fallback — see that class).
///
/// Uses `handler.next()` rather than `handler.reject()` so the mapped
/// error continues through any subsequent interceptor instead of
/// short-circuiting the chain.
class ErrorMappingInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final appException = mapDioException(err);

    AppLogger.w(
      'HTTP error → ${appException.type.name}: ${appException.message}',
      error: appException,
      stackTrace: appException.stackTrace,
    );

    // next() — NOT reject().
    //
    // reject() immediately completes the outer request future and
    // terminates the interceptor chain. Anything downstream (notably
    // RefreshInterceptor's auth-error detection) would never run.
    //
    // next() passes the mapped DioException along to the next interceptor.
    // If none handle it, the chain naturally completes with the mapped
    // error, so callers still see DioException(error: AppException) —
    // identical final state, without short-circuiting the Refresh layer.
    handler.next(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: appException,
        stackTrace: err.stackTrace,
      ),
    );
  }

  /// Maps a [DioException] to an [AppException].
  ///
  /// Exposed for `RefreshInterceptor` (to map retry errors) and for tests.
  static AppException mapDioException(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return AppException.network(
          message: 'The request timed out. Please try again.',
          cause: err,
        );

      case DioExceptionType.connectionError:
        return AppException.network(cause: err);

      case DioExceptionType.badCertificate:
        return AppException.network(
          message: 'The server certificate could not be verified.',
          cause: err,
        );

      case DioExceptionType.cancel:
        return AppException.cancelled(cause: err);

      case DioExceptionType.unknown:
        return AppException.network(
          message: 'Could not reach the server.',
          cause: err,
        );

      case DioExceptionType.badResponse:
        return _mapResponse(err);
    }
  }

  static AppException _mapResponse(DioException err) {
    final response = err.response;
    if (response == null) {
      return AppException.unknown(
        message: 'No response from server.',
        cause: err,
      );
    }

    final status = response.statusCode ?? 0;
    final data = response.data;
    final message = _extractMessage(data) ?? _defaultMessageFor(status);
    final fieldErrors = _extractFieldErrors(data);
    final path = err.requestOptions.path;

    // Auth-endpoint special case — see 3.1 fixup for rationale.
    // On login / register / refresh, a 401/403 means "credentials or
    // account issue" (client-error) — NOT "session expired" (auth-error).
    // Preserves the server message for the UI and prevents
    // RefreshInterceptor from trying to refresh on those endpoints.
    final isAuthEstablishmentPath = path.contains('/auth/login') ||
        path.contains('/auth/register/') ||
        path.contains('/auth/refresh');

    if ((status == 401 || status == 403) && isAuthEstablishmentPath) {
      return AppException.client(message: message, cause: err);
    }

    if (status == 401 || status == 403) {
      return AppException.auth(message: message, cause: err);
    }
    if (status == 404) {
      return AppException.notFound(message: message, cause: err);
    }
    if (status == 422) {
      return AppException.validation(
        message: message,
        fieldErrors: fieldErrors,
        cause: err,
      );
    }
    if (status >= 500) {
      return AppException.server(message: message, cause: err);
    }
    if (status >= 400) {
      return AppException.client(message: message, cause: err);
    }

    return AppException.unknown(
      message: 'Unexpected response (status $status).',
      cause: err,
    );
  }

  static String? _extractMessage(dynamic data) {
    if (data is Map) {
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
    return null;
  }

  static Map<String, List<String>> _extractFieldErrors(dynamic data) {
    if (data is! Map) return const {};
    final errors = data['errors'];
    if (errors is! Map) return const {};

    return errors.map((key, value) {
      if (value is List) {
        return MapEntry(
          key.toString(),
          value.map((e) => e.toString()).toList(),
        );
      }
      return MapEntry(key.toString(), [value.toString()]);
    });
  }

  static String _defaultMessageFor(int status) {
    if (status == 401) return 'Authentication required.';
    if (status == 403) return 'You do not have access to this resource.';
    if (status == 404) return 'The requested item could not be found.';
    if (status == 422) return 'Please check your input and try again.';
    if (status >= 500) return 'Something went wrong on our side.';
    return 'The request could not be completed.';
  }
}