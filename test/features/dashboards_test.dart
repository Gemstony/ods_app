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
/// Each test navigates to a dashboard via the dev role-jump chip on the login
/// screen, then asserts on the dashboard's structure (AppBar, NavigationBar,
/// selected tab index). Tests deliberately avoid asserting on tab *content*
/// text — IndexedStack keeps all tab bodies in the tree, so `find.text()`
/// finds labels in any tab, not just the visible one. `selectedIndex` is the
/// only reliable signal that a tab switch happened.
void main() {
  // ─── Owner ─────────────────────────────────────────────────────────
  testWidgets('Owner dashboard renders with 5 tabs', (tester) async {
    await _bootTo(tester, 'Owner');

    expect(find.byType(OwnerDashboardScreen), findsOneWidget);
    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.destinations.length, 5);
    expect(navBar.selectedIndex, 0);

    // Tab labels appear on the nav bar.
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
    expect(navBar.selectedIndex, 0);

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

    // Initially on Home (index 0).
    var navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 0);

    // Tap Branches (index 1). NavigationBar handles its own hit test.
    await tester.tap(find.text('Branches').last);
    await tester.pumpAndSettle();

    navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 1);

    // Tap Finance (index 3).
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

/// Navigates from app boot to a given dashboard via the dev role-jump chip.
/// Handles the splash timer and route transitions correctly.
Future<void> _bootTo(WidgetTester tester, String roleLabel) async {
  AppConfig.initialize();
  await tester.pumpWidget(const OdsApp());

  // Splash → login.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1600));
  await tester.pumpAndSettle();
  expect(find.byType(LoginScreen), findsOneWidget);

  // Login → dashboard.
  await tester.tap(find.widgetWithText(ActionChip, roleLabel));
  await tester.pumpAndSettle();
}