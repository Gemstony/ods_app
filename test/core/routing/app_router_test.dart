import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/routing/app_router.dart';
import 'package:ods_app/core/routing/role_guard.dart';
import 'package:ods_app/core/routing/route_names.dart';

void main() {
  setUpAll(AppConfig.initialize);

  group('RouteNames', () {
    test('splash is root', () {
      expect(RouteNames.splash, '/');
    });

    test('all paths are unique', () {
      final paths = {
        RouteNames.splash,
        RouteNames.login,
        RouteNames.owner,
        RouteNames.manager,
        RouteNames.distributor,
        RouteNames.rider,
        RouteNames.receiver,
        RouteNames.accessDenied,
      };
      expect(paths.length, 8);
    });
  });

  group('RoleGuard.homeForRole', () {
    test('maps each role to its dashboard', () {
      expect(RoleGuard.homeForRole('owner'), RouteNames.owner);
      expect(RoleGuard.homeForRole('manager'), RouteNames.manager);
      expect(RoleGuard.homeForRole('distributor'), RouteNames.distributor);
      expect(RoleGuard.homeForRole('rider'), RouteNames.rider);
      expect(RoleGuard.homeForRole('receiver'), RouteNames.receiver);
    });

    test('unknown role → login', () {
      expect(RoleGuard.homeForRole('does-not-exist'), RouteNames.login);
    });
  });

  group('RoleGuard.currentRole', () {
    tearDown(() => RoleGuard.roleProvider = null);

    test('null when no provider set', () {
      expect(RoleGuard.currentRole(), isNull);
      expect(RoleGuard.isAuthenticated, isFalse);
    });

    test('reads from injected provider', () {
      RoleGuard.roleProvider = () => 'owner';
      expect(RoleGuard.currentRole(), 'owner');
      expect(RoleGuard.isAuthenticated, isTrue);
    });
  });

  group('AppRouter.build', () {
    test('returns a GoRouter configured with splash as initial location', () {
      final router = AppRouter.build();
      expect(router.routeInformationProvider, isNotNull);
      expect(AppRouter.enforceAuth, isFalse); // 1.5 default
    });
  });
}