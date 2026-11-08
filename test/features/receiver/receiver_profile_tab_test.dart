import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/auth/auth_user.dart';
import 'package:ods_app/features/receiver/presentation/screens/receiver_profile_tab.dart';
import 'package:ods_app/shared/providers/auth_provider.dart';
import 'package:ods_app/widgets/widgets.dart';

void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

AuthUser _user({
  String? status,
  bool dispatcherEnabled = false,
  DateTime? emailVerifiedAt,
  UserBranchRef? branch,
  DateTime? createdAt,
}) {
  return AuthUser(
    id: 42,
    name: 'Test Receiver',
    email: 'receiver@ods.test',
    phone: '0712345678',
    role: 'receiver',
    status: status ?? 'active',
    dispatcherEnabled: dispatcherEnabled,
    permissions: const [],
    createdAt: createdAt ?? DateTime(2025, 3, 14),
    emailVerifiedAt: emailVerifiedAt ?? DateTime(2025, 3, 14),
    branch: branch,
  );
}

Widget _wrap({AuthUser? user}) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(user ?? _user()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: ReceiverProfileTab()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  // ─── Header ─────────────────────────────────────────────
  testWidgets('renders header with name, Receiver badge, and Active status',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Test Receiver'), findsOneWidget);
    expect(find.text('Receiver'), findsOneWidget);
    expect(find.text('Active'), findsWidgets);
  });

  testWidgets('shows Dispatcher badge only when dispatcherEnabled is true',
      (tester) async {
    _useLargeViewport(tester);

    // Plain receiver — no Dispatcher badge
    await tester.pumpWidget(_wrap(user: _user(dispatcherEnabled: false)));
    await tester.pumpAndSettle();
    expect(find.text('Dispatcher'), findsNothing);

    // Dispatcher receiver — badge visible
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_user(dispatcherEnabled: true)),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: ReceiverProfileTab()),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Dispatcher'), findsOneWidget);
  });

  testWidgets('shows pending approval status for pending receiver',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(user: _user(status: 'pending')));
    await tester.pumpAndSettle();

    expect(find.text('Pending approval'), findsOneWidget);
  });

  // ─── Contact ────────────────────────────────────────────
  testWidgets('renders contact card with email, phone, verified icon',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Contact'), findsOneWidget);
    expect(find.text('receiver@ods.test'), findsOneWidget);
    expect(find.text('0712345678'), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
  });

  testWidgets('shows warning icon when email is not verified',
      (tester) async {
    _useLargeViewport(tester);
    final custom = AuthUser(
      id: 42,
      name: 'Test Receiver',
      email: 'receiver@ods.test',
      phone: '0712345678',
      role: 'receiver',
      status: 'active',
      dispatcherEnabled: false,
      permissions: const [],
      createdAt: DateTime(2025, 3, 14),
      // emailVerifiedAt null
    );

    await tester.pumpWidget(_wrap(user: custom));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsNothing);
  });

  // ─── Account ────────────────────────────────────────────
  testWidgets('renders account card with member since', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Member since'), findsOneWidget);
    expect(find.text('14 Mar 2025'), findsOneWidget);
    expect(find.text('No branch assigned'), findsOneWidget);
  });

  testWidgets('shows branch name and code when assigned', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(user: _user(
      branch: const UserBranchRef(
        id: 5,
        name: 'Kariakoo Branch',
        code: 'KRK-01',
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Kariakoo Branch · KRK-01'), findsOneWidget);
  });

  // ─── Footer ─────────────────────────────────────────────
  testWidgets('renders version footer', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(
      find.text('${AppConfig.appName} · ${AppConfig.appTagline}'),
      findsOneWidget,
    );
    expect(
      find.text('Version ${AppConfig.appVersion}'),
      findsOneWidget,
    );
  });

  // ─── Not signed in ──────────────────────────────────────
  testWidgets('renders "Not signed in" fallback when user is null',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(null),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: ReceiverProfileTab()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Not signed in.'), findsOneWidget);
    expect(find.text('Contact'), findsNothing);
    expect(find.text('Account'), findsNothing);
  });
}