import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../errors/app_exception.dart';
import '../utils/logger.dart';

// ─────────────────────────────────────────────────────────────────────
// Auth header interceptor
// ─────────────────────────────────────────────────────────────────────

/// Attaches a bearer token to every outgoing request when one is available.
///
/// The token source is injected — in Sub-phase 1.8 this will be wired to
/// secure storage. Until then the provider is null and no header is sent.
class AuthHeaderInterceptor extends Interceptor {
  final String? Function()? tokenProvider;

  AuthHeaderInterceptor({this.tokenProvider});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

// ─────────────────────────────────────────────────────────────────────
// Error mapping interceptor
// ─────────────────────────────────────────────────────────────────────

/// Converts every [DioException] into an [AppException], so downstream
/// layers (repositories, `ApiResult.guard`) see one error type.
///
/// The mapped [AppException] is stored in [DioException.error] so
/// `ApiResult.guard` can catch it via its `on AppException` clause.
class ErrorMappingInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final appException = mapDioException(err);

    AppLogger.w(
      'HTTP error → ${appException.type.name}: ${appException.message}',
      error: appException,
      stackTrace: appException.stackTrace,
    );

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: appException,
        stackTrace: err.stackTrace,
      ),
    );
  }

  /// Maps a [DioException] to an [AppException]. Public for testing.
  @visibleForTesting
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

    // Unexpected 2xx/3xx that Dio still flagged as bad.
    return AppException.unknown(
      message: 'Unexpected response (status $status).',
      cause: err,
    );
  }

  // ─── Laravel envelope helpers ────────────────────────────────────
  //
  // Envelope (Phase 1.10):
  //   success: { "success": true,  "message": "...", "data": {...} }
  //   error:   { "success": false, "message": "...", "errors": {...} }

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
