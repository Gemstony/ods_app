import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/theme/app_colors.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/dashboard_kpis.dart';
import 'package:ods_app/features/owner/presentation/screens/owner_home_tab.dart';
import 'package:ods_app/shared/providers/dashboard_providers.dart';
import 'package:ods_app/widgets/widgets.dart';

// ─────────────────────────────────────────────────────────────────────
// Fixtures
// ─────────────────────────────────────────────────────────────────────

DashboardKpis _sampleKpis({
  int pendingApprovals = 3,
  int activeBranches = 5,
  int deliveriesToday = 12,
  double revenueToday = 24000,
  int openDisputes = 0,
}) {
  return DashboardKpis(
    branches: BranchKpis(totalActive: activeBranches),
    users: UserKpis(
      totalActive: 59,
      pendingApprovals: pendingApprovals,
      managers: 5,
      riders: 12,
      receivers: 8,
      distributors: 34,
    ),
    deliveries: DeliveryKpis(
      todayCount: deliveriesToday,
      todayDelivered: 8,
      activeCount: 15,
      thisWeekCount: 87,
    ),
    revenue: RevenueKpis(
      todayTsh: revenueToday,
      thisWeekTsh: 156000,
      thisMonthTsh: 892000,
    ),
    payables: const PayableKpis(
      riderEarningsPendingTsh: 30000,
      dispatcherEarningsPendingTsh: 15000,
      transportFareOwedTsh: 45000,
    ),
    openDisputes: openDisputes,
    generatedAt: DateTime.now(),
  );
}

// ─────────────────────────────────────────────────────────────────────
// Harness
// ─────────────────────────────────────────────────────────────────────

Widget _wrap({
  DashboardKpis? data,
  Failure? error,
}) {
  return ProviderScope(
    overrides: [
      ownerDashboardProvider.overrideWith((ref) async {
        if (error != null) throw error;
        return data ?? DashboardKpis.empty();
      }),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: OwnerHomeTab()),
    ),
  );
}

/// Makes the test viewport tall enough that the entire `ListView` renders.
///
/// Without this, `find.text('Delivery operations')` fails because that
/// section is below the default 600px viewport and Flutter's ListView
/// doesn't build off-screen children.
void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

// ─────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  // ─── Loading ──────────────────────────────────────────────
  testWidgets('shows loading state while fetching', (tester) async {
    // A never-completing `Completer.future` keeps the provider in
    // `AsyncLoading` without ever creating a Timer, so the test finishes
    // cleanly (a `Future.delayed` would leave a pending timer that the
    // framework rejects at teardown).
    final completer = Completer<DashboardKpis>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ownerDashboardProvider.overrideWith((ref) => completer.future),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: OwnerHomeTab()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LoadingView), findsOneWidget);
    expect(find.text('Loading dashboard…'), findsOneWidget);
  });

  // ─── Error ────────────────────────────────────────────────
  testWidgets('shows error state with retry when fetch fails', (tester) async {
    await tester.pumpWidget(
      _wrap(error: const Failure(
        type: FailureType.network,
        message: 'Offline',
      )),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  // ─── KPI tiles ────────────────────────────────────────────
  testWidgets('renders all four KPI tiles', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sampleKpis()));
    await tester.pumpAndSettle();

    // Labels — 'Revenue today' appears in the KPI tile AND in the
    // financial section, so uses `findsWidgets`.
    expect(find.text('Pending approvals'), findsOneWidget);
    expect(find.text('Active branches'), findsOneWidget);
    expect(find.text('Deliveries today'), findsOneWidget);
    expect(find.text('Revenue today'), findsWidgets);

    // Values — several overlap with the financial / team sections.
    expect(find.text('3'), findsOneWidget);          // pending approvals
    expect(find.text('5'), findsWidgets);             // active branches + managers
    expect(find.text('12'), findsWidgets);            // deliveries today + riders
    expect(find.text('TZS 24.0k'), findsWidgets);     // revenue today + financial row
  });

  // ─── Financial snapshot ──────────────────────────────────
  testWidgets('renders financial snapshot section', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sampleKpis()));
    await tester.pumpAndSettle();

    expect(find.text('Financial snapshot'), findsOneWidget);
    expect(find.text('Revenue this week'), findsOneWidget);
    expect(find.text('Revenue this month'), findsOneWidget);
    expect(find.text('Pending payables'), findsOneWidget);
  });

  // ─── Team ─────────────────────────────────────────────────
  testWidgets('renders team section with role counts', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sampleKpis()));
    await tester.pumpAndSettle();

    expect(find.text('Team'), findsOneWidget);
    expect(find.text('Managers'), findsOneWidget);
    expect(find.text('Delivery agents'), findsOneWidget);
    expect(find.text('Receivers'), findsOneWidget);
    expect(find.text('Distributors'), findsOneWidget);
    expect(find.text('Total active users'), findsOneWidget);
  });

  // ─── Delivery operations ─────────────────────────────────
  testWidgets('renders delivery operations section', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sampleKpis()));
    await tester.pumpAndSettle();

    expect(find.text('Delivery operations'), findsOneWidget);
    expect(find.text('Active deliveries'), findsOneWidget);
    expect(find.text('Delivered today'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
  });

  // ─── Disputes ─────────────────────────────────────────────
  testWidgets('does not show disputes banner when none exist', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sampleKpis(openDisputes: 0)));
    await tester.pumpAndSettle();

    expect(find.textContaining('dispute'), findsNothing);
  });

  testWidgets('shows disputes banner when disputes exist', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sampleKpis(openDisputes: 2)));
    await tester.pumpAndSettle();

    expect(find.textContaining('2 open disputes'), findsOneWidget);
  });

  // ─── Pending approvals highlight ─────────────────────────
  testWidgets('highlights pending approvals when > 0', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sampleKpis(pendingApprovals: 5)));
    await tester.pumpAndSettle();

    // Find the KPI tile that contains 'Pending approvals' label — the
    // first Container ancestor is the _KpiTile's outer Container.
    final pendingTile = find
        .ancestor(
          of: find.text('Pending approvals'),
          matching: find.byType(Container),
        )
        .first;

    // The '5' value inside that tile must be rendered in warning color.
    final valueWidget = tester.widget<Text>(
      find.descendant(of: pendingTile, matching: find.text('5')),
    );
    expect(valueWidget.style?.color, AppColors.warning);
  });
}