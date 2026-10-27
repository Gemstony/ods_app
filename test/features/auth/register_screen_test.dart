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
import 'package:ods_app/features/auth/presentation/screens/register_screen.dart';
import 'package:ods_app/shared/providers/auth_provider.dart';

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

Map<String, dynamic> _registerSuccessPayload() => {
      'success': true,
      'message': 'Registration successful. Your account is pending approval.',
      'data': {
        'id': 99,
        'name': 'John Distributor',
        'email': 'john@example.com',
        'phone': '0712345678',
        'role': 'distributor',
        'status': 'pending',
        'distributor_id': 'NEO12345',
        'dispatcher_enabled': false,
        'permissions': <String>['create_delivery_requests'],
      },
    };

Map<String, dynamic> _duplicateEmailPayload() => {
      'success': false,
      'message': 'Validation failed.',
      'errors': {
        'email': ['This email is already registered.'],
      },
    };

Map<String, dynamic> _weakPasswordPayload() => {
      'success': false,
      'message': 'Validation failed.',
      'errors': {
        'password': ['Password must be at least 8 characters.'],
      },
    };

Widget _wrap({required Widget child, InMemorySecureStorage? storage}) {
  final effectiveStorage = storage ?? InMemorySecureStorage();
  final router = GoRouter(
    initialLocation: '/register',
    routes: [
      GoRoute(path: '/register', builder: (_, __) => child),
      GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(body: Text('Login stub')),
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

/// Scrolls the submit button into view, then taps it.
///
/// The register form is taller than the 600px test viewport — the button
/// lands at y≈618 and `tester.tap()` misses silently (warnIfMissed
/// default). `ensureVisible` scrolls it into view first.
Future<void> _tapCreateAccount(WidgetTester tester) async {
  final button = find.widgetWithText(ElevatedButton, 'Create account');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _fillValidForm(WidgetTester tester) async {
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'), 'John Distributor');
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Distributor ID'), 'NEO12345');
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'), 'john@example.com');
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone'), '0712345678');
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'), 'SecretPass123!');
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'), 'SecretPass123!');
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    AppConfig.initialize();
    ApiClient.instance.initialize(
      tokenService: TokenService(storage: InMemorySecureStorage()),
    );
  });

  testWidgets('shows validation errors on empty submit', (tester) async {
    final swap = _AdapterSwap(_MockAdapter(
      statusCode: 201,
      body: _registerSuccessPayload(),
    ))..install();
    addTearDown(swap.restore);

    await tester.pumpWidget(_wrap(child: const RegisterScreen()));
    await tester.pumpAndSettle();

    await _tapCreateAccount(tester);

    // Scroll to see all validation errors at once — the form is taller
    // than the viewport.
    await tester.scrollUntilVisible(
      find.text('Password is required.'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Your full name is required.'), findsOneWidget);
    expect(find.text('Distributor ID is required.'), findsOneWidget);
    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Phone number is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });

  testWidgets('mismatched password confirmation shows inline error',
      (tester) async {
    final swap = _AdapterSwap(_MockAdapter(
      statusCode: 201,
      body: _registerSuccessPayload(),
    ))..install();
    addTearDown(swap.restore);

    await tester.pumpWidget(_wrap(child: const RegisterScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'), 'John Distributor');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Distributor ID'), 'NEO12345');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'), 'john@example.com');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone'), '0712345678');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'SecretPass123!');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'), 'DifferentPass!');
    await tester.pumpAndSettle();

    await _tapCreateAccount(tester);

    await tester.scrollUntilVisible(
      find.text('Passwords do not match.'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match.'), findsOneWidget);
  });

  testWidgets('successful registration shows pending-approval dialog',
      (tester) async {
    final swap = _AdapterSwap(_MockAdapter(
      statusCode: 201,
      body: _registerSuccessPayload(),
    ))..install();
    addTearDown(swap.restore);

    await tester.pumpWidget(_wrap(child: const RegisterScreen()));
    await tester.pumpAndSettle();

    await _fillValidForm(tester);
    await _tapCreateAccount(tester);

    expect(find.text('Account created'), findsOneWidget);
    expect(find.textContaining('pending approval'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Back to sign in'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Back to sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Login stub'), findsOneWidget);
  });

  testWidgets('422 duplicate email shows inline error under email field',
      (tester) async {
    final swap = _AdapterSwap(_MockAdapter(
      statusCode: 422,
      body: _duplicateEmailPayload(),
    ))..install();
    addTearDown(swap.restore);

    await tester.pumpWidget(_wrap(child: const RegisterScreen()));
    await tester.pumpAndSettle();

    await _fillValidForm(tester);
    await _tapCreateAccount(tester);

    expect(find.text('This email is already registered.'), findsOneWidget);
    expect(find.text('Account created'), findsNothing);
  });

  testWidgets('422 weak password shows inline error under password field',
      (tester) async {
    final swap = _AdapterSwap(_MockAdapter(
      statusCode: 422,
      body: _weakPasswordPayload(),
    ))..install();
    addTearDown(swap.restore);

    await tester.pumpWidget(_wrap(child: const RegisterScreen()));
    await tester.pumpAndSettle();

    await _fillValidForm(tester);
    await _tapCreateAccount(tester);

    expect(
      find.text('Password must be at least 8 characters.'),
      findsOneWidget,
    );
  });
}