import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/app.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/network/api_client.dart';
import 'package:ods_app/core/network/token_service.dart';
import 'package:ods_app/data/local/secure_storage.dart';
import 'package:ods_app/data/models/delivery.dart';
import 'package:ods_app/features/auth/presentation/screens/login_screen.dart';
import 'package:ods_app/features/distributor/presentation/screens/distributor_dashboard_screen.dart';
import 'package:ods_app/features/owner/presentation/screens/owner_dashboard_screen.dart';
import 'package:ods_app/shared/providers/auth_provider.dart';
import 'package:ods_app/shared/providers/branch_providers.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';
import 'package:ods_app/widgets/delivery_card.dart';

// ─────────────────────────────────────────────────────────────────────
// Path-aware mock adapter
// ─────────────────────────────────────────────────────────────────────

class _PathAwareMock implements HttpClientAdapter {
  _PathAwareMock([Map<String, _MockResponse>? initial])
      : routes = initial ?? {};

  final Map<String, _MockResponse> routes;

  /// Every request that hit the adapter, formatted as `METHOD /path`.
  final List<String> captured = [];

  void on(String path, _MockResponse response) => routes[path] = response;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured.add('${options.method} ${options.path}');
    final response = routes[options.path];
    if (response == null) {
      return ResponseBody.fromString(
        jsonEncode({
          'success': false,
          'message': 'Not mocked: ${options.path}',
          'errors': null,
        }),
        404,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MockResponse {
  _MockResponse(this.statusCode, this.body);
  final int statusCode;
  final Map<String, dynamic> body;
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

// ─────────────────────────────────────────────────────────────────────
// Response fixtures
// ─────────────────────────────────────────────────────────────────────

Map<String, dynamic> _loginBody({
  int userId = 42,
  String role = 'owner',
  String email = 'owner@ods.test',
  int? branchId,
}) =>
    {
      'success': true,
      'message': 'Login successful.',
      'data': {
        'user': {
          'id': userId,
          'name': 'Ahmed Juma',
          'email': email,
          'phone': '0712345678',
          'role': role,
          'status': 'active',
          'branch_id': branchId,
          'distributor_id': role == 'distributor' ? 'NEO-12345' : null,
          'dispatcher_enabled': false,
          'permissions': <String>['manage_users', 'manage_branches'],
        },
        'access_token': 'sample-access-token',
        'refresh_token': 'sample-refresh-${'a' * 50}',
        'token_type': 'bearer',
        'expires_in': 3600,
      },
    };

Map<String, dynamic> _branchesBody() => {
      'success': true,
      'message': 'OK',
      'data': {
        'data': [
          _branchJson(id: 1, code: 'DSM-01', name: 'Dar es Salaam Central'),
          _branchJson(id: 2, code: 'ARU-01', name: 'Arusha Branch'),
        ],
      },
    };

Map<String, dynamic> _branchJson({
  required int id,
  required String code,
  required String name,
}) =>
    {
      'id': id,
      'name': name,
      'code': code,
      'address': '123 Kariakoo, DSM',
      'latitude': -6.79,
      'longitude': 39.20,
      'operating_hours': {
        'monday': {'open': '08:00', 'close': '18:00'},
      },
      'status': 'active',
      'created_by': 42,
      'created_at': '2026-10-24T07:00:00+00:00',
      'updated_at': '2026-10-24T07:00:00+00:00',
      'deleted_at': null,
    };

Map<String, dynamic> _deliveriesBody() => {
      'success': true,
      'message': 'OK',
      'data': {
        'data': [_deliveryJson()],
      },
    };

Map<String, dynamic> _deliveryJson() => {
      'id': 1,
      'tracking_id': 'ODS-20261024-XYZ789',
      'distributor_id': 42,
      'pickup_branch_id': 1,
      'service_type': 'receive',
      'status': 'paid',
      'pickup_address': '123 Kariakoo',
      'pickup_latitude': -6.79,
      'pickup_longitude': 39.20,
      'pickup_contact_phone': '0712345678',
      'destination_address': '456 Upanga',
      'destination_latitude': -6.78,
      'destination_longitude': 39.22,
      'destination_region': null,
      'destination_district': null,
      'destination_bus_stop': null,
      'recipient_name': null,
      'recipient_phone': null,
      'distance_km': 3.2,
      'rate_per_km': 500.00,
      'minimum_fee': 1000.00,
      'rounding_increment': 500,
      'calculated_fee': 1600.00,
      'ods_delivery_fee': 2000.00,
      'bus_cargo_fare': null,
      'discount_amount': 0.00,
      'discount_reason': null,
      'total_amount': 2000.00,
      'currency': 'TZS',
      'rider_id': null,
      'assigned_at': null,
      'assignment_expires_at': null,
      'accepted_at': null,
      'picked_up_at': null,
      'delivered_at': null,
      'dispatcher_id': null,
      'dispatched_at': null,
      'batch_id': null,
      'batch_window_start': null,
      'batch_window_end': null,
      'assignment_group_id': null,
      'cancelled_at': null,
      'cancelled_by': null,
      'cancellation_reason': null,
      'notes': null,
      'created_at': '2026-10-24T07:00:00+00:00',
      'updated_at': '2026-10-24T07:00:00+00:00',
      'deleted_at': null,
    };

// ─────────────────────────────────────────────────────────────────────
// Boot + login helpers
// ─────────────────────────────────────────────────────────────────────

Future<void> _bootToLogin(WidgetTester tester) async {
  await tester.pumpWidget(
    OdsApp(
      overrides: [
        secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
      ],
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1600));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));

  expect(
    find.byType(LoginScreen),
    findsOneWidget,
    reason: 'Splash should have transitioned to login after 1600ms',
  );
}

Future<ProviderContainer> _doLogin(
  WidgetTester tester, {
  required String email,
  required String password,
}) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Email'),
    email,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Password'),
    password,
  );
  await tester.pump(const Duration(milliseconds: 50));

