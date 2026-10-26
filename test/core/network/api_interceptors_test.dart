import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/errors/app_exception.dart';
import 'package:ods_app/core/network/api_interceptors.dart';

DioException _err({
  DioExceptionType type = DioExceptionType.badResponse,
  int? status,
  dynamic body,
  String path = '/test',
}) {
  final options = RequestOptions(path: path);
  final response = status == null
      ? null
      : Response<dynamic>(
          requestOptions: options,
          statusCode: status,
          data: body,
        );
  return DioException(
    requestOptions: options,
    response: response,
    type: type,
  );
}

void main() {
  // ─── Transport errors ──────────────────────────────────────
  group('ErrorMappingInterceptor.mapDioException — transport errors', () {
    test('connectionError → network', () {
      final e = ErrorMappingInterceptor.mapDioException(
        _err(type: DioExceptionType.connectionError),
      );
      expect(e.type, AppExceptionType.network);
    });

    test('connectionTimeout → network with timeout message', () {
      final e = ErrorMappingInterceptor.mapDioException(
        _err(type: DioExceptionType.connectionTimeout),
      );
      expect(e.type, AppExceptionType.network);
      expect(e.message.toLowerCase(), contains('timed out'));
    });

    test('receiveTimeout → network', () {
      final e = ErrorMappingInterceptor.mapDioException(
        _err(type: DioExceptionType.receiveTimeout),
      );
      expect(e.type, AppExceptionType.network);
    });

    test('cancel → cancelled', () {
      final e = ErrorMappingInterceptor.mapDioException(
        _err(type: DioExceptionType.cancel),
      );
      expect(e.type, AppExceptionType.cancelled);
    });

    test('badCertificate → network', () {
      final e = ErrorMappingInterceptor.mapDioException(
        _err(type: DioExceptionType.badCertificate),
      );
      expect(e.type, AppExceptionType.network);
      expect(e.message.toLowerCase(), contains('certificate'));
    });
  });

  // ─── HTTP status errors on PROTECTED endpoints ─────────────
  group('ErrorMappingInterceptor.mapDioException — HTTP status', () {
    test('401 on protected endpoint → auth (session expired)', () {
      final e = ErrorMappingInterceptor.mapDioException(
        _err(
          status: 401,
          path: '/auth/me',
          body: {'message': 'Unauthenticated.'},
        ),
      );
      expect(e.type, AppExceptionType.auth);
      expect(e.message, 'Unauthenticated.');
    });

    test('403 on protected endpoint → auth', () {
      final e = ErrorMappingInterceptor.mapDioException(
        _err(
          status: 403,
          path: '/owner/branches',
          body: {'message': 'Forbidden'},
        ),
      );
      expect(e.type, AppExceptionType.auth);
    });

    test('404 → notFound', () {
      final e = ErrorMappingInterceptor.mapDioException(
        _err(status: 404, body: {'message': 'Not here'}),
      );
      expect(e.type, AppExceptionType.notFound);
      expect(e.message, 'Not here');
    });

    test('422 → validation with fieldErrors', () {
      final e = ErrorMappingInterceptor.mapDioException(
        _err(
          status: 422,
          body: {
            'message': 'Validation failed',
            'errors': {
              'email': ['The email field is required.'],
              'phone': ['The phone must be 10 digits.'],
            },
          },
        ),
      );

      expect(e.type, AppExceptionType.validation);
      expect(e.message, 'Validation failed');
      expect(e.fieldErrors['email'], ['The email field is required.']);
      expect(e.fieldErrors['phone'], ['The phone must be 10 digits.']);
    });

    test('500 → server', () {
      final e = ErrorMappingInterceptor.mapDioException(
        _err(status: 500, body: {'message': 'Internal error'}),
      );
      expect(e.type, AppExceptionType.server);
      expect(e.message, 'Internal error');
    });

    test('400 → client', () {
      final e = ErrorMappingInterceptor.mapDioException(
        _err(status: 400, body: {'message': 'Bad request'}),
      );
      expect(e.type, AppExceptionType.client);
      expect(e.message, 'Bad request');
    });

    test('empty body falls back to default message per status', () {
      final e = ErrorMappingInterceptor.mapDioException(
        _err(status: 500, body: null),
      );
      expect(e.type, AppExceptionType.server);
      expect(e.message.isNotEmpty, isTrue);
    });
  });

  // ─── HTTP status errors on AUTH-ESTABLISHMENT endpoints ───
  group('ErrorMappingInterceptor.mapDioException — auth endpoints', () {
    test('401 on /auth/login → client (not auth)', () {
      final e = ErrorMappingInterceptor.mapDioException(
        _err(
          status: 401,
          path: '/auth/login',
          body: {'message': 'Invalid email or password.'},
        ),
      );
      expect(e.type, AppExceptionType.client);
      expect(e.message, 'Invalid email or password.');
    });

    test('403 on /auth/login → client (pending / suspended account)', () {
      final e = ErrorMappingInterceptor.mapDioException(
        _err(
          status: 403,
          path: '/auth/login',
          body: {
            'message': 'Your account is pending approval. Please wait for the administrator.',
          },
        ),
      );
      expect(e.type, AppExceptionType.client);
      expect(e.message, contains('pending approval'));
    });

    test('401 on /auth/refresh → client (invalid or expired refresh token)', () {
      final e = ErrorMappingInterceptor.mapDioException(
        _err(
          status: 401,
          path: '/auth/refresh',
          body: {'message': 'Invalid or expired refresh token.'},
        ),
      );
      expect(e.type, AppExceptionType.client);
      expect(e.message, contains('Invalid or expired'));
    });

    test('403 on /auth/register/distributor → client', () {
      final e = ErrorMappingInterceptor.mapDioException(
        _err(
          status: 403,
          path: '/auth/register/distributor',
          body: {'message': 'Email already registered.'},
        ),
      );
      expect(e.type, AppExceptionType.client);
      expect(e.message, 'Email already registered.');
    });
  });
}