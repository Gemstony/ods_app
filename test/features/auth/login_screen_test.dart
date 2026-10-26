import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/network/api_client.dart';
import 'package:ods_app/core/network/token_service.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/local/secure_storage.dart';
import 'package:ods_app/features/auth/presentation/screens/login_screen.dart';
import 'package:ods_app/shared/providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────
// Mock adapters
// ─────────────────────────────────────────────────────────────────────

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

class _DelayedMockAdapter implements HttpClientAdapter {
  _DelayedMockAdapter({required this.statusCode, required this.body});
  final int statusCode;
  final Map<String, dynamic>? body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
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

/// Swaps the shared `ApiClient.instance.dio` adapter for the duration of a
/// test, then restores it. The interceptor chain (installed once in
/// `setUpAll`) stays in place across the swap, so error mapping and auth
/// header logic behave exactly as they do in production.
class _AdapterSwap {
  _AdapterSwap(this.adapter);
  final HttpClientAdapter adapter;
  HttpClientAdapter? _original;

  void install() {
    _original = ApiClient.instance.dio.httpClientAdapter;
    ApiClient.instance.dio.httpClientAdapter = adapter;
  }

  void restore() {
    if (_original != null) {
      ApiClient.instance.dio.httpClientAdapter = _original!;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// Canned payloads
// ─────────────────────────────────────────────────────────────────────

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
          'dispatcher_enabled': false,
          'permissions': <String>['manage_users', 'manage_branches'],
        },
        'access_token': 'sample-access-token',
        'refresh_token': 'sample-refresh-token-${'x' * 46}',
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

Map<String, dynamic> _pendingUserPayload() => {
      'success': false,
      'message':
          'Your account is pending approval. Please wait for the administrator.',
      'errors': null,
    };

Map<String, dynamic> _invalidCredentialsPayload() => {
      'success': false,
      'message': 'Invalid email or password.',
      'errors': null,
    };

// ─────────────────────────────────────────────────────────────────────
// Test harness
// ─────────────────────────────────────────────────────────────────────

/// Wraps the login screen in a real router with stub dashboards at each
/// role path, so we can assert on navigation without pulling in the real
/// dashboard widgets.
///
/// Always overrides `secureStorageProvider` with an `InMemorySecureStorage`
/// so `signIn` runs without hitting platform channels. Pass [storage] to
/// inspect persisted tokens after the test.
Widget _wrap({required Widget child, InMemorySecureStorage? storage}) {
  final effectiveStorage = storage ?? InMemorySecureStorage();

  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => child),
      GoRoute(
        path: '/owner',
        builder: (_, __) => const Scaffold(body: Text('Owner dashboard')),
      ),
      GoRoute(
        path: '/distributor',
        builder: (_, __) =>
            const Scaffold(body: Text('Distributor dashboard')),
      ),
      GoRoute(
        path: '/manager',
        builder: (_, __) => const Scaffold(body: Text('Manager dashboard')),
      ),
      GoRoute(
        path: '/rider',
        builder: (_, __) => const Scaffold(body: Text('Rider dashboard')),
      ),
      GoRoute(
        path: '/receiver',
        builder: (_, __) => const Scaffold(body: Text('Receiver dashboard')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      secureStorageProvider.overrideWithValue(effectiveStorage),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    AppConfig.initialize();

    // Install the production interceptor chain on the shared ApiClient
    // so that 4xx responses are mapped to typed AppExceptions (validation
    // / client / auth) exactly as they would be in the running app.
    //
    // Without this, `_AdapterSwap` swaps the raw transport but the
    // resulting DioException is unmapped — the login screen never sees
    // failure.fieldErrors and never has a server message to display.
    ApiClient.instance.initialize(
      tokenService: TokenService(storage: InMemorySecureStorage()),
    );
  });

  // ─── 1. Client-side validation ────────────────────────────────
  testWidgets('shows client-side validation errors on empty submit',
      (tester) async {
    final swap = _AdapterSwap(_MockAdapter(
      statusCode: 200,
      body: _loginSuccessPayload(),
    ))..install();
    addTearDown(swap.restore);

    await tester.pumpWidget(_wrap(child: const LoginScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
    expect(find.text('Owner dashboard'), findsNothing);
  });

  // ─── 2. Successful login ──────────────────────────────────────
  testWidgets(
      'successful login persists tokens and navigates to role dashboard',
      (tester) async {
    final storage = InMemorySecureStorage();
    final swap = _AdapterSwap(_MockAdapter(
      statusCode: 200,
      body: _loginSuccessPayload(),
    ))..install();
    addTearDown(swap.restore);

    await tester.pumpWidget(
      _wrap(child: const LoginScreen(), storage: storage),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'ahmed@ods.test');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'YourStrongPassword123!');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pumpAndSettle();

    // Navigated by role
    expect(find.text('Owner dashboard'), findsOneWidget);

    // Tokens persisted under the keys TokenService uses
    expect(await storage.read('ods.auth.access_token'), 'sample-access-token');
    expect(await storage.read('ods.auth.refresh_token'),
        startsWith('sample-refresh-token'));
    expect(await storage.read('ods.auth.role'), 'owner');
    expect(await storage.read('ods.auth.user_id'), '42');
    expect(await storage.read('ods.auth.display_name'), 'Ahmed Juma');
  });

  // ─── 3. 422 → inline field errors ─────────────────────────────
  testWidgets('422 maps field errors to inline text under each field',
      (tester) async {
    final swap = _AdapterSwap(_MockAdapter(
      statusCode: 422,
      body: _validationErrorPayload(),
    ))..install();
    addTearDown(swap.restore);

    await tester.pumpWidget(_wrap(child: const LoginScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'x@ods.test');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'whatever');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('The email field is required.'), findsOneWidget);
    expect(find.text('The password field is required.'), findsOneWidget);
    expect(find.text('Owner dashboard'), findsNothing);
  });

  // ─── 4. 403 → SnackBar with server message ────────────────────
  testWidgets('403 pending approval shows server message in snackbar',
      (tester) async {
    final swap = _AdapterSwap(_MockAdapter(
      statusCode: 403,
      body: _pendingUserPayload(),
    ))..install();
    addTearDown(swap.restore);

    await tester.pumpWidget(_wrap(child: const LoginScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'pending@ods.test');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'whatever');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.textContaining('pending approval'), findsOneWidget);
    expect(find.text('Owner dashboard'), findsNothing);
  });

  // ─── 5. 401 → SnackBar with server message ────────────────────
  testWidgets('401 wrong credentials shows server message in snackbar',
      (tester) async {
    final swap = _AdapterSwap(_MockAdapter(
      statusCode: 401,
      body: _invalidCredentialsPayload(),
    ))..install();
    addTearDown(swap.restore);

    await tester.pumpWidget(_wrap(child: const LoginScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'ahmed@ods.test');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'wrong');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password.'), findsOneWidget);
    expect(find.text('Owner dashboard'), findsNothing);
  });

  // ─── 6. Loading state ─────────────────────────────────────────
  testWidgets('"Sign in" button shows loading state while submitting',
      (tester) async {
    final swap = _AdapterSwap(_DelayedMockAdapter(
      statusCode: 200,
      body: _loginSuccessPayload(),
    ))..install();
    addTearDown(swap.restore);

    await tester.pumpWidget(_wrap(child: const LoginScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'ahmed@ods.test');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'YourStrongPassword123!');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pump(); // one frame — submit is in-flight

    // Spinner replaces the "Sign in" label during the request.
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pumpAndSettle();
    expect(find.text('Owner dashboard'), findsOneWidget);
  });
}