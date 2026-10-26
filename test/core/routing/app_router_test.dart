import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/routing/app_router.dart';
import 'package:ods_app/core/routing/role_guard.dart';
import 'package:ods_app/core/routing/route_names.dart';

void main() {
  setUpAll(AppConfig.initialize);

  group('AppRouter config', () {
    test('enforceAuth is on from 3.4 onward', () {
      expect(AppRouter.enforceAuth, isTrue);
    });

    test('build() returns a router', () {
      expect(AppRouter.build(), isNotNull);
    });

    test('build() accepts an optional refreshListenable', () {
      final notifier = ChangeNotifierStub();
      expect(AppRouter.build(refreshListenable: notifier), isNotNull);
      notifier.dispose();
    });
  });

  group('resolveRedirect — while restoring', () {
    test('on splash → stays on splash', () {
      expect(
        AppRouter.resolveRedirect(
          location: RouteNames.splash,
          isRestoring: true,
          role: null,
        ),
        isNull,
      );
    });

    test('on login → forced to splash', () {
      expect(
        AppRouter.resolveRedirect(
          location: RouteNames.login,
          isRestoring: true,
          role: null,
        ),
        RouteNames.splash,
      );
    });

    test('on protected route → forced to splash', () {
      expect(
        AppRouter.resolveRedirect(
          location: RouteNames.owner,
          isRestoring: true,
          role: 'owner', // should be ignored; restore still pending
        ),
        RouteNames.splash,
      );
    });
  });

  group('resolveRedirect — signed out', () {
    test('on login → allowed', () {
      expect(
        AppRouter.resolveRedirect(
          location: RouteNames.login,
          isRestoring: false,
          role: null,
        ),
        isNull,
      );
    });

    test('on splash → allowed (splash handles navigation)', () {
      expect(
        AppRouter.resolveRedirect(
          location: RouteNames.splash,
          isRestoring: false,
          role: null,
        ),
        isNull,
      );
    });

    test('on owner route → forced to login', () {
      expect(
        AppRouter.resolveRedirect(
          location: RouteNames.owner,
          isRestoring: false,
          role: null,
        ),
        RouteNames.login,
      );
    });

    test('on any protected route → forced to login', () {
      for (final path in [
        RouteNames.manager,
        RouteNames.distributor,
        RouteNames.rider,
        RouteNames.receiver,
      ]) {
        expect(
          AppRouter.resolveRedirect(
            location: path,
            isRestoring: false,
            role: null,
          ),
          RouteNames.login,
          reason: 'Expected redirect to login from $path',
        );
      }
    });
  });

  group('resolveRedirect — signed in', () {
    test('on login → home for role', () {
      expect(
        AppRouter.resolveRedirect(
          location: RouteNames.login,
          isRestoring: false,
          role: 'owner',
        ),
        RouteNames.owner,
      );
    });

    test('on splash → allowed (splash owns startup navigation)', () {
      expect(
        AppRouter.resolveRedirect(
          location: RouteNames.splash,
          isRestoring: false,
          role: 'distributor',
        ),
        isNull,
      );
    });

    test('on own role route → allowed', () {
      expect(
        AppRouter.resolveRedirect(
          location: RouteNames.rider,
          isRestoring: false,
          role: 'rider',
        ),
        isNull,
      );
    });

    test('distributor on /login → distributor dashboard', () {
      expect(
        AppRouter.resolveRedirect(
          location: RouteNames.login,
          isRestoring: false,
          role: 'distributor',
        ),
        RouteNames.distributor,
      );
    });
  });
}

/// Minimal ChangeNotifier stub for build() smoke tests.
class ChangeNotifierStub extends ChangeNotifier {}