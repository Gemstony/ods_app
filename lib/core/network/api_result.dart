import '../errors/app_exception.dart';
import '../errors/failure.dart';
import '../utils/logger.dart';
import 'package:dio/dio.dart';

/// Sealed result type returned by every repository method.
///
/// Every async operation either succeeds with data ([ApiSuccess]) or fails
/// with a user-safe [Failure] ([ApiFailure]). The sealed hierarchy lets
/// callers exhaustively switch on the outcome — no more `if (x != null)`.
///
/// Repositories should use [ApiResult.guard] as their default try/catch:
///
/// ```dart
/// Future<ApiResult<Health>> getHealth() => ApiResult.guard(() async {
///   final r = await _dio.get('/health');
///   return Health.fromJson(r.data['data']);
/// });
/// ```
sealed class ApiResult<T> {
  const ApiResult();

  // ─── Basic inspection ────────────────────────────────────────────

  bool get isSuccess => this is ApiSuccess<T>;
  bool get isFailure => this is ApiFailure<T>;

  /// Returns the success data, or `null` if this is a failure.
  T? get dataOrNull => switch (this) {
        ApiSuccess<T>(:final data) => data,
        ApiFailure<T>() => null,
      };

  /// Returns the failure, or `null` if this is a success.
  Failure? get failureOrNull => switch (this) {
        ApiSuccess<T>() => null,
        ApiFailure<T>(:final failure) => failure,
      };

  // ─── Pattern matching ────────────────────────────────────────────

  /// Collapses both branches into a single value.
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(Failure failure) onFailure,
  }) =>
      switch (this) {
        ApiSuccess<T>(:final data) => onSuccess(data),
        ApiFailure<T>(:final failure) => onFailure(failure),
      };

  // ─── Guarded execution ───────────────────────────────────────────

  /// Runs [block] and captures any thrown error into a typed [ApiResult].
  ///
  /// Handles three cases in order:
  ///
  ///   1. `AppException`       — thrown directly by our own code
  ///                             (e.g., `StateError` wrapped by a repo, or
  ///                             `AppException.parsing()` from a bad payload)
  ///
  ///   2. `DioException`       — thrown by Dio after our ErrorMappingInterceptor
  ///                             rejected the request. The interceptor stashes
  ///                             the mapped `AppException` in `err.error`, so
  ///                             we unwrap it here. This is the normal path for
  ///                             HTTP errors (4xx / 5xx).
  ///
  ///   3. any other `Object`   — wrapped as `AppException.unknown`
  ///
  /// The catch is broad on purpose: repositories should never let an
  /// unhandled exception escape to the UI layer.
  static Future<ApiResult<T>> guard<T>(Future<T> Function() block) async {
    try {
      final result = await block();
      return ApiSuccess<T>(result);
    } on AppException catch (e, st) {
      AppLogger.w(
        'API call failed: ${e.message}',
        error: e,
        stackTrace: st,
      );
      return ApiFailure<T>(Failure.fromException(e));
    } on DioException catch (e, st) {
      // Dio's interceptors can only reject with DioException. Our
      // ErrorMappingInterceptor stashes the mapped AppException in `.error`.
      final cause = e.error;
      if (cause is AppException) {
        AppLogger.w(
          'HTTP error mapped: ${cause.type.name}: ${cause.message}',
          error: cause,
          stackTrace: st,
        );
        return ApiFailure<T>(Failure.fromException(cause));
      }
      // Fallback if the interceptor chain somehow didn't map the error
      // (e.g., a repo instantiated Dio without our interceptors). Surface
      // a network failure — it's the most likely cause and it's retryable.
      AppLogger.e(
        'DioException without mapped AppException',
        error: e,
        stackTrace: st,
      );
      final wrapped = AppException.network(
        message: 'Network request failed',
        cause: e,
        stackTrace: st,
      );
      return ApiFailure<T>(Failure.fromException(wrapped));
    } catch (e, st) {
      AppLogger.e(
        'Unhandled exception in guarded block',
        error: e,
        stackTrace: st,
      );
      final wrapped = AppException.unknown(
        message: 'Unexpected error',
        cause: e,
        stackTrace: st,
      );
      return ApiFailure<T>(Failure.fromException(wrapped));
    }
  }
}

final class ApiSuccess<T> extends ApiResult<T> {
  final T data;
  const ApiSuccess(this.data);
}

final class ApiFailure<T> extends ApiResult<T> {
  final Failure failure;
  const ApiFailure(this.failure);
}
