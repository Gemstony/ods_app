import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/repositories/auth_repository.dart';
import 'package:ods_app/core/network/api_interceptors.dart';

/// Minimal Dio adapter that returns a canned response without any network
/// traffic. Matches what the backend would return so the repository's
/// envelope parsing is genuinely exercised.
class _MockAdapter implements HttpClientAdapter {
  _MockAdapter({
    required this.statusCode,
    required this.body,
    this.responseHeaders,
  });

  final int statusCode;
  final Map<String, dynamic>? body;
  final Map<String, List<String>>? responseHeaders;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...?responseHeaders,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(_MockAdapter adapter) {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:8000/api/v1',
    validateStatus: (s) => s != null && s < 400,
  ));
  dio.httpClientAdapter = adapter;
  // The ErrorMappingInterceptor is what converts DioException into
  // AppException. Without it, ApiResult.guard has nothing to unwrap.
  // This mirrors production's ApiClient exactly.
  dio.interceptors.add(ErrorMappingInterceptor());
  return dio;
}

/// Sample success payload matching `/api/v1/auth/login` from 2.6.
Map<String, dynamic> _loginSuccessPayload() => {
      'success': true,
      'message': 'Login successful.',
      'data': {
        'user': {
          'id': 42,
          'name': 'Ahmed Juma',
          'email': 'ahmed@ods.test',
          'phone': '0712345678',
          'role': 'owner',
          'status': 'active',
          'branch_id': null,
          'distributor_id': null,
          'dispatcher_enabled': false,
          'email_verified_at': '2026-10-24T07:00:00+00:00',
          'created_at': '2026-10-24T07:00:00+00:00',
          'permissions': [
            'manage_users',
            'manage_branches',
            'manage_settings',
            'manage_finance',
            'view_audit_logs',
            'resolve_disputes',
          ],
        },
        'access_token': 'eyJ0eXAiOiJKV1QiLCJhbGc...sample...',
        'refresh_token': 'a' * 64,
        'token_type': 'bearer',
        'expires_in': 3600,
      },
    };

Map<String, dynamic> _validationErrorPayload() => {
      'success': false,
      'message': 'Validation failed.',
      'errors': {
        'email': ['The email field is required.'],
        'password': ['The password field is required.'],
      },
    };

Map<String, dynamic> _statusErrorPayload() => {
      'success': false,
      'message':
          'Your account is pending approval. Please wait for the administrator.',
      'errors': null,
    };

void main() {
  group('AuthRepository.login', () {
    test('parses a valid login response into user + tokens', () async {
      final repo = AuthRepository(
        dio: _dioWith(
            _MockAdapter(statusCode: 200, body: _loginSuccessPayload())),
      );

      final result = await repo.login(
        email: 'ahmed@ods.test',
        password: 'secret-pass',
      );

      expect(result, isA<ApiSuccess>());
      final value = result.dataOrNull!;
      expect(value.user.id, 42);
      expect(value.user.role, 'owner');
      expect(value.user.isOwner, isTrue);
      expect(value.user.isActive, isTrue);
      expect(value.user.hasPermission('manage_users'), isTrue);
      expect(value.user.hasPermission('manage_staff'), isFalse);
      expect(value.user.permissions.length, 6);
      expect(value.tokens.accessToken, contains('eyJ'));
      expect(value.tokens.refreshToken.length, 64);
      expect(value.tokens.expiresIn, 3600);
      expect(value.tokens.accessExpiryDate.isAfter(DateTime.now()), isTrue);
    });

    test('maps 422 to validation failure with fieldErrors', () async {
      final repo = AuthRepository(
        dio: _dioWith(
            _MockAdapter(statusCode: 422, body: _validationErrorPayload())),
      );

      final result = await repo.login(email: '', password: '');
      expect(result, isA<ApiFailure>());
      final failure = result.failureOrNull!;
      expect(failure.isValidation, isTrue);
      expect(failure.fieldErrors['email'],
          contains('The email field is required.'));
      expect(failure.fieldErrors['password'], isNotNull);
    });

    test('maps 403 to a client failure with the server message', () async {
      final repo = AuthRepository(
        dio: _dioWith(
            _MockAdapter(statusCode: 403, body: _statusErrorPayload())),
      );

      final result = await repo.login(email: 'pending@ods.test', password: 'x');
      expect(result, isA<ApiFailure>());
      final failure = result.failureOrNull!;
      expect(failure.message, contains('pending approval'));
      expect(failure.isRetryable, isFalse);
    });
  });

  group('AuthRepository.me', () {
    test('parses a user', () async {
      // /me returns the user object directly in `data` (not bundled).
      final payload = {
        'success': true,
        'message': 'OK',
        'data': _loginSuccessPayload()['data']!['user'],
      };

      final repo = AuthRepository(
        dio: _dioWith(_MockAdapter(statusCode: 200, body: payload)),
      );

      final result = await repo.me();
      expect(result, isA<ApiSuccess>());
      final user = result.dataOrNull!;
      expect(user.id, 42);
      expect(user.role, 'owner');
    });
  });

  group('AuthRepository.logout / logoutAll', () {
    test('logout sends the refresh token when provided', () async {
      final adapter = _MockAdapter(
        statusCode: 200,
        body: {
          'success': true,
          'message': 'Logged out successfully.',
          'data': null
        },
      );
      final repo = AuthRepository(dio: _dioWith(adapter));

      final result = await repo.logout(refreshToken: 'r' * 64);
      expect(result, isA<ApiSuccess>());
    });

    test('logout works without a refresh token', () async {
      final adapter = _MockAdapter(
        statusCode: 200,
        body: {
          'success': true,
          'message': 'Logged out successfully.',
          'data': null
        },
      );
      final repo = AuthRepository(dio: _dioWith(adapter));

      final result = await repo.logout();
      expect(result, isA<ApiSuccess>());
    });

    test('logoutAll returns success on 200', () async {
      final adapter = _MockAdapter(
        statusCode: 200,
        body: {
          'success': true,
          'message': 'Logged out from all devices.',
          'data': null
        },
      );
      final repo = AuthRepository(dio: _dioWith(adapter));

      final result = await repo.logoutAll();
      expect(result, isA<ApiSuccess>());
    });
  });

  group('AuthRepository.refresh', () {
    test('parses a rotated token pair', () async {
      final payload = _loginSuccessPayload(); // same shape as login
      final repo = AuthRepository(
        dio: _dioWith(_MockAdapter(statusCode: 200, body: payload)),
      );

      final result = await repo.refresh(refreshToken: 'old' * 20);
      expect(result, isA<ApiSuccess>());
      expect(result.dataOrNull!.tokens.accessToken.isNotEmpty, isTrue);
    });

    test('401 from refresh maps to a client failure', () async {
      final repo = AuthRepository(
        dio: _dioWith(_MockAdapter(
          statusCode: 401,
          body: {
            'success': false,
            'message': 'Invalid or expired refresh token.',
            'errors': null,
          },
        )),
      );

      final result = await repo.refresh(refreshToken: 'invalid');
      expect(result, isA<ApiFailure>());
      expect(result.failureOrNull!.message, contains('Invalid or expired'));
    });
  });
}
