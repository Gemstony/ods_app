import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/features/distributor/presentation/screens/distributor_dashboard_screen.dart';
import 'package:ods_app/features/manager/presentation/screens/manager_dashboard_screen.dart';
import 'package:ods_app/features/owner/presentation/screens/owner_dashboard_screen.dart';
import 'package:ods_app/features/receiver/presentation/screens/receiver_dashboard_screen.dart';
import 'package:ods_app/features/rider/presentation/screens/rider_dashboard_screen.dart';

/// Minimal router that renders [dashboard] directly at /dashboard, and a
/// stub at /login so the dashboard's AppBar logout action (which calls
/// `context.go(RouteNames.login)`) doesn't throw during interaction tests.
Widget _wrapDashboard(Widget dashboard) {
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(path: '/dashboard', builder: (_, __) => dashboard),
      GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(body: Text('Login stub')),
      ),
    ],
  );

  return ProviderScope(
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router,
    ),
  );
}

Future<void> _pumpDashboard(WidgetTester tester, Widget dashboard) async {
  await tester.pumpWidget(_wrapDashboard(dashboard));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(AppConfig.initialize);

  testWidgets('Owner dashboard renders with 5 tabs', (tester) async {
    await _pumpDashboard(tester, const OwnerDashboardScreen());

    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.destinations.length, 5);
    expect(navBar.selectedIndex, 0);

    for (final label in ['Home', 'Branches', 'Users', 'Finance', 'Settings']) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('Manager dashboard renders with 5 tabs', (tester) async {
    await _pumpDashboard(tester, const ManagerDashboardScreen());
    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.destinations.length, 5);
    for (final label in ['Home', 'Staff', 'Deliveries', 'Packages', 'Profile']) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('Distributor dashboard renders with 5 tabs', (tester) async {
    await _pumpDashboard(tester, const DistributorDashboardScreen());
    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.destinations.length, 5);
    for (final label in ['Home', 'New', 'History', 'Rewards', 'Profile']) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('Rider dashboard renders with 4 tabs', (tester) async {
    await _pumpDashboard(tester, const RiderDashboardScreen());
    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.destinations.length, 4);
    for (final label in ['Tasks', 'Active', 'Earnings', 'Profile']) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('Receiver dashboard renders with 4 tabs', (tester) async {
    await _pumpDashboard(tester, const ReceiverDashboardScreen());
    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.destinations.length, 4);
    for (final label in ['Packages', 'Regional', 'History', 'Profile']) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('tapping a tab updates the selected index', (tester) async {
    await _pumpDashboard(tester, const OwnerDashboardScreen());

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
}