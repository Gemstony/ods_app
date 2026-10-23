import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ods_app/app.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/features/auth/presentation/screens/login_screen.dart';
import 'package:ods_app/features/auth/presentation/screens/splash_screen.dart';
import 'package:ods_app/features/owner/presentation/screens/owner_dashboard_screen.dart';

/// Widget tests for routing + splash + login.
///
/// A note on `pumpAndSettle`:
///   Route transitions animate over several hundred milliseconds. A single
///   `pump()` only advances one frame, so widgets mid-transition are found
///   by finders but their rendered position is still the *starting* offset
///   (often off-screen). Tapping them silently misses.
///   `pumpAndSettle()` advances until there are no scheduled frames, which
///   means transitions complete — after which finders, positions, and tap
///   targets all agree.
///
///   The one place we intentionally do NOT use `pumpAndSettle()` is right
///   after `pumpWidget()`, because the splash has a 1500ms `Timer`, and
///   `pumpAndSettle()` would advance the clock past it and skip the splash
///   state we want to assert.
void main() {
  // ─── Splash ────────────────────────────────────────────────────────
  testWidgets('splash renders brand and auto-routes to login', (tester) async {
    AppConfig.initialize();
    await tester.pumpWidget(const OdsApp());
    await tester.pump(); // one frame is enough to lay out splash

    // Splash is showing — its timer hasn't fired yet.
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Zero Distance Services'), findsOneWidget);

    // Advance past the 1500ms redirect timer.
    await tester.pump(const Duration(milliseconds: 1600));

    // Now wait for the login route's transition to fully complete so
    // SplashScreen has been removed from the tree.
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome to ODS'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  // ─── Role jump chips ──────────────────────────────────────────────
  testWidgets('dev role-jump chips navigate to each dashboard',
      (tester) async {
    await _bootToLogin(tester);

    await tester.tap(find.widgetWithText(ActionChip, 'Owner'));
    await tester.pumpAndSettle(); // transition must complete

    expect(find.byType(OwnerDashboardScreen), findsOneWidget);
    expect(find.text('Owner panel'), findsOneWidget);
  });

  // ─── Back to login ────────────────────────────────────────────────
  testWidgets('placeholder dashboard "Back to login" returns to login',
      (tester) async {
    await _bootToLogin(tester);

    await tester.tap(find.widgetWithText(ActionChip, 'Owner'));
    await tester.pumpAndSettle();
    expect(find.text('Owner panel'), findsOneWidget);
    // Sanity: splash is gone.
    expect(find.byType(SplashScreen), findsNothing);

    // Now the tooltip is at its final on-screen position.
    await tester.tap(find.byTooltip('Back to login'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(OwnerDashboardScreen), findsNothing);
  });

  // ─── Theme ────────────────────────────────────────────────────────
  testWidgets('ODS theme is applied after routing', (tester) async {
    await _bootToLogin(tester);

    final ctx = tester.element(find.byType(LoginScreen));
    expect(Theme.of(ctx).useMaterial3, isTrue);
  });

  // ─── Unknown route ────────────────────────────────────────────────
  testWidgets('unknown route falls through to errorBuilder', (tester) async {
    await _bootToLogin(tester);

    final goRouter = GoRouter.of(tester.element(find.byType(LoginScreen)));
    goRouter.go('/this-route-does-not-exist');
    await tester.pumpAndSettle();

    expect(find.text('Page not found'), findsOneWidget);
    expect(find.textContaining('this-route-does-not-exist'), findsOneWidget);
  });
}

/// Shared helper: boots the app, waits through the splash timer, and
/// settles on the login screen. Every non-splash test starts here.
Future<void> _bootToLogin(WidgetTester tester) async {
  AppConfig.initialize();
  await tester.pumpWidget(const OdsApp());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1600));
  await tester.pumpAndSettle();
  // Precondition — every downstream test assumes login is showing.
  expect(find.byType(LoginScreen), findsOneWidget);
}