import 'app_exception.dart';

/// Categories of user-facing failures.
///
/// [Failure]s are what the UI reacts to. They carry messages that are safe to
/// display and structured data (like field errors) that screens can render.
enum FailureType {
  network,
  server,
  client,
  auth,
  validation,
  notFound,
  cancelled,
  unknown,
}

/// User-safe error object that every repository returns on failure.
///
/// Built from an [AppException] via [Failure.fromException]. Contains no
/// technical details that leak server internals, stack traces, or file paths.
///
/// The UI never inspects an exception — it inspects a [Failure].
class Failure {
  final FailureType type;

  /// Message safe to display to the user.
  final String message;

  /// Optional stable error code (e.g., `INSUFFICIENT_FUNDS`).
  final String? code;

  /// Field-level errors for form validation.
  /// Empty for non-validation failures.
  final Map<String, List<String>> fieldErrors;

  const Failure({
    required this.type,
    required this.message,
    this.code,
    this.fieldErrors = const {},
  });

  // ─── Primary conversion ──────────────────────────────────────────

  /// Converts a low-level [AppException] into a user-facing [Failure].
  ///
  /// This is the ONLY place where exception types map to user-facing copy.
  /// Change the strings here to change the UX globally.
  factory Failure.fromException(AppException e) {
    switch (e.type) {
      case AppExceptionType.network:
        return Failure(
          type: FailureType.network,
          message: 'Unable to reach the server. '
              'Please check your internet connection and try again.',
          code: e.code,
        );

      case AppExceptionType.server:
      case AppExceptionType.parsing:
        // Never surface raw 5xx messages — they can leak internals.
        return Failure(
          type: FailureType.server,
          message: 'Something went wrong on our side. Please try again.',
          code: e.code,
        );

      case AppExceptionType.client:
        // 400-level errors are usually deliberate API design; safe to show.
        return Failure(
          type: FailureType.client,
          message: e.message.isNotEmpty
              ? e.message
              : 'The request could not be completed.',
          code: e.code,
        );

      case AppExceptionType.auth:
        return Failure(
          type: FailureType.auth,
          message: 'Your session has expired. Please sign in again.',
          code: e.code,
        );

      case AppExceptionType.validation:
        return Failure(
          type: FailureType.validation,
          message: e.message.isNotEmpty
              ? e.message
              : 'Please check your input and try again.',
          code: e.code,
          fieldErrors: e.fieldErrors,
        );

      case AppExceptionType.notFound:
        return Failure(
          type: FailureType.notFound,
          message: e.message.isNotEmpty
              ? e.message
              : 'The requested item could not be found.',
          code: e.code,
        );

      case AppExceptionType.cancelled:
        return Failure(
          type: FailureType.cancelled,
          message: 'The request was cancelled.',
          code: e.code,
        );

      case AppExceptionType.storage:
      case AppExceptionType.unknown:
        return Failure(
          type: FailureType.unknown,
          message: 'Something unexpected happened. Please try again.',
          code: e.code,
        );
    }
  }

  // ─── Convenience factories ───────────────────────────────────────

  factory Failure.network({String? code}) => Failure.fromException(
        AppException.network(code: code),
      );

  factory Failure.server({String? code}) => Failure.fromException(
        AppException.server(code: code),
      );

  factory Failure.auth({String? code}) => Failure.fromException(
        AppException.auth(code: code),
      );

  factory Failure.validation({
    String message = 'Please check your input and try again.',
    Map<String, List<String>> fieldErrors = const {},
    String? code,
  }) =>
      Failure(
        type: FailureType.validation,
        message: message,
        fieldErrors: fieldErrors,
        code: code,
      );

  factory Failure.notFound({String? message}) => Failure(
        type: FailureType.notFound,
        message: message ?? 'The requested item could not be found.',
      );

  factory Failure.unknown({String? message}) => Failure(
        type: FailureType.unknown,
        message: message ?? 'Something unexpected happened. Please try again.',
      );

  // ─── Helpers ─────────────────────────────────────────────────────

  /// True if showing a "Try again" button makes sense.
  bool get isRetryable =>
      type == FailureType.network || type == FailureType.server;

  /// True if the user needs to be redirected to login.
  bool get isAuthError => type == FailureType.auth;

  /// True if this is a form-level validation failure.
  bool get isValidation => type == FailureType.validation;

  Failure copyWith({
    String? message,
    Map<String, List<String>>? fieldErrors,
  }) =>
      Failure(
        type: type,
        message: message ?? this.message,
        code: code,
        fieldErrors: fieldErrors ?? this.fieldErrors,
      );

  @override
  String toString() {
    final b = StringBuffer('Failure(${type.name}: $message');
    if (code != null) b.write(', code: $code');
    if (fieldErrors.isNotEmpty) b.write(', fieldErrors: $fieldErrors');
    b.write(')');
    return b.toString();
  }
}