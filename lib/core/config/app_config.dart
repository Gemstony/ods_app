import 'env.dart';

/// The three deployment environments for the ODS app.
enum AppEnvironment { dev, staging, prod }

/// Global, immutable-at-runtime configuration for the app.
///
/// Call [initialize] once from `main()` *after* `WidgetsFlutterBinding.ensureInitialized()`.
/// Every other layer reads from the static fields here — nothing else in the
/// codebase should read from [Env] directly.
class AppConfig {
  AppConfig._();

  static const String appName = 'ODS';
  static const String appTagline = 'Zero Distance Services';
  static const String appVersion = '0.1.0';

  static bool _initialized = false;

  static late final AppEnvironment environment;
  static late final String apiBaseUrl;

  /// Resolves the runtime environment and base URL exactly once.
  static void initialize() {
    if (_initialized) return;

    environment = _parseEnvironment(Env.rawEnvironment);
    apiBaseUrl = Env.apiBaseUrlOverride.isNotEmpty
        ? Env.apiBaseUrlOverride
        : _defaultBaseUrlFor(environment);

    _initialized = true;
  }

  static bool get isDev => environment == AppEnvironment.dev;
  static bool get isStaging => environment == AppEnvironment.staging;
  static bool get isProd => environment == AppEnvironment.prod;

  static AppEnvironment _parseEnvironment(String value) {
    switch (value) {
      case 'prod':
        return AppEnvironment.prod;
      case 'staging':
        return AppEnvironment.staging;
      case 'dev':
      default:
        return AppEnvironment.dev;
    }
  }

  static String _defaultBaseUrlFor(AppEnvironment env) {
    switch (env) {
      // ────────────────────────────────────────────────────────────────
      // DEV defaults to localhost:8000 — the address `php artisan serve`
      // listens on. This works directly in Chrome.
      //
      // For a PHYSICAL PHONE, `localhost` means the phone itself (wrong).
      // Always override with your laptop's LAN IP:
      //
      //   --dart-define=API_BASE_URL=http://192.168.1.40:8000/api/v1
      //
      // Find your LAN IP:
      //   Windows:  ipconfig   (IPv4 under Wi-Fi adapter)
      //   macOS:    ifconfig | grep "inet "
      //   Linux:    ip addr
      // ────────────────────────────────────────────────────────────────
      case AppEnvironment.dev:
        return 'http://localhost:8000/api/v1';

      case AppEnvironment.staging:
        return 'https://staging-api.ods.example.com/api/v1';

      case AppEnvironment.prod:
        return 'https://api.ods.example.com/api/v1';
    }
  }
}