  final signIn = find.widgetWithText(ElevatedButton, 'Sign in');
  await tester.ensureVisible(signIn);
  await tester.pump(const Duration(milliseconds: 50));

  await tester.tap(signIn);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));

  return ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
    listen: false,
  );
}

/// Runs a repository call in the real async zone.
///
/// **This is the critical primitive for widget tests doing network I/O.**
/// The test body runs in a fake-async zone where Dio's internal timers
/// never fire unless you `pump()`. Since `await repo.method()` blocks the
/// body (no pumping possible), the request deadlocks.
///
/// `tester.runAsync` executes the closure outside the fake-async zone
/// where real timers fire normally. The result comes back to the test
/// body once the I/O completes.
Future<T> _doAsync<T>(WidgetTester tester, Future<T> Function() fn) async {
  final result = await tester.runAsync(fn);
  if (result == null) {
    throw StateError('runAsync returned null — the closure threw or was '
        'cancelled. Check stderr for the underlying error.');
  }
  return result;
}

// ─────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    AppConfig.initialize();
    ApiClient.instance.initialize(
      tokenService: TokenService(storage: InMemorySecureStorage()),
    );
  });

  // ─── Test 1: Auth pipeline end-to-end ──────────────────────────
  testWidgets(
    'E2E: login as Owner → dashboard renders → providers reflect state',
    (tester) async {
      final mock = _PathAwareMock({
        '/auth/login': _MockResponse(200, _loginBody()),
      });
      final swap = _AdapterSwap(mock)..install();
      addTearDown(swap.restore);

      await _bootToLogin(tester);
      final container = await _doLogin(
        tester,
        email: 'owner@ods.test',
        password: 'secret-pass',
      );

      expect(
        mock.captured,
        contains('POST /auth/login'),
        reason: 'Login request did not hit the mock adapter. '
            'Captured: ${mock.captured}',
      );

      expect(find.byType(OwnerDashboardScreen), findsOneWidget);

      expect(container.read(isAuthenticatedProvider), isTrue);
      expect(container.read(currentRoleProvider), 'owner');
      expect(container.read(currentUserIdProvider), '42');
      expect(container.read(currentUserProvider)?.email, 'owner@ods.test');
      expect(container.read(currentUserProvider)?.isOwner, isTrue);
      expect(container.read(currentBranchIdProvider), isNull);
    },
  );

  // ─── Test 2: Repository works through the full stack ──────────
  testWidgets(
    'E2E: repository call after login parses correctly through interceptors',
    (tester) async {
      final mock = _PathAwareMock({
        '/auth/login': _MockResponse(200, _loginBody()),
        '/owner/branches': _MockResponse(200, _branchesBody()),
      });
      final swap = _AdapterSwap(mock)..install();
      addTearDown(swap.restore);

      await _bootToLogin(tester);
      final container = await _doLogin(
        tester,
        email: 'owner@ods.test',
        password: 'secret-pass',
      );

      expect(
        mock.captured,
        contains('POST /auth/login'),
        reason: 'Login request did not hit the mock adapter',
      );
      expect(find.byType(OwnerDashboardScreen), findsOneWidget);

      // ─── FIX: run the repository call in the real async zone ────
      final branchRepo = container.read(branchRepositoryProvider);
      final result = await _doAsync(tester, () => branchRepo.list());

      expect(
        mock.captured,
        contains('GET /owner/branches'),
        reason: 'Branch request did not hit the mock adapter. '
            'Captured: ${mock.captured}',
      );

      expect(result.isSuccess, isTrue);
      final branches = result.dataOrNull!;
      expect(branches.length, 2);
      expect(branches[0].code, 'DSM-01');
      expect(branches[0].name, 'Dar es Salaam Central');
      expect(branches[0].isActive, isTrue);
      expect(branches[1].code, 'ARU-01');
      expect(branches[1].name, 'Arusha Branch');
    },
  );

  // ─── Test 3: API data renders through widget layer ────────────
  testWidgets(
    'E2E: fetched delivery renders correctly through DeliveryCard',
    (tester) async {
      final mock = _PathAwareMock({
        '/auth/login': _MockResponse(
          200,
          _loginBody(role: 'distributor', email: 'dist@ods.test'),
        ),
        '/distributor/deliveries': _MockResponse(200, _deliveriesBody()),
      });
      final swap = _AdapterSwap(mock)..install();
      addTearDown(swap.restore);

      await _bootToLogin(tester);
      final container = await _doLogin(
        tester,
        email: 'dist@ods.test',
        password: 'secret-pass',
      );

      expect(
        mock.captured,
        contains('POST /auth/login'),
        reason: 'Login request did not hit the mock adapter',
      );
      expect(find.byType(DistributorDashboardScreen), findsOneWidget);

      final deliveryRepo = container.read(deliveryRepositoryProvider);
      final result =
          await _doAsync(tester, () => deliveryRepo.listMine());

      expect(
        mock.captured,
        contains('GET /distributor/deliveries'),
        reason: 'Delivery request did not hit the mock adapter. '
            'Captured: ${mock.captured}',
      );

      expect(result.isSuccess, isTrue);
      final delivery = result.dataOrNull!.first;
      expect(delivery.trackingId, 'ODS-20261024-XYZ789');
      expect(delivery.serviceType, ServiceType.receive);
      expect(delivery.status, DeliveryStatus.paid);

      // Render the fetched delivery.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: DeliveryCard(delivery: delivery),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('ODS-20261024-XYZ789'), findsOneWidget);
      expect(find.text('Receive'), findsOneWidget);
      expect(find.text('Ready for pickup'), findsOneWidget);
      expect(find.text('456 Upanga'), findsOneWidget);
      expect(find.text('TZS 2000'), findsOneWidget);
    },
  );

  // ─── Test 4: Failure mapping through the full stack ───────────
  testWidgets(
    'E2E: unmocked endpoint maps to notFound through interceptor chain',
    (tester) async {
      // /owner/branches intentionally NOT mocked → 404.
      final mock = _PathAwareMock({
        '/auth/login': _MockResponse(200, _loginBody()),
      });
      final swap = _AdapterSwap(mock)..install();
      addTearDown(swap.restore);

      await _bootToLogin(tester);
      final container = await _doLogin(
        tester,
        email: 'owner@ods.test',
        password: 'secret-pass',
      );

      expect(
        mock.captured,
        contains('POST /auth/login'),
        reason: 'Login request did not hit the mock adapter',
      );
      expect(find.byType(OwnerDashboardScreen), findsOneWidget);

      final branchRepo = container.read(branchRepositoryProvider);
      final result = await _doAsync(tester, () => branchRepo.list());

      expect(
        mock.captured,
        contains('GET /owner/branches'),
        reason: 'Branch request did not hit the mock adapter',
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.type.name, 'notFound');
      expect(result.failureOrNull!.isRetryable, isFalse);
    },
  );
}