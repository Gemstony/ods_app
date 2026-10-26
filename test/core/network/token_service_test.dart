import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/network/token_service.dart';
import 'package:ods_app/data/local/secure_storage.dart';
import 'package:ods_app/data/models/auth/auth_tokens.dart';
import 'package:ods_app/data/models/auth/auth_user.dart';

/// Minimal Dio adapter returning a canned JSON response.
class _MockAdapter implements HttpClientAdapter {
  _MockAdapter({required this.statusCode, required this.body});
  final int statusCode;
  final Map<String, dynamic>? body;

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
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _mockRefreshDio(_MockAdapter adapter) {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:8000/api/v1',
    validateStatus: (s) => s != null && s < 400,
  ));
  dio.httpClientAdapter = adapter;
  return dio;
}

Map<String, dynamic> _successBody() => {
      'success': true,
      'message': 'Token refreshed.',
      'data': {
        'user': {
          'id': 42,
          'name': 'Ahmed',
          'email': 'ahmed@ods.test',
          'phone': '0712345678',
          'role': 'owner',
          'status': 'active',
          'dispatcher_enabled': false,
          'permissions': ['manage_users'],
        },
        'access_token': 'new-access-token',
        'refresh_token': 'new-refresh-token-${'a' * 48}',
        'token_type': 'bearer',
        'expires_in': 3600,
      },
    };

AuthUser _sampleUser() => AuthUser(
      id: 42,
      name: 'Ahmed',
      email: 'ahmed@ods.test',
      phone: '0712345678',
      role: 'owner',
      status: 'active',
      dispatcherEnabled: false,
      permissions: const ['manage_users'],
    );

AuthTokens _sampleTokens() => const AuthTokens(
      accessToken: 'old-access',
      refreshToken: 'old-refresh',
      tokenType: 'bearer',
      expiresIn: 3600,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  group('TokenService — storage', () {
    test('getAccessToken returns null when storage is empty', () async {
      final storage = InMemorySecureStorage();
      final service = TokenService(storage: storage);
      expect(await service.getAccessToken(), isNull);
      expect(await service.getRefreshToken(), isNull);
    });

    test('persistSession writes access, refresh, user id, role, and name',
        () async {
      final storage = InMemorySecureStorage();
      final service = TokenService(storage: storage);

      await service.persistSession(
        user: _sampleUser(),
        tokens: _sampleTokens(),
      );

      expect(await storage.read('ods.auth.access_token'), 'old-access');
      expect(await storage.read('ods.auth.refresh_token'), 'old-refresh');
      expect(await storage.read('ods.auth.user_id'), '42');
      expect(await storage.read('ods.auth.role'), 'owner');
      expect(await storage.read('ods.auth.display_name'), 'Ahmed');
    });

    test('clearTokens removes every key', () async {
      final storage = InMemorySecureStorage();
      final service = TokenService(storage: storage);
      await service.persistSession(
        user: _sampleUser(),
        tokens: _sampleTokens(),
      );
      await service.clearTokens();

      expect(await service.getAccessToken(), isNull);
      expect(await service.getRefreshToken(), isNull);
      expect(await storage.read('ods.auth.user_id'), isNull);
      expect(await storage.read('ods.auth.role'), isNull);
      expect(await storage.read('ods.auth.display_name'), isNull);
    });
  });

  group('TokenService — refresh', () {
    test('returns null when no refresh token is stored', () async {
      final service = TokenService(storage: InMemorySecureStorage());
      expect(await service.refresh(), isNull);
    });

    test('returns AuthLoginResult on success', () async {
      final storage = InMemorySecureStorage();
      await storage.write('ods.auth.refresh_token', 'old-refresh');

      final service = TokenService(
        storage: storage,
        refreshDio: _mockRefreshDio(_MockAdapter(
          statusCode: 200,
          body: _successBody(),
        )),
      );

      final result = await service.refresh();
      expect(result, isNotNull);
      expect(result!.user.role, 'owner');
      expect(result.tokens.accessToken, 'new-access-token');
      expect(result.tokens.refreshToken.startsWith('new-refresh-token'), isTrue);
    });

    test('returns null on 401 from server', () async {
      final storage = InMemorySecureStorage();
      await storage.write('ods.auth.refresh_token', 'expired-refresh');

      final service = TokenService(
        storage: storage,
        refreshDio: _mockRefreshDio(_MockAdapter(
          statusCode: 401,
          body: {
            'success': false,
            'message': 'Invalid or expired refresh token.',
            'errors': null,
          },
        )),
      );

      expect(await service.refresh(), isNull);
    });

    test('returns null on network error', () async {
      final storage = InMemorySecureStorage();
      await storage.write('ods.auth.refresh_token', 'whatever');

      final dio = Dio(BaseOptions(
        baseUrl: 'http://localhost:1/api/v1',
        connectTimeout: const Duration(milliseconds: 100),
      ));
      final service = TokenService(storage: storage, refreshDio: dio);

      expect(await service.refresh(), isNull);
    });
  });
}