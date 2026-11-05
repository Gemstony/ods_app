import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/auth/auth_user.dart';
import 'package:ods_app/features/rider/presentation/screens/rider_profile_tab.dart';
import 'package:ods_app/shared/providers/auth_provider.dart';
import 'package:ods_app/widgets/widgets.dart';

void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

AuthUser _user({
  String? status,
  bool withPersonal = true,
  bool withVehicle = true,
  DateTime? emailVerifiedAt,
  UserBranchRef? branch,
  DateTime? createdAt,
}) {
  return AuthUser(
    id: 42,
    name: 'Test Rider',
    email: 'rider@ods.test',
    phone: '0712345678',
    role: 'rider',
    status: status ?? 'active',
    dispatcherEnabled: false,
    permissions: const [],
    nida: withPersonal ? '19900101123456789012' : null,
    sex: withPersonal ? 'male' : null,
    dateOfBirth: withPersonal ? DateTime(1990, 1, 1) : null,
    vehicleType: withVehicle ? 'Motorcycle' : null,
    vehicleColor: withVehicle ? 'Red' : null,
    vehicleOwnership: withVehicle ? 'owned' : null,
    plateNumber: withVehicle ? 'T123ABC' : null,
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
      home: const Scaffold(body: RiderProfileTab()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  // ─── Header ─────────────────────────────────────────────
  testWidgets('renders header with name, badge, and active status',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Test Rider'), findsOneWidget);
    expect(find.text('Delivery Agent'), findsOneWidget);
    expect(find.text('Active'), findsWidgets);
  });

  testWidgets('shows pending approval status for pending rider',
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
    expect(find.text('rider@ods.test'), findsOneWidget);
    expect(find.text('0712345678'), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
  });

  testWidgets('shows warning icon when email is not verified',
      (tester) async {
    _useLargeViewport(tester);
    final unverified = _user(emailVerifiedAt: null);
    // Force email_verified_at null by building a custom user
    final custom = AuthUser(
      id: unverified.id,
      name: unverified.name,
      email: unverified.email,
      phone: unverified.phone,
      role: unverified.role,
      status: unverified.status,
      dispatcherEnabled: unverified.dispatcherEnabled,
      permissions: unverified.permissions,
      nida: unverified.nida,
      sex: unverified.sex,
      dateOfBirth: unverified.dateOfBirth,
      vehicleType: unverified.vehicleType,
      vehicleColor: unverified.vehicleColor,
      vehicleOwnership: unverified.vehicleOwnership,
      plateNumber: unverified.plateNumber,
      createdAt: unverified.createdAt,
      // emailVerifiedAt stays null
    );

    await tester.pumpWidget(_wrap(user: custom));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsNothing);
  });

  // ─── Personal details ───────────────────────────────────
  testWidgets('renders personal details when present', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Personal details'), findsOneWidget);
    expect(find.text('19900101123456789012'), findsOneWidget);
    expect(find.text('Male'), findsOneWidget);
    expect(find.text('1 Jan 1990'), findsOneWidget);
  });

  testWidgets('hides personal details section when all fields null',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(user: _user(withPersonal: false)));
    await tester.pumpAndSettle();

    expect(find.text('Personal details'), findsNothing);
  });

  // ─── Vehicle ────────────────────────────────────────────
  testWidgets('renders vehicle details when present', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Vehicle'), findsOneWidget);
    expect(find.text('Motorcycle'), findsOneWidget);
    expect(find.text('Red'), findsOneWidget);
    expect(find.text('Owned'), findsOneWidget);
    expect(find.text('T123ABC'), findsOneWidget);
  });

  testWidgets('hides vehicle section when all fields null',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(user: _user(withVehicle: false)));
    await tester.pumpAndSettle();

    expect(find.text('Vehicle'), findsNothing);
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

  testWidgets('shows branch name and code when branch is assigned',
      (tester) async {
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
        home: const Scaffold(body: RiderProfileTab()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Not signed in.'), findsOneWidget);
    expect(find.text('Contact'), findsNothing);
    expect(find.text('Account'), findsNothing);
  });
}