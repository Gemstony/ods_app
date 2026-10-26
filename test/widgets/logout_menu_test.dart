import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/local/secure_storage.dart';
import 'package:ods_app/data/models/auth/auth_tokens.dart';
import 'package:ods_app/data/models/auth/auth_user.dart';
import 'package:ods_app/data/repositories/auth_repository.dart';
import 'package:ods_app/features/owner/presentation/screens/owner_dashboard_screen.dart';
import 'package:ods_app/shared/providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────
// Test double
// ─────────────────────────────────────────────────────────────────────

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({
    this.logoutResult,
    this.logoutAllResult,
    this.throwOnLogout = false,
    this.throwOnLogoutAll = false,
  });

  final ApiResult<void>? logoutResult;
  final ApiResult<void>? logoutAllResult;
  final bool throwOnLogout;
  final bool throwOnLogoutAll;

  int logoutCalls = 0;
  int logoutAllCalls = 0;
  String? lastRefreshToken;

  @override
  Future<ApiResult<void>> logout({String? refreshToken}) async {
    logoutCalls++;
    lastRefreshToken = refreshToken;
    if (throwOnLogout) throw Exception('simulated network failure');
    return logoutResult ?? ApiSuccess<void>(null);
  }

  @override
  Future<ApiResult<void>> logoutAll() async {
    logoutAllCalls++;
    if (throwOnLogoutAll) throw Exception('simulated network failure');
    return logoutAllResult ?? ApiSuccess<void>(null);
  }
}

// ─────────────────────────────────────────────────────────────────────
// Fixtures + harness
// ─────────────────────────────────────────────────────────────────────

AuthUser _user() => const AuthUser(
      id: 42,
      name: 'Ahmed',
      email: 'ahmed@ods.test',
      phone: '0712345678',
      role: 'owner',
      status: 'active',
      dispatcherEnabled: false,
      permissions: ['manage_users'],
    );

AuthTokens _tokens() => const AuthTokens(
      accessToken: 'fake-access',
      refreshToken: 'fake-refresh',
      tokenType: 'bearer',
      expiresIn: 3600,
    );

class _Harness {
  _Harness({
    required this.container,
    required this.storage,
    required this.repo,
    required this.router,
  });

  final ProviderContainer container;
  final InMemorySecureStorage storage;
  final _FakeAuthRepository repo;
  final GoRouter router;

  void dispose() {
    router.dispose();
    container.dispose();
  }
}

Future<_Harness> _pumpSignedInDashboard(
  WidgetTester tester, {
  _FakeAuthRepository? repo,
}) async {
  final storage = InMemorySecureStorage();
  final effectiveRepo = repo ?? _FakeAuthRepository();

  final container = ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(effectiveRepo),
    ],
  );

  // Put the session into a signed-in state before pumping.
  await container.read(sessionProvider.notifier).signIn(
        user: _user(),
        tokens: _tokens(),
      );

  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (_, __) => const OwnerDashboardScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(body: Text('Login stub')),
      ),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();

  return _Harness(
    container: container,
    storage: storage,
    repo: effectiveRepo,
    router: router,
  );
}

Future<void> _openMenuAndTapItem(
  WidgetTester tester,
  String itemText,
) async {
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
  await tester.tap(find.text(itemText));
  await tester.pumpAndSettle();
}

Future<void> _confirmDialog(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
  await tester.pumpAndSettle();
}

// ─────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(AppConfig.initialize);

  group('LogoutMenu — menu rendering', () {
    testWidgets('shows both options', (tester) async {
      final h = await _pumpSignedInDashboard(tester);
      addTearDown(h.dispose);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Log out'), findsOneWidget);
      expect(find.text('Log out from all devices'), findsOneWidget);
    });
  });

  group('LogoutMenu — single-device logout', () {
    testWidgets('cancel in dialog does NOT sign out', (tester) async {
      final h = await _pumpSignedInDashboard(tester);
      addTearDown(h.dispose);

      await _openMenuAndTapItem(tester, 'Log out');

      expect(find.text('Log out?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(h.repo.logoutCalls, 0);
      expect(h.container.read(sessionProvider).valueOrNull, isNotNull);
      expect(await h.storage.read('ods.auth.access_token'), isNotNull);
    });

    testWidgets(
        'confirm calls /auth/logout with refresh token, clears storage, navigates',
        (tester) async {
      final h = await _pumpSignedInDashboard(tester);
      addTearDown(h.dispose);

      await _openMenuAndTapItem(tester, 'Log out');
      await _confirmDialog(tester);

      expect(h.repo.logoutCalls, 1);
      expect(h.repo.logoutAllCalls, 0);
      expect(h.repo.lastRefreshToken, startsWith('fake-refresh'));

      expect(await h.storage.read('ods.auth.access_token'), isNull);
      expect(await h.storage.read('ods.auth.refresh_token'), isNull);
      expect(h.container.read(sessionProvider).valueOrNull, isNull);

      expect(find.text('Login stub'), findsOneWidget);
    });

    testWidgets('logout succeeds locally when backend returns an error',
        (tester) async {
      final h = await _pumpSignedInDashboard(
        tester,
        repo: _FakeAuthRepository(
          logoutResult: ApiFailure<void>(const Failure(
            type: FailureType.auth,
            message: 'Session already dead',
          )),
        ),
      );
      addTearDown(h.dispose);

      await _openMenuAndTapItem(tester, 'Log out');
      await _confirmDialog(tester);

      expect(find.text('Login stub'), findsOneWidget);
      expect(h.container.read(sessionProvider).valueOrNull, isNull);
      expect(await h.storage.read('ods.auth.access_token'), isNull);
    });

    testWidgets('logout succeeds locally when backend throws', (tester) async {
      final h = await _pumpSignedInDashboard(
        tester,
        repo: _FakeAuthRepository(throwOnLogout: true),
      );
      addTearDown(h.dispose);

      await _openMenuAndTapItem(tester, 'Log out');
      await _confirmDialog(tester);

      expect(find.text('Login stub'), findsOneWidget);
      expect(h.container.read(sessionProvider).valueOrNull, isNull);
      expect(await h.storage.read('ods.auth.access_token'), isNull);
    });
  });

  group('LogoutMenu — all-devices logout', () {
    testWidgets(
        'confirm calls /auth/logout-all, clears storage, navigates',
        (tester) async {
      final h = await _pumpSignedInDashboard(tester);
      addTearDown(h.dispose);

      await _openMenuAndTapItem(tester, 'Log out from all devices');
      await _confirmDialog(tester);

      expect(h.repo.logoutAllCalls, 1);
      expect(h.repo.logoutCalls, 0);
      expect(await h.storage.read('ods.auth.access_token'), isNull);
      expect(h.container.read(sessionProvider).valueOrNull, isNull);
      expect(find.text('Login stub'), findsOneWidget);
    });

    testWidgets('all-devices dialog has distinct wording', (tester) async {
      final h = await _pumpSignedInDashboard(tester);
      addTearDown(h.dispose);

      await _openMenuAndTapItem(tester, 'Log out from all devices');

      expect(find.text('Log out from all devices?'), findsOneWidget);
      expect(find.textContaining('every device'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('cancel in all-devices dialog does NOT call logoutAll',
        (tester) async {
      final h = await _pumpSignedInDashboard(tester);
      addTearDown(h.dispose);

      await _openMenuAndTapItem(tester, 'Log out from all devices');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(h.repo.logoutAllCalls, 0);
      expect(h.container.read(sessionProvider).valueOrNull, isNotNull);
    });
  });
}