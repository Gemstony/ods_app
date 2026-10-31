import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/data/models/reward.dart';
import 'package:ods_app/widgets/reward_progress_card.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
    );

Reward _reward({
  int monthlyCount = 0,
  int rollingCount = 0,
  bool tier1Available = false,
  bool tier2Available = false,
  DateTime? tier1ExpiresAt,
}) {
  return Reward(
    id: 1,
    distributorId: 42,
    currentMonth: '2026-10',
    monthlyCount: monthlyCount,
    tier1Available: tier1Available,
    tier1ExpiresAt: tier1ExpiresAt,
    rollingCount: rollingCount,
    tier2Available: tier2Available,
  );
}

void main() {
  testWidgets('shows both tier titles', (tester) async {
    await tester.pumpWidget(_wrap(
      RewardProgressCard(reward: _reward()),
    ));
    expect(find.text('Reward progress'), findsOneWidget);
    expect(find.textContaining('Tier 1'), findsOneWidget);
    expect(find.textContaining('50% off'), findsOneWidget);
    expect(find.textContaining('Tier 2'), findsOneWidget);
    expect(find.textContaining('Free delivery'), findsOneWidget);
  });

  testWidgets('shows current / threshold counts', (tester) async {
    await tester.pumpWidget(_wrap(
      RewardProgressCard(reward: _reward(monthlyCount: 8, rollingCount: 20)),
    ));
    expect(find.text('8 / 20'), findsOneWidget);
    expect(find.text('20 / 50'), findsOneWidget);
  });

  testWidgets('shows remaining count when not available', (tester) async {
    await tester.pumpWidget(_wrap(
      RewardProgressCard(reward: _reward(monthlyCount: 15, rollingCount: 30)),
    ));
    expect(find.text('5 more this month'), findsOneWidget);
    expect(find.text('20 more in rolling window'), findsOneWidget);
  });

  testWidgets('shows AVAILABLE badge when tier1 is usable', (tester) async {
    await tester.pumpWidget(_wrap(
      RewardProgressCard(
        reward: _reward(
          monthlyCount: 20,
          tier1Available: true,
          tier1ExpiresAt: DateTime.now().add(const Duration(days: 30)),
        ),
      ),
    ));
    expect(find.text('AVAILABLE'), findsOneWidget);
  });

  testWidgets('shows AVAILABLE badge for tier2 when usable', (tester) async {
    await tester.pumpWidget(_wrap(
      RewardProgressCard(
        reward: _reward(
          rollingCount: 50,
          tier2Available: true,
        ),
      ),
    ));
    expect(find.text('AVAILABLE'), findsOneWidget);
  });

  testWidgets('shows both AVAILABLE badges when both tiers usable',
      (tester) async {
    await tester.pumpWidget(_wrap(
      RewardProgressCard(
        reward: _reward(
          monthlyCount: 20,
          rollingCount: 50,
          tier1Available: true,
          tier2Available: true,
          tier1ExpiresAt: DateTime.now().add(const Duration(days: 30)),
        ),
      ),
    ));
    expect(find.text('AVAILABLE'), findsNWidgets(2));
  });

  testWidgets('shows expiry date when tier is available', (tester) async {
    await tester.pumpWidget(_wrap(
      RewardProgressCard(
        reward: _reward(
          monthlyCount: 20,
          tier1Available: true,
          tier1ExpiresAt: DateTime(2026, 12, 24),
        ),
      ),
    ));
    expect(find.text('Expires 24 Dec'), findsOneWidget);
  });

  testWidgets('progress bar reflects correct percentage', (tester) async {
    await tester.pumpWidget(_wrap(
      RewardProgressCard(
        reward: _reward(monthlyCount: 10, rollingCount: 25),
      ),
    ));

    final bars = tester
        .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator))
        .toList();
    expect(bars.length, 2);
    expect(bars[0].value, closeTo(0.5, 0.01)); // 10/20
    expect(bars[1].value, closeTo(0.5, 0.01)); // 25/50
  });

  testWidgets('progress bar caps at 1.0 for over-threshold', (tester) async {
    await tester.pumpWidget(_wrap(
      RewardProgressCard(
        reward: _reward(monthlyCount: 35, rollingCount: 80),
      ),
    ));

    final bars = tester
        .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator))
        .toList();
    expect(bars[0].value, 1.0);
    expect(bars[1].value, 1.0);
  });

  testWidgets('respects custom thresholds', (tester) async {
    await tester.pumpWidget(_wrap(
      RewardProgressCard(
        reward: _reward(monthlyCount: 5, rollingCount: 10),
        tier1Threshold: 10,
        tier2Threshold: 20,
        tier1DiscountPercent: 40.0,
      ),
    ));
    expect(find.text('5 / 10'), findsOneWidget);
    expect(find.text('10 / 20'), findsOneWidget);
    expect(find.textContaining('40% off'), findsOneWidget);
  });
}