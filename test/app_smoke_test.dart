import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ods_app/app.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/features/auth/presentation/screens/login_screen.dart';
import 'package:ods_app/features/auth/presentation/screens/splash_screen.dart';

void main() {
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

  testWidgets('login screen renders the auth form', (tester) async {
    AppConfig.initialize();
    await tester.pumpWidget(const OdsApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Sign in'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    // Dev-only artifacts removed in 3.3:
    expect(find.text('Test API connection'), findsNothing);
    expect(find.text('Dev shortcuts'), findsNothing);
    expect(find.widgetWithText(ActionChip, 'Owner'), findsNothing);
  });

  testWidgets('ODS theme is applied after routing', (tester) async {
    AppConfig.initialize();
    await tester.pumpWidget(const OdsApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    final ctx = tester.element(find.byType(LoginScreen));
    expect(Theme.of(ctx).useMaterial3, isTrue);
  });

  testWidgets('unknown route falls through to errorBuilder', (tester) async {
    AppConfig.initialize();
    await tester.pumpWidget(const OdsApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    final goRouter = GoRouter.of(tester.element(find.byType(LoginScreen)));
    goRouter.go('/this-route-does-not-exist');
    await tester.pumpAndSettle();

    expect(find.text('Page not found'), findsOneWidget);
    expect(find.textContaining('this-route-does-not-exist'), findsOneWidget);
  });
}