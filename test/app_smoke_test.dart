import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ods_app/app.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/local/secure_storage.dart';
import 'package:ods_app/data/models/auth/auth_user.dart';
import 'package:ods_app/data/repositories/auth_repository.dart';
import 'package:ods_app/features/auth/presentation/screens/login_screen.dart';
import 'package:ods_app/features/auth/presentation/screens/splash_screen.dart';
import 'package:ods_app/features/owner/presentation/screens/owner_dashboard_screen.dart';
import 'package:ods_app/shared/providers/auth_provider.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/models/dashboard_kpis.dart';
import 'package:ods_app/data/repositories/dashboard_repository.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';
import 'package:ods_app/data/models/auth/auth_user.dart';
import 'package:ods_app/data/repositories/user_repository.dart';
import 'package:ods_app/data/models/finance_summary.dart';
import 'package:ods_app/data/repositories/finance_repository.dart';

// ─────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────

/// Boots the full app with an empty `InMemorySecureStorage`.
///
/// Without this override, `SessionNotifier.restoreSession()` calls
/// `SecureStorage.read()` — a platform channel that hangs in a widget test
/// (no handler registered). The splash's `Future.wait([restore, 1500ms])`
/// would then never resolve, and we'd never leave `/splash`.
Future<void> _pumpApp(WidgetTester tester) async {
  AppConfig.initialize();
  await tester.pumpWidget(
    // KeyedSubtree with a UniqueKey forces Flutter to build a fresh
    // widget tree on every pumpWidget. Without it, Riverpod's
    // ProviderScope can be reused across tests (or across consecutive
    // pumps in the same test), and asserts because the override count
    // between the two configurations differs.
    KeyedSubtree(
      key: UniqueKey(),
      child: OdsApp(
        overrides: [
          secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
        ],
      ),
    ),
  );
}

/// Boots the app with an empty storage, waits through the splash timer,
/// and settles on the login screen. Every signed-out test starts here.
Future<void> _bootToLogin(WidgetTester tester) async {
  await _pumpApp(tester);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1600));
  await tester.pumpAndSettle();
  expect(find.byType(LoginScreen), findsOneWidget);
}

/// Minimal fake: restores an Owner on startup without touching the network.
///
/// Only `/auth/me` is stubbed. Any other method inherited from
/// `AuthRepository` would hit the real `ApiClient` — fine here because
/// none of the smoke tests call them.
class _SignedInAuthRepository extends AuthRepository {
  @override
  Future<ApiResult<AuthUser>> me() async => const ApiSuccess<AuthUser>(
        AuthUser(
          id: 42,
          name: 'Test Owner',
          email: 'owner@test.local',
          phone: '0700000000',
          role: 'owner',
          status: 'active',
          dispatcherEnabled: false,
          permissions: ['manage_users'],
        ),
      );
}

/// Prevents the Owner dashboard's Users tab from calling the real
/// `/owner/users` endpoint during smoke tests. Returns an empty list.
class _FakeUserRepository extends UserRepository {
  _FakeUserRepository() : super(dio: Dio());

  @override
  Future<ApiResult<List<AuthUser>>> list({
    String? role,
    String? status,
    int? branchId,
    String? search,
    int? perPage,
    int page = 1,
  }) async =>
      const ApiSuccess<List<AuthUser>>([]);
}

class _FakeFinanceRepository extends FinanceRepository {
  _FakeFinanceRepository() : super(dio: Dio());

  @override
  Future<ApiResult<FinanceSummary>> getSummary() async =>
      ApiSuccess(FinanceSummary.empty());
}

/// Minimal fake: returns an empty `DashboardKpis` immediately, so the
/// signed-in Owner's dashboard doesn't attempt a real network call.
class _FakeDashboardRepository extends DashboardRepository {
  _FakeDashboardRepository() : super(dio: Dio());

  @override
  Future<ApiResult<DashboardKpis>> getKpis() async =>
      ApiSuccess(DashboardKpis.empty());
}

/// Boots the app with pre-populated tokens and a fake `/me`, so the
/// splash's session-restore path succeeds and lands on the Owner dashboard.
Future<void> _bootToSignedInOwner(WidgetTester tester) async {
  AppConfig.initialize();

  final storage = InMemorySecureStorage();
  await storage.write('ods.auth.access_token', 'fake-access');
  await storage.write('ods.auth.refresh_token', 'fake-refresh');

  await tester.pumpWidget(
    // Same KeyedSubtree pattern as _pumpApp — guarantees a fresh tree
    // and a fresh ProviderScope, so the override count change from
    // 1 (signed-out tests) to 5 (this helper) doesn't trip Riverpod's
    // "can't change number of overrides" assertion.
    KeyedSubtree(
      key: UniqueKey(),
      child: OdsApp(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          authRepositoryProvider.overrideWithValue(_SignedInAuthRepository()),
          dashboardRepositoryProvider
              .overrideWithValue(_FakeDashboardRepository()),
          userRepositoryProvider.overrideWithValue(_FakeUserRepository()),
          financeRepositoryProvider.overrideWithValue(_FakeFinanceRepository()),
        ],
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1600));
  await tester.pumpAndSettle();
  expect(find.byType(OwnerDashboardScreen), findsOneWidget);
}
// ─────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────

void main() {
  // ─── Splash ──────────────────────────────────────────────────────
  testWidgets('splash renders brand and auto-routes to login', (tester) async {
    await _pumpApp(tester);
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Zero Distance Services'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome to ODS'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  // ─── Login screen renders without dev artifacts ──────────────────
  testWidgets('login screen renders the auth form', (tester) async {
    await _bootToLogin(tester);

    expect(find.widgetWithText(ElevatedButton, 'Sign in'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);

    // Dev-only artifacts removed in 3.3 must not reappear.
    expect(find.text('Test API connection'), findsNothing);
    expect(find.text('Dev shortcuts'), findsNothing);
    expect(find.widgetWithText(ActionChip, 'Owner'), findsNothing);
  });

  // ─── Theme ───────────────────────────────────────────────────────
  testWidgets('ODS theme is applied after routing', (tester) async {
    await _bootToLogin(tester);

    final ctx = tester.element(find.byType(LoginScreen));
    expect(Theme.of(ctx).useMaterial3, isTrue);
  });

  // ─── Unknown route — signed out ──────────────────────────────────
  testWidgets(
      'unknown route while signed out redirects to login (not errorBuilder)',
      (tester) async {
    await _bootToLogin(tester);

    // Post-3.4: the auth gate intercepts unknown routes for signed-out
    // users and redirects to /login before the router's route table is
    // even consulted. errorBuilder is only reachable for signed-in users
    // who hit a bad path — see the sibling test below.
    final goRouter = GoRouter.of(tester.element(find.byType(LoginScreen)));
    goRouter.go('/this-route-does-not-exist');
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Page not found'), findsNothing);
  });

  // ─── Unknown route — signed in ───────────────────────────────────
  testWidgets('unknown route while signed in falls through to errorBuilder',
      (tester) async {
    await _bootToSignedInOwner(tester);

    // Signed-in users can reach errorBuilder because the redirect returns
    // null for non-login paths (see AppRouter.resolveRedirect).
    final goRouter = GoRouter.of(
      tester.element(find.byType(OwnerDashboardScreen)),
    );
    goRouter.go('/this-route-does-not-exist');
    await tester.pumpAndSettle();

    expect(find.text('Page not found'), findsOneWidget);
    expect(find.textContaining('this-route-does-not-exist'), findsOneWidget);
  });
}
