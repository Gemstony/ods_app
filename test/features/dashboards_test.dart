import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/app.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/features/auth/presentation/screens/login_screen.dart';
import 'package:ods_app/features/distributor/presentation/screens/distributor_dashboard_screen.dart';
import 'package:ods_app/features/manager/presentation/screens/manager_dashboard_screen.dart';
import 'package:ods_app/features/owner/presentation/screens/owner_dashboard_screen.dart';
import 'package:ods_app/features/receiver/presentation/screens/receiver_dashboard_screen.dart';
import 'package:ods_app/features/rider/presentation/screens/rider_dashboard_screen.dart';

/// Tests for the five role dashboards built in Sub-phase 1.6.
///
/// As in `app_smoke_test.dart`:
///   • `pumpAndSettle()` after every navigation action so route transitions
///     complete before assertions run.
///   • `ensureVisible()` before tapping the dev role chip, because the dev
///     panel sits below the fold on an 800×600 test viewport.
void main() {
  // ─── Owner ─────────────────────────────────────────────────────────
  testWidgets('Owner dashboard renders with 5 tabs', (tester) async {
    await _bootTo(tester, 'Owner');

    expect(find.byType(OwnerDashboardScreen), findsOneWidget);
    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.destinations.length, 5);
    expect(navBar.selectedIndex, 0);

    for (final label in ['Home', 'Branches', 'Users', 'Finance', 'Settings']) {
      expect(find.text(label), findsWidgets);
    }
  });

  // ─── Manager ───────────────────────────────────────────────────────
  testWidgets('Manager dashboard renders with 5 tabs', (tester) async {
    await _bootTo(tester, 'Manager');

    expect(find.byType(ManagerDashboardScreen), findsOneWidget);
    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.destinations.length, 5);

    for (final label in ['Home', 'Staff', 'Deliveries', 'Packages', 'Profile']) {
      expect(find.text(label), findsWidgets);
    }
  });

  // ─── Distributor ──────────────────────────────────────────────────
  testWidgets('Distributor dashboard renders with 5 tabs', (tester) async {
    await _bootTo(tester, 'Distributor');

    expect(find.byType(DistributorDashboardScreen), findsOneWidget);
    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.destinations.length, 5);

    for (final label in ['Home', 'New', 'History', 'Rewards', 'Profile']) {
      expect(find.text(label), findsWidgets);
    }
  });

  // ─── Rider ────────────────────────────────────────────────────────
  testWidgets('Rider dashboard renders with 4 tabs', (tester) async {
    await _bootTo(tester, 'Rider');

    expect(find.byType(RiderDashboardScreen), findsOneWidget);
    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.destinations.length, 4);

    for (final label in ['Tasks', 'Active', 'Earnings', 'Profile']) {
      expect(find.text(label), findsWidgets);
    }
  });

  // ─── Receiver ─────────────────────────────────────────────────────
  testWidgets('Receiver dashboard renders with 4 tabs', (tester) async {
    await _bootTo(tester, 'Receiver');

    expect(find.byType(ReceiverDashboardScreen), findsOneWidget);
    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.destinations.length, 4);

    for (final label in ['Packages', 'Regional', 'History', 'Profile']) {
      expect(find.text(label), findsWidgets);
    }
  });

  // ─── Tab switching ────────────────────────────────────────────────
  testWidgets('tapping a tab updates the selected index', (tester) async {
    await _bootTo(tester, 'Owner');

    var navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 0);

    await tester.tap(find.text('Branches').last);
    await tester.pumpAndSettle();
    navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 1);

    await tester.tap(find.text('Finance').last);
    await tester.pumpAndSettle();
    navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 3);
  });

  // ─── Back to login ────────────────────────────────────────────────
  testWidgets('logout icon returns to login from any dashboard',
      (tester) async {
    await _bootTo(tester, 'Distributor');

    expect(find.byType(DistributorDashboardScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Back to login'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(DistributorDashboardScreen), findsNothing);
  });
}

// ─── Shared helper ──────────────────────────────────────────────────

/// Boots the app, waits through the splash, settles on login, then taps a
/// role chip (after ensuring it's on-screen) and lands on that dashboard.
Future<void> _bootTo(WidgetTester tester, String roleLabel) async {
  AppConfig.initialize();
  await tester.pumpWidget(const OdsApp());

  // Splash → login
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1600));
  await tester.pumpAndSettle();
  expect(find.byType(LoginScreen), findsOneWidget);

  // Login → dashboard
  final chip = find.widgetWithText(ActionChip, roleLabel);
  expect(chip, findsOneWidget,
      reason: 'Dev role chip "$roleLabel" not found on login screen');
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}