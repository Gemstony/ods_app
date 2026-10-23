/// Categories of low-level errors the app can encounter.
///
/// Every thrown [AppException] carries one of these so that higher layers
/// (repositories, UI) can react without parsing strings.
enum AppExceptionType {
  /// No connectivity, DNS failure, timeout, or connection refused.
  network,

  /// Server returned a 5xx error or the response could not be understood.
  server,

  /// Server returned a 4xx error other than 401/403/404/422.
  client,

  /// 401 Unauthorized or 403 Forbidden — user must re-authenticate.
  auth,

  /// 422 Unprocessable Entity or a form-level input error.
  validation,

  /// 404 Not Found — requested entity doesn't exist.
  notFound,

  /// Response body could not be parsed (bad JSON, unexpected shape).
  parsing,

  /// Local device storage / secure storage failure.
  storage,

  /// Request was explicitly cancelled by the caller or the user.
  cancelled,

  /// Anything that doesn't fit the above.
  unknown,
}

/// Low-level exception thrown by network, storage, and parsing layers.
///
/// Repositories should catch `AppException` and convert to `Failure` via
/// [Failure.fromException]. UI code should never see `AppException` directly.
///
/// Constructors are provided per category so callers don't have to remember
/// the enum name — and so future refactors to the enum stay localized.
class AppException implements Exception {
  final AppExceptionType type;
  final String message;
  final String? code;
  final Map<String, List<String>> fieldErrors;
  final Object? cause;
  final StackTrace? stackTrace;

  const AppException({
    required this.type,
    required this.message,
    this.code,
    this.fieldErrors = const {},
    this.cause,
    this.stackTrace,
  });

  // ─── Factories per category ──────────────────────────────────────

  factory AppException.network({
    String message = 'Network request failed',
    String? code,
    Object? cause,
    StackTrace? stackTrace,
  }) =>
      AppException(
        type: AppExceptionType.network,
        message: message,
        code: code,
        cause: cause,
        stackTrace: stackTrace,
      );

  factory AppException.server({
    String message = 'Server error',
    String? code,
    Object? cause,
    StackTrace? stackTrace,
  }) =>
      AppException(
        type: AppExceptionType.server,
        message: message,
        code: code,
        cause: cause,
        stackTrace: stackTrace,
      );

  factory AppException.client({
    required String message,
    String? code,
    Object? cause,
    StackTrace? stackTrace,
  }) =>
      AppException(
        type: AppExceptionType.client,
        message: message,
        code: code,
        cause: cause,
        stackTrace: stackTrace,
      );

  factory AppException.auth({
    String message = 'Authentication required',
    String? code,
    Object? cause,
    StackTrace? stackTrace,
  }) =>
      AppException(
        type: AppExceptionType.auth,
        message: message,
        code: code,
        cause: cause,
        stackTrace: stackTrace,
      );

  factory AppException.validation({
    required String message,
    Map<String, List<String>> fieldErrors = const {},
    String? code,
    Object? cause,
    StackTrace? stackTrace,
  }) =>
      AppException(
        type: AppExceptionType.validation,
        message: message,
        fieldErrors: fieldErrors,
        code: code,
        cause: cause,
        stackTrace: stackTrace,
      );

  factory AppException.notFound({
    String message = 'Resource not found',
    String? code,
    Object? cause,
    StackTrace? stackTrace,
  }) =>
      AppException(
        type: AppExceptionType.notFound,
        message: message,
        code: code,
        cause: cause,
        stackTrace: stackTrace,
      );

  factory AppException.parsing({
    String message = 'Failed to parse response',
    Object? cause,
    StackTrace? stackTrace,
  }) =>
      AppException(
        type: AppExceptionType.parsing,
        message: message,
        cause: cause,
        stackTrace: stackTrace,
      );

  factory AppException.storage({
    String message = 'Storage operation failed',
    Object? cause,
    StackTrace? stackTrace,
  }) =>
      AppException(
        type: AppExceptionType.storage,
        message: message,
        cause: cause,
        stackTrace: stackTrace,
      );

  factory AppException.cancelled({
    String message = 'Request was cancelled',
    Object? cause,
    StackTrace? stackTrace,
  }) =>
      AppException(
        type: AppExceptionType.cancelled,
        message: message,
        cause: cause,
        stackTrace: stackTrace,
      );

  factory AppException.unknown({
    String message = 'An unexpected error occurred',
    Object? cause,
    StackTrace? stackTrace,
  }) =>
      AppException(
        type: AppExceptionType.unknown,
        message: message,
        cause: cause,
        stackTrace: stackTrace,
      );

  // ─── Debug output ────────────────────────────────────────────────

  @override
  String toString() {
    final b = StringBuffer('AppException(${type.name}: $message');
    if (code != null) b.write(', code: $code');
    if (fieldErrors.isNotEmpty) b.write(', fieldErrors: $fieldErrors');
    if (cause != null) b.write(', cause: $cause');
    b.write(')');
    return b.toString();
  }
}