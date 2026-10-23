import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_interceptors.dart';

/// Singleton wrapper around a configured [Dio] instance.
///
/// **Do not construct your own [Dio] anywhere else.** Repositories must use
/// [instance.dio] so that the interceptor chain and base URL are consistent.
///
/// Requires [AppConfig.initialize] to have run first, because the base URL
/// is read from [AppConfig.apiBaseUrl] at construction time. In the app this
/// is guaranteed by `main()`; in tests, call `AppConfig.initialize()` in
/// `setUpAll`.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  late final Dio dio = _buildDio();

  Dio _buildDio() {
    final d = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        // Let the interceptor decide how to map failures — don't let Dio
        // throw its own generic exception on 4xx/5xx.
        validateStatus: (status) => status != null && status < 400,
      ),
    );

    d.interceptors.addAll([
      // Auth is inert until 1.8 wires a token provider.
      AuthHeaderInterceptor(),
      ErrorMappingInterceptor(),
    ]);

    return d;
  }

  /// Allows tests to inject a fully configured Dio (e.g. with a mock adapter).
  /// Production code never calls this.
  static ApiClient withDio(Dio dio) {
    final client = ApiClient._();
    // ignore: invalid_use_of_visible_for_testing_member
    client._overrideDio(dio);
    return client;
  }

  void _overrideDio(Dio d) {
    // Hack-free approach: we can't reassign a `late final`, so we cheat by
    // using a boxed getter. Kept private — production never hits this.
    _testDio = d;
  }

  Dio? _testDio;

  Dio get effectiveDio => _testDio ?? dio;
}