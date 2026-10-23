import 'dart:developer' as developer;

/// Severity levels for app logging.
///
/// Ordered so that `minimumLevel` filtering works by comparing `index`.
enum LogLevel { debug, info, warning, error }

/// Structured logger that pipes into Dart DevTools' Logging view.
///
/// Every log line is prefixed with `[ODS/LEVEL]` so it's greppable in the
/// DevTools console and in `flutter run` output.
///
/// Production logging (Sentry, remote crash reporting) is a Phase 15 concern —
/// this logger stays local by design.
class AppLogger {
  AppLogger._();

  /// The lowest level that will be emitted. Bump to [LogLevel.info] in
  /// production once remote logging exists, to reduce noise.
  static LogLevel minimumLevel = LogLevel.debug;

  static const String _appName = 'ODS';

  // ─── Level shortcuts ────────────────────────────────────────────

  static void d(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(LogLevel.debug, message, error, stackTrace);

  static void i(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(LogLevel.info, message, error, stackTrace);

  static void w(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(LogLevel.warning, message, error, stackTrace);

  static void e(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(LogLevel.error, message, error, stackTrace);

  // ─── Exception helper ───────────────────────────────────────────

  /// Logs a captured exception with an optional [context] label so the
  /// DevTools stack viewer groups similar errors together.
  static void exception(
    Object error,
    StackTrace stackTrace, {
    String? context,
  }) {
    final label =
        context == null ? 'Unhandled exception' : 'Exception ($context)';
    e(label, error: error, stackTrace: stackTrace);
  }

  // ─── Internal ───────────────────────────────────────────────────

  static void _log(
    LogLevel level,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    if (level.index < minimumLevel.index) return;

    final tag = level.name.toUpperCase();
    final fullMessage = '[$_appName/$tag] $message';

    developer.log(
      fullMessage,
      name: _appName,
      level: _levelValue(level),
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Maps our [LogLevel] to Dart's `dart:developer` severity values.
  static int _levelValue(LogLevel level) => switch (level) {
        LogLevel.debug => 500, // Level.FINE
        LogLevel.info => 800, // Level.INFO
        LogLevel.warning => 900, // Level.WARNING
        LogLevel.error => 1000, // Level.SEVERE
      };
}