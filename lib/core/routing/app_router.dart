import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/distributor/presentation/screens/distributor_dashboard_screen.dart';
import '../../features/manager/presentation/screens/manager_dashboard_screen.dart';
import '../../features/owner/presentation/screens/owner_dashboard_screen.dart';
import '../../features/receiver/presentation/screens/receiver_dashboard_screen.dart';
import '../../features/rider/presentation/screens/rider_dashboard_screen.dart';
import 'role_guard.dart';
import 'route_names.dart';

/// Builds the app's [GoRouter] instance.
///
/// While [enforceAuth] is `false` (Sub-phases 1.5–1.7 and 1.8 partially),
/// redirects are bypassed so all role dashboards are reachable for testing.
/// Phase 3 flips this to `true` once real auth is wired.
class AppRouter {
  AppRouter._();

  /// Auth gate switch. `false` during early development, `true` from Phase 3.
  static const bool enforceAuth = false;

  static GoRouter build() {
    return GoRouter(
      initialLocation: RouteNames.splash,
      debugLogDiagnostics: AppConfig.isDev,
      redirect: _redirect,
      routes: [
        GoRoute(
          path: RouteNames.splash,
          builder: (_, __) => const SplashScreen(),
        ),
        GoRoute(
          path: RouteNames.login,
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: RouteNames.owner,
          builder: (_, __) => const OwnerDashboardScreen(),
        ),
        GoRoute(
          path: RouteNames.manager,
          builder: (_, __) => const ManagerDashboardScreen(),
        ),
        GoRoute(
          path: RouteNames.distributor,
          builder: (_, __) => const DistributorDashboardScreen(),
        ),
        GoRoute(
          path: RouteNames.rider,
          builder: (_, __) => const RiderDashboardScreen(),
        ),
        GoRoute(
          path: RouteNames.receiver,
          builder: (_, __) => const ReceiverDashboardScreen(),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Page not found')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No route for "${state.uri}".',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  /// The single place where auth + role decide where a user lands.
  ///
  /// Behaviour today ([enforceAuth] = false): no redirects at all.
  /// Behaviour once Phase 3 enables [enforceAuth]:
  ///   - signed out      → forced to /login (unless already on /login or /)
  ///   - signed in       → auth routes redirect to home-for-role
  ///   - signed in       → any other route: allowed (per-screen role checks
  ///                       are added in Phase 3 via route guards, not here)
  static String? _redirect(BuildContext context, GoRouterState state) {
    if (!enforceAuth) return null;

    final role = RoleGuard.currentRole();
    final location = state.matchedLocation;
    final isAuthRoute = location == RouteNames.login || location == RouteNames.splash;

    if (role == null) {
      return isAuthRoute ? null : RouteNames.login;
    }

    if (isAuthRoute) {
      return RoleGuard.homeForRole(role);
    }

    return null;
  }
}