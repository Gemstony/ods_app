import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/theme/app_colors.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/manager_dashboard_kpis.dart';
import 'package:ods_app/features/manager/presentation/providers/manager_dashboard_providers.dart';
import 'package:ods_app/features/manager/presentation/screens/manager_home_tab.dart';
import 'package:ods_app/widgets/widgets.dart';

void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

ManagerDashboardKpis _sample({
  String branchStatus = 'active',
  int waiting = 2,
  int inTransit = 1,
  int today = 12,
  int delivered = 8,
  double revenue = 24000,
  int receivers = 2,
  int riders = 3,
  int totalStaff = 5,
}) {
  return ManagerDashboardKpis(
    branch: ManagerBranchRef(
      id: 5,
      name: 'Kariakoo Branch',
      code: 'KRK-01',
      status: branchStatus,
    ),
    staff: ManagerStaffKpis(
      totalActive: totalStaff,
      receivers: receivers,
      riders: riders,
    ),
    deliveries: ManagerDeliveryKpis(
      todayCount: today,
      activeCount: waiting + inTransit,
      waitingPickup: waiting,
      inTransit: inTransit,
      deliveredToday: delivered,
    ),
    revenue: ManagerRevenueKpis(todayTsh: revenue),
    generatedAt: DateTime.now(),
  );
}

Widget _wrap({ManagerDashboardKpis? data, Failure? error}) {
  return ProviderScope(
    overrides: [
      managerDashboardProvider.overrideWith((ref) async {
        if (error != null) throw error;
        return data ?? ManagerDashboardKpis.empty();
      }),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: ManagerHomeTab()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  // ─── Loading ──────────────────────────────────────────────
  testWidgets('shows loading state while fetching', (tester) async {
    final completer = Completer<ManagerDashboardKpis>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          managerDashboardProvider.overrideWith((ref) => completer.future),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: ManagerHomeTab()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LoadingView), findsOneWidget);
    expect(find.text('Loading branch data…'), findsOneWidget);
  });

  // ─── Error ────────────────────────────────────────────────
  testWidgets('shows error state with retry', (tester) async {
    await tester.pumpWidget(_wrap(error: const Failure(
      type: FailureType.network,
      message: 'Offline',
    )));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  // ─── No branch ────────────────────────────────────────────
  testWidgets('shows "No branch assigned" when branch is null',
      (tester) async {
    await tester.pumpWidget(_wrap(data: ManagerDashboardKpis.empty()));
    await tester.pumpAndSettle();

    expect(find.text('No branch assigned'), findsOneWidget);
    expect(find.textContaining('Ask the Owner'), findsOneWidget);
  });

  // ─── Success ──────────────────────────────────────────────
  testWidgets('renders branch header with name and status chip',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sample()));
    await tester.pumpAndSettle();

    expect(find.text('Kariakoo Branch'), findsOneWidget);
    expect(find.textContaining('KRK-01'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('renders all four KPI labels', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sample()));
    await tester.pumpAndSettle();

    expect(find.text('Waiting for pickup'), findsOneWidget);
    expect(find.text('In transit'), findsOneWidget);
    expect(find.text('Deliveries today'), findsOneWidget);
    expect(find.text('Delivered today'), findsOneWidget);
  });

  testWidgets('waiting-for-pickup tile shows highlighted color when > 0',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sample(waiting: 3)));
    await tester.pumpAndSettle();

    // Find the KPI tile containing "Waiting for pickup" label,
    // then find the "3" inside it and assert its color.
    final tile = find
        .ancestor(
          of: find.text('Waiting for pickup'),
          matching: find.byType(Container),
        )
        .first;
    final valueWidget = tester.widget<Text>(
      find.descendant(of: tile, matching: find.text('3')),
    );
    expect(valueWidget.style?.color, AppColors.warning);
  });

  testWidgets('renders revenue section', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sample(revenue: 24000)));
    await tester.pumpAndSettle();

    expect(find.text('Revenue today'), findsOneWidget);
    expect(find.text('TZS 24.0k'), findsOneWidget);
  });

  testWidgets('renders team section with role breakdown', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(
      _wrap(data: _sample(receivers: 2, riders: 3, totalStaff: 5)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Team'), findsOneWidget);
    expect(find.text('Receivers'), findsOneWidget);
    expect(find.text('Riders'), findsOneWidget);
    expect(find.text('Total active'), findsOneWidget);
  });

  // ─── Inactive branch warning ─────────────────────────────
  testWidgets('shows inactive warning when branch is inactive',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(
      _wrap(data: _sample(branchStatus: 'inactive')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Inactive'), findsWidgets);
    expect(find.textContaining('Your branch is currently inactive'),
        findsOneWidget);
  });

  testWidgets('does not show inactive warning when branch is active',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sample(branchStatus: 'active')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Your branch is currently inactive'),
        findsNothing);
  });
}