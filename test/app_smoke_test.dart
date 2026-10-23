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
/// Notes:
///   • `pumpAndSettle()` after navigation — route transitions animate over
///     ~300ms; a single `pump()` leaves widgets mid-transition (and, in
///     particular, at their *starting* on-screen offset).
///   • `ensureVisible()` before tapping any widget inside the login's
///     `SingleChildScrollView` — the dev panel is below the fold on an
///     800×600 test viewport, so tap-by-center misses silently.
void main() {
  // ─── Splash ────────────────────────────────────────────────────────
  testWidgets('splash renders brand and auto-routes to login', (tester) async {
    AppConfig.initialize();
    await tester.pumpWidget(const OdsApp());
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Zero Distance Services'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome to ODS'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  // ─── Role jump chips ──────────────────────────────────────────────
  testWidgets('dev role-jump chips navigate to each dashboard',
      (tester) async {
    await _bootToLogin(tester);

    await _tapRoleChip(tester, 'Owner');

    expect(find.byType(OwnerDashboardScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  // ─── Back to login ────────────────────────────────────────────────
  testWidgets('dashboard "Back to login" returns to login', (tester) async {
    await _bootToLogin(tester);

    await _tapRoleChip(tester, 'Owner');
    expect(find.byType(OwnerDashboardScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);

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

// ─── Shared helpers ─────────────────────────────────────────────────

Future<void> _bootToLogin(WidgetTester tester) async {
  AppConfig.initialize();
  await tester.pumpWidget(const OdsApp());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1600));
  await tester.pumpAndSettle();
  expect(find.byType(LoginScreen), findsOneWidget);
}

/// Scrolls the given role chip into view before tapping it.
///
/// The dev section (session chip + dev-sign-in button + role chips) sits
/// below the fold on an 800×600 test viewport. `tester.tap()` by itself
/// computes the widget's center and misses if it's off-screen — this
/// helper makes the intent explicit and reliable.
Future<void> _tapRoleChip(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(ActionChip, label);
  expect(chip, findsOneWidget,
      reason: 'Dev role chip "$label" not found on login screen');

  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();

  await tester.tap(chip);
  await tester.pumpAndSettle();
}