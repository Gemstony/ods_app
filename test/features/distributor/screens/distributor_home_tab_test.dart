import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/theme/app_colors.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/distributor_dashboard_kpis.dart';
import 'package:ods_app/data/models/reward.dart';
import 'package:ods_app/features/distributor/presentation/providers/distributor_dashboard_providers.dart';
import 'package:ods_app/features/distributor/presentation/screens/distributor_home_tab.dart';
import 'package:ods_app/widgets/widgets.dart';

void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

DistributorDashboardKpis _sample({
  int active = 3,
  int awaiting = 1,
  int delivered = 5,
  int total = 9,
  double spent = 15000,
  bool tier1Available = false,
}) {
  return DistributorDashboardKpis(
    deliveries: DistributorDeliveryKpis(
      activeCount: active,
      awaitingPaymentCount: awaiting,
      deliveredThisMonth: delivered,
      totalThisMonth: total,
    ),
    revenue: DistributorRevenueKpis(spentThisMonthTsh: spent),
    rewards: DistributorRewardKpis(
      progress: Reward(
        id: 1,
        distributorId: 42,
        currentMonth: '2026-11',
        monthlyCount: 5,
        tier1Available: tier1Available,
        tier1ExpiresAt: tier1Available
            ? DateTime.now().add(const Duration(days: 30))
            : null,
        rollingCount: 45,
        tier2Available: false,
      ),
      tier1Threshold: 20,
      tier2Threshold: 50,
      tier1DiscountPercent: 50,
    ),
    recentDeliveries: const [],
    generatedAt: DateTime.now(),
  );
}

Widget _wrap({DistributorDashboardKpis? data, Failure? error}) {
  return ProviderScope(
    overrides: [
      distributorDashboardProvider.overrideWith((ref) async {
        if (error != null) throw error;
        return data ?? DistributorDashboardKpis.empty();
      }),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: DistributorHomeTab()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  testWidgets('shows loading state', (tester) async {
    final completer = Completer<DistributorDashboardKpis>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          distributorDashboardProvider.overrideWith((ref) => completer.future),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: DistributorHomeTab()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LoadingView), findsOneWidget);
  });

  testWidgets('shows error state with retry', (tester) async {
    await tester.pumpWidget(_wrap(error: const Failure(
      type: FailureType.network,
      message: 'Offline',
    )));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('renders all four KPI labels', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sample()));
    await tester.pumpAndSettle();

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Awaiting payment'), findsOneWidget);
    expect(find.text('Delivered this month'), findsOneWidget);
    expect(find.text('Total this month'), findsOneWidget);
  });

  testWidgets('awaiting payment tile highlights when > 0', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sample(awaiting: 3)));
    await tester.pumpAndSettle();

    // Locate the "3" inside the awaiting-payment tile
    final tile = find
        .ancestor(
          of: find.text('Awaiting payment'),
          matching: find.byType(Container),
        )
        .first;
    final valueWidget = tester.widget<Text>(
      find.descendant(of: tile, matching: find.text('3')),
    );
    expect(valueWidget.style?.color, AppColors.warning);
  });

  testWidgets('renders spend section', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sample(spent: 15000)));
    await tester.pumpAndSettle();

    expect(find.text('Spent this month'), findsOneWidget);
    expect(find.text('TZS 15.0k'), findsOneWidget);
  });

  testWidgets('renders rewards progress card', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sample()));
    await tester.pumpAndSettle();

    expect(find.byType(RewardProgressCard), findsOneWidget);
    expect(find.text('Reward progress'), findsOneWidget);
  });

  testWidgets('shows available-reward banner when tier is usable',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sample(tier1Available: true)));
    await tester.pumpAndSettle();

    expect(find.textContaining('reward available'), findsOneWidget);
  });

  testWidgets('does not show available-reward banner when no tier is usable',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sample(tier1Available: false)));
    await tester.pumpAndSettle();

    expect(find.textContaining('reward available'), findsNothing);
  });

  testWidgets('hides recent activity when there are no recent deliveries',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sample()));
    await tester.pumpAndSettle();

    expect(find.text('Recent activity'), findsNothing);
  });
}