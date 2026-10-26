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

class AppRouter {
  AppRouter._();

  /// Auth gate. `true` from Phase 3.4 onward.
  static const bool enforceAuth = true;

  static GoRouter build({Listenable? refreshListenable}) {
    return GoRouter(
      initialLocation: RouteNames.splash,
      debugLogDiagnostics: AppConfig.isDev,
      refreshListenable: refreshListenable,
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

  /// Pure redirect logic — exposed for unit tests.
  ///
  /// Rules (top to bottom):
  ///   1. Auth disabled (dev-only escape hatch) → no redirects.
  ///   2. Still restoring AND not on splash → force to splash.
  ///   3. On splash → no redirect (splash controls its own navigation).
  ///   4. Signed in AND on login → home for role.
  ///   5. Signed in elsewhere → allow.
  ///   6. Signed out AND not on login → login.
  ///   7. Signed out on login → allow.
  static String? resolveRedirect({
    required String location,
    required bool isRestoring,
    required String? role,
  }) {
    if (!enforceAuth) return null;

    final isOnSplash = location == RouteNames.splash;
    final isOnLogin = location == RouteNames.login;

    if (isRestoring) {
      return isOnSplash ? null : RouteNames.splash;
    }

    if (isOnSplash) return null;

    if (role != null) {
      return isOnLogin ? RoleGuard.homeForRole(role) : null;
    }

    return isOnLogin ? null : RouteNames.login;
  }

  static String? _redirect(BuildContext context, GoRouterState state) {
    return resolveRedirect(
      location: state.matchedLocation,
      isRestoring: RoleGuard.isRestoring,
      role: RoleGuard.currentRole(),
    );
  }
}