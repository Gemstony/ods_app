import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/distributor_dashboard_kpis.dart';
import 'package:ods_app/data/models/reward.dart';
import 'package:ods_app/features/distributor/presentation/providers/distributor_rewards_providers.dart';
import 'package:ods_app/features/distributor/presentation/screens/distributor_rewards_tab.dart';
import 'package:ods_app/widgets/widgets.dart';

// ─────────────────────────────────────────────────────────────────────
// Test helpers
// ─────────────────────────────────────────────────────────────────────

void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

DistributorRewardKpis _overview({
  int monthly = 8,
  int rolling = 45,
  bool tier1Available = false,
  bool tier2Available = false,
  DateTime? tier1ExpiresAt,
  DateTime? tier2ExpiresAt,
}) {
  return DistributorRewardKpis(
    progress: Reward(
      id: 1,
      distributorId: 42,
      currentMonth: '2026-11',
      monthlyCount: monthly,
      tier1Available: tier1Available,
      tier1ExpiresAt: tier1ExpiresAt,
      rollingCount: rolling,
      tier2Available: tier2Available,
      tier2ExpiresAt: tier2ExpiresAt,
    ),
    tier1Threshold: 20,
    tier2Threshold: 50,
    tier1DiscountPercent: 50,
  );
}

Widget _wrap({DistributorRewardKpis? data, Failure? error}) {
  return ProviderScope(
    overrides: [
      distributorRewardsProvider.overrideWith((ref) async {
        if (error != null) throw error;
        return data ?? _overview();
      }),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: DistributorRewardsTab()),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  // ─── States ──────────────────────────────────────────────
  testWidgets('shows loading state', (tester) async {
    final completer = Completer<DistributorRewardKpis>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          distributorRewardsProvider.overrideWith((ref) => completer.future),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: DistributorRewardsTab()),
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

  // ─── Structure ───────────────────────────────────────────
  testWidgets('renders header and progress card', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Your rewards'), findsOneWidget);
    expect(find.text('Nov 2026'), findsOneWidget); // month badge
    expect(find.byType(RewardProgressCard), findsOneWidget);
    expect(find.text('Reward progress'), findsOneWidget);
  });

  testWidgets('renders "how rewards work" card', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('How rewards work'), findsOneWidget);
    expect(find.text('Tier 1 discount'), findsOneWidget);
    expect(find.text('Tier 2 benefit'), findsOneWidget);
    expect(find.textContaining('20 successful deliveries'), findsOneWidget);
    expect(find.textContaining('50 successful deliveries'), findsOneWidget);
  });

  testWidgets('renders redemption history placeholder', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Redemption history'), findsOneWidget);
    expect(find.textContaining('Coming in Phase 13'), findsOneWidget);
  });

  // ─── Available banner ────────────────────────────────────
  testWidgets('does NOT show available banner when no tier is usable',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _overview()));
    await tester.pumpAndSettle();

    expect(find.text('Reward available!'), findsNothing);
  });

  testWidgets('shows available banner when tier1 is available',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(
      data: _overview(
        tier1Available: true,
        tier1ExpiresAt: DateTime(2026, 12, 4),
      ),
    ));
    await tester.pumpAndSettle();

    // Banner now uses celebratory copy that doesn't collide with the
    // how-it-works card ("Tier 1 discount" / "Tier 2 benefit").
    expect(find.text('Reward available!'), findsOneWidget);
    expect(find.textContaining('50% off your next delivery'), findsOneWidget);
    expect(find.textContaining('Discount expires 4 Dec 2026'), findsOneWidget);
  });

  testWidgets('shows both tiers when both are available', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(
      data: _overview(
        tier1Available: true,
        tier1ExpiresAt: DateTime(2026, 12, 4),
        tier2Available: true,
        tier2ExpiresAt: DateTime(2026, 12, 10),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('50% off your next delivery'), findsOneWidget);
    expect(find.textContaining('One free delivery'), findsOneWidget);
    expect(find.textContaining('Discount expires 4 Dec 2026'), findsOneWidget);
    expect(
      find.textContaining('Free delivery expires 10 Dec 2026'),
      findsOneWidget,
    );
  });

  // ─── Progress display ────────────────────────────────────
  testWidgets('progress card shows 8/20 and 45/50 counts', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _overview(monthly: 8, rolling: 45)));
    await tester.pumpAndSettle();

    expect(find.text('8 / 20'), findsOneWidget);
    expect(find.text('45 / 50'), findsOneWidget);
  });

  testWidgets('expired tier1 does NOT show available banner', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(
      data: _overview(
        tier1Available: true,
        tier1ExpiresAt: DateTime(2026, 1, 1), // in the past
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Reward available!'), findsNothing);
  });
}