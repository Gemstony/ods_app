import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/network/api_interceptors.dart';
import 'package:ods_app/core/network/token_service.dart';
import 'package:ods_app/data/local/secure_storage.dart';

/// Adapter that returns responses in FIFO order. Falls back to the last
/// response if more requests come in than items in the queue.
class _SequenceAdapter implements HttpClientAdapter {
  _SequenceAdapter(this._responses);
  final List<_MockResponse> _responses;
  int _index = 0;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    final response = _responses[_index.clamp(0, _responses.length - 1)];
    if (_index < _responses.length - 1) _index++;
    return ResponseBody.fromString(
      response.body == null ? '' : jsonEncode(response.body),
      response.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MockResponse {
  _MockResponse(this.status, [this.body]);
  final int status;
  final Map<String, dynamic>? body;
}

Map<String, dynamic> _refreshedTokensBody() => {
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
          'permissions': <String>[],
        },
        'access_token': 'new-access',
        'refresh_token': 'new-refresh-${'a' * 50}',
        'token_type': 'bearer',
        'expires_in': 3600,
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  /// Sets up an app Dio + TokenService with controllable adapters.
  Future<({
    Dio dio,
    TokenService tokenService,
    InMemorySecureStorage storage,
    List<String> sessionExpiredEvents,
    _SequenceAdapter appAdapter,
    _SequenceAdapter refreshAdapter,
  })> setup({
    required List<_MockResponse> appResponses,
    required List<_MockResponse> refreshResponses,
  }) async {
    final storage = InMemorySecureStorage();
    await storage.write('ods.auth.access_token', 'stale-token');
    await storage.write('ods.auth.refresh_token', 'good-refresh');

    final refreshAdapter = _SequenceAdapter(refreshResponses);
    final refreshDio = Dio(BaseOptions(
      baseUrl: 'http://localhost:8000/api/v1',
      validateStatus: (s) => s != null && s < 400,
    ))..httpClientAdapter = refreshAdapter;

    final tokenService = TokenService(
      storage: storage,
      refreshDio: refreshDio,
    );

    final appAdapter = _SequenceAdapter(appResponses);
    final appDio = Dio(BaseOptions(
      baseUrl: 'http://localhost:8000/api/v1',
      validateStatus: (s) => s != null && s < 400,
    ))..httpClientAdapter = appAdapter;

    final sessionExpiredEvents = <String>[];
    appDio.interceptors.addAll([
      AuthHeaderInterceptor(tokenService),
      RefreshInterceptor(
        tokenService: tokenService,
        dio: appDio,
        onSessionExpired: () => sessionExpiredEvents.add('expired'),
      ),
      ErrorMappingInterceptor(),
    ]);

    return (
      dio: appDio,
      tokenService: tokenService,
      storage: storage,
      sessionExpiredEvents: sessionExpiredEvents,
      appAdapter: appAdapter,
      refreshAdapter: refreshAdapter,
    );
  }

  test('non-auth error (500) does not trigger refresh', () async {
    final ctx = await setup(
      appResponses: [_MockResponse(500, {'message': 'Server error'})],
      refreshResponses: [_MockResponse(200, _refreshedTokensBody())],
    );

    try {
      await ctx.dio.get('/protected');
      fail('expected DioException');
    } on DioException catch (e) {
      expect(e.response?.statusCode, 500);
    }

    expect(ctx.refreshAdapter.calls, 0);
    expect(ctx.sessionExpiredEvents, isEmpty);
  });

  test('401 on protected endpoint triggers refresh and retries', () async {
    final ctx = await setup(
      appResponses: [
        _MockResponse(401, {'message': 'Unauthenticated.'}),
        _MockResponse(200, {'ok': true}),
      ],
      refreshResponses: [_MockResponse(200, _refreshedTokensBody())],
    );

    final response = await ctx.dio.get('/protected');

    expect(response.statusCode, 200);
    expect(response.data, {'ok': true});
    expect(ctx.refreshAdapter.calls, 1);
    expect(ctx.sessionExpiredEvents, isEmpty);
    // New tokens were persisted
    expect(await ctx.storage.read('ods.auth.access_token'), 'new-access');
  });

  test('refresh failure signs out and propagates original 401', () async {
    final ctx = await setup(
      appResponses: [_MockResponse(401, {'message': 'Unauthenticated.'})],
      refreshResponses: [
        _MockResponse(401, {'message': 'Invalid or expired refresh token.'}),
      ],
    );

    try {
      await ctx.dio.get('/protected');
      fail('expected DioException');
    } on DioException catch (e) {
      expect(e.response?.statusCode, 401);
    }

    expect(ctx.refreshAdapter.calls, 1);
    expect(ctx.sessionExpiredEvents, ['expired']);
  });

  test('parallel 401s trigger exactly one refresh (single-flight)',
      () async {
    final ctx = await setup(
      appResponses: [
        _MockResponse(401, {'message': 'Unauthenticated.'}),
        _MockResponse(401, {'message': 'Unauthenticated.'}),
        _MockResponse(401, {'message': 'Unauthenticated.'}),
        _MockResponse(200, {'ok': true}),
        _MockResponse(200, {'ok': true}),
        _MockResponse(200, {'ok': true}),
      ],
      refreshResponses: [_MockResponse(200, _refreshedTokensBody())],
    );

    final results = await Future.wait([
      ctx.dio.get('/a').then((r) => r.statusCode, onError: (e) => -1),
      ctx.dio.get('/b').then((r) => r.statusCode, onError: (e) => -1),
      ctx.dio.get('/c').then((r) => r.statusCode, onError: (e) => -1),
    ]);

    expect(results.where((code) => code == 200).length, 3);
    // Single-flight: only ONE call to the refresh adapter despite 3x 401s.
    expect(ctx.refreshAdapter.calls, 1);
    expect(ctx.sessionExpiredEvents, isEmpty);
  });

  test('401 on /auth/refresh does NOT loop (propagates)', () async {
    // The app Dio has no refresh attempt because the interceptor sees the
    // /auth/refresh path and skips.
    final ctx = await setup(
      appResponses: [
        _MockResponse(401, {'message': 'Invalid or expired refresh token.'}),
      ],
      refreshResponses: [_MockResponse(200, _refreshedTokensBody())],
    );

    try {
      await ctx.dio.post('/auth/refresh', data: {'refresh_token': 'x'});
      fail('expected DioException');
    } on DioException catch (e) {
      expect(e.response?.statusCode, 401);
    }

    // No refresh was triggered because we skip /auth/refresh path.
    expect(ctx.refreshAdapter.calls, 0);
    expect(ctx.sessionExpiredEvents, isEmpty);
  });

  test('auth header is attached to protected requests but not auth endpoints',
      () async {
    final ctx = await setup(
      appResponses: [
        _MockResponse(200, {'ok': true}),
        _MockResponse(200, {'ok': true}),
      ],
      refreshResponses: [_MockResponse(200, _refreshedTokensBody())],
    );

    // Simulate the adapter capturing the headers of each request.
    final capturedHeaders = <Map<String, dynamic>>[];
    final originalFetch = ctx.appAdapter.fetch;
    ctx.dio.httpClientAdapter = _HeaderCapturingAdapter(
      delegate: ctx.appAdapter,
      captured: capturedHeaders,
    );

    await ctx.dio.get('/protected');
    await ctx.dio.post('/auth/login', data: {'email': 'x', 'password': 'y'});

    expect(capturedHeaders[0]['Authorization'], 'Bearer stale-token');
    expect(capturedHeaders[1].containsKey('Authorization'), isFalse);
    // Silence linter about unused variable
    expect(originalFetch, isNotNull);
  });
}

/// Wraps a delegate adapter and captures outgoing request headers so we
/// can assert on the Authorization header.
class _HeaderCapturingAdapter implements HttpClientAdapter {
  _HeaderCapturingAdapter({
    required this.delegate,
    required this.captured,
  });
  final HttpClientAdapter delegate;
  final List<Map<String, dynamic>> captured;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    captured.add(Map<String, dynamic>.from(options.headers));
    return delegate.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) => delegate.close(force: force);
}