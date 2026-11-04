import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/auth/auth_user.dart';
import 'package:ods_app/features/distributor/presentation/screens/distributor_profile_tab.dart';
import 'package:ods_app/shared/providers/auth_provider.dart';
import 'package:ods_app/widgets/widgets.dart';

void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

AuthUser _user({
  String? status,
  String? distributorId,
  DateTime? createdAt,
  UserBranchRef? branch,
  DateTime? emailVerifiedAt,
}) {
  return AuthUser(
    id: 42,
    name: 'Jane Distributor',
    email: 'jane@ods.test',
    phone: '0712345678',
    role: 'distributor',
    status: status ?? 'active',
    distributorId: distributorId ?? 'DIST-0001',
    createdAt: createdAt ?? DateTime(2025, 3, 14),
    emailVerifiedAt: emailVerifiedAt ?? DateTime(2025, 3, 14),
    branch: branch,
    dispatcherEnabled: false,
    permissions: const [],
  );
}

Widget _wrap({AuthUser? user}) {
  return ProviderScope(
    overrides: [
      // currentUserProvider is the only thing this tab reads.
      // Overriding it avoids constructing sessionProvider / SecureStorage
      // (which would otherwise touch platform channels in tests).
      currentUserProvider.overrideWithValue(user ?? _user()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: DistributorProfileTab()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  testWidgets('renders header with name, role badge, and active status',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Jane Distributor'), findsOneWidget);
    expect(find.text('Distributor'), findsOneWidget);
    // Role badge text "Distributor" also appears in the badge
    expect(find.text('Active'), findsWidgets); // StatusChip
  });

  testWidgets('renders contact card with email, phone, verified icon',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Contact'), findsOneWidget);
    expect(find.text('jane@ods.test'), findsOneWidget);
    expect(find.text('0712345678'), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
  });

  testWidgets('renders account card with distributor ID and member since',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('DIST-0001'), findsOneWidget);
    expect(find.text('14 Mar 2025'), findsOneWidget);
    // No branch set:
    expect(find.text('No branch assigned'), findsOneWidget);
  });

  testWidgets('shows branch name and code when branch is present',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(
      user: _user(branch: const UserBranchRef(
        id: 5,
        name: 'Kariakoo Branch',
        code: 'KRK-01',
      )),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Kariakoo Branch · KRK-01'), findsOneWidget);
  });

  testWidgets('shows pending approval status for pending users',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(user: _user(status: 'pending')));
    await tester.pumpAndSettle();

    expect(find.text('Pending approval'), findsOneWidget);
  });

  testWidgets('shows "Not assigned yet" when distributorId is empty',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(user: _user(distributorId: '')));
    await tester.pumpAndSettle();

    expect(find.text('Not assigned yet'), findsOneWidget);
  });

  testWidgets('shows warning icon when email is not verified',
      (tester) async {
    _useLargeViewport(tester);
    // override emailVerifiedAt to null by building custom user
    final unverified = AuthUser(
      id: 42,
      name: 'Jane Distributor',
      email: 'jane@ods.test',
      phone: '0712345678',
      role: 'distributor',
      status: 'active',
      distributorId: 'DIST-0001',
      createdAt: DateTime(2025, 3, 14),
      dispatcherEnabled: false,
      permissions: const [],
    );
    await tester.pumpWidget(_wrap(user: unverified));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsNothing);
  });

  testWidgets('renders version footer with app name and version',
      (tester) async {
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

  testWidgets('renders "Not signed in" fallback when user is null',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(null),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: DistributorProfileTab()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Not signed in.'), findsOneWidget);
    // Should NOT render any card sections
    expect(find.text('Contact'), findsNothing);
    expect(find.text('Account'), findsNothing);
  });
}