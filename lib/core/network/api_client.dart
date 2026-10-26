import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_interceptors.dart';
import 'token_service.dart';

/// Singleton wrapper around the app's configured [Dio] instance.
///
/// **Do not construct your own [Dio] anywhere else.** Repositories must use
/// [instance.dio] so the interceptor chain and base URL are consistent.
///
/// Must be [initialize]d once at app startup (in `_OdsAppRootState.initState`)
/// before any request goes out. Without initialization, [dio] has no
/// interceptors — which is fine for tests, dangerous in production.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  late final Dio dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      validateStatus: (status) => status != null && status < 400,
    ),
  );

  bool _initialized = false;

  /// Wires the interceptor chain. Called once from `_OdsAppRootState.initState`.
  ///
  /// Idempotent — safe to call multiple times (hot reload).
  void initialize({
    required TokenService tokenService,
    void Function()? onSessionExpired,
  }) {
    // Clear first so hot reload doesn't stack interceptors.
    dio.interceptors.clear();

    // Order matters. Dio fires onRequest in insertion order and onError
    // in reverse. So:
    //   Request: AuthHeader → Refresh → ErrorMapping
    //   Error:   ErrorMapping (map) → Refresh (check mapped type) → AuthHeader
    // Interceptor ordering — target behaviour:
    //   Request path: AuthHeader (attach token) → Refresh (no-op) → ErrorMapping (no-op)
    //   Error path:   ErrorMapping (map to AppException) → Refresh (check type, retry) → AuthHeader (no-op)
    //
    // Dio 4.x documented reverse-order onError; Dio 5.x traverses forward.
    // The RefreshInterceptor is now robust to either (Fix A), but we order
    // this list so ErrorMapping runs first on the error path under BOTH
    // orderings — maximum robustness with zero behavioural surprise.
    dio.interceptors.addAll([
      ErrorMappingInterceptor(),
      RefreshInterceptor(
        tokenService: tokenService,
        dio: dio,
        onSessionExpired: onSessionExpired,
      ),
      AuthHeaderInterceptor(tokenService),
    ]);

    _initialized = true;
  }

  /// True after [initialize] has been called at least once.
  bool get isInitialized => _initialized;
}