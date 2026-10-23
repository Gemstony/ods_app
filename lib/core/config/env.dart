/// Raw build-time environment values injected via --dart-define.
///
/// This file only exposes the *raw* inputs. Interpretation happens in
/// [AppConfig] so that tests and future tooling can override behaviour
/// without touching the compiled constants.
class Env {
  Env._();

  /// Compile-time environment name: `dev` | `staging` | `prod`.
  ///
  /// Injected with: flutter run --dart-define=ENV=dev
  static const String rawEnvironment =
      String.fromEnvironment('ENV', defaultValue: 'dev');

  /// Optional explicit override for the API base URL.
  ///
  /// Use this whenever the default dev URL (localhost) is not what you want,
  /// e.g. testing from a physical phone that must reach your laptop over Wi-Fi:
  ///
  ///   --dart-define=API_BASE_URL=http://192.168.1.40:8000/api/v1
  static const String apiBaseUrlOverride =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');
}