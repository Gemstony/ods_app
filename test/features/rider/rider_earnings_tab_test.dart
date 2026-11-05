import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/earning.dart';
import 'package:ods_app/data/repositories/earnings_repository.dart';
import 'package:ods_app/features/rider/presentation/screens/rider_earnings_tab.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';
import 'package:ods_app/widgets/widgets.dart';

void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Earning _earning({
  int id = 1,
  EarningType type = EarningType.rider_baseline,
  EarningStatus status = EarningStatus.pending,
  double amount = 1500,
  String? trackingId,
  DateTime? earnedAt,
}) {
  return Earning(
    id: id,
    userId: 42,
    deliveryId: trackingId != null ? id : null,
    deliveryTrackingId: trackingId,
    type: type,
    amount: amount,
    currency: 'TZS',
    status: status,
    earnedAt: earnedAt ?? DateTime(2026, 11, 4),
  );
}

class _FakeEarningsRepo extends EarningsRepository {
  _FakeEarningsRepo({
    this.result,
    this.completer,
  }) : super(dio: Dio());

  final EarningsResult? result;
  final Completer<ApiResult<EarningsResult>>? completer;

  @override
  Future<ApiResult<EarningsResult>> listMine({
    EarningStatus? status,
    int? perPage,
  }) {
    if (completer != null) return completer!.future;
    return Future.value(
      ApiSuccess(result ?? EarningsResult.empty()),
    );
  }
}

Widget _wrap({required EarningsRepository repo}) {
  return ProviderScope(
    overrides: [
      earningsRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: RiderEarningsTab()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  // ─── Loading / error ────────────────────────────────────
  testWidgets('shows loading state', (tester) async {
    final completer = Completer<ApiResult<EarningsResult>>();
    final repo = _FakeEarningsRepo(completer: completer);

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pump();

    expect(find.byType(LoadingView), findsOneWidget);
  });

  testWidgets('shows error state with retry', (tester) async {
    final repo = _FakeEarningsRepo(
      result: null,
    );
    // Override to return a failure
    final failingRepo = _FailingEarningsRepo();

    await tester.pumpWidget(_wrap(repo: failingRepo));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  // ─── Empty state ────────────────────────────────────────
  testWidgets('shows empty state when there are no earnings',
      (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeEarningsRepo(result: EarningsResult.empty());

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('No earnings yet'), findsOneWidget);
    expect(
      find.textContaining('Your earnings will appear here'),
      findsOneWidget,
    );
  });

  // ─── Summary ────────────────────────────────────────────
  testWidgets('summary card renders all three totals', (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeEarningsRepo(
      result: const EarningsResult(
        items: [],
        owedTsh: 15000,
        paidThisMonthTsh: 5000,
        paidTotalTsh: 50000,
      ),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Earnings summary'), findsOneWidget);
    expect(find.text('Owed to you'), findsOneWidget);
    expect(find.text('Paid this month'), findsOneWidget);
    expect(find.text('All-time paid'), findsOneWidget);
    expect(find.text('TZS 15.0k'), findsOneWidget);
    expect(find.text('TZS 5000'), findsOneWidget);
    expect(find.text('TZS 50.0k'), findsOneWidget);
  });

  testWidgets('owed value shows warning color when > 0', (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeEarningsRepo(
      result: const EarningsResult(
        items: [],
        owedTsh: 15000,
        paidThisMonthTsh: 0,
        paidTotalTsh: 0,
      ),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    final valueFinder = find.text('TZS 15.0k');
    final widget = tester.widget<Text>(valueFinder);
    expect(widget.style?.color, isNotNull);
  });

  // ─── Earning card rendering ─────────────────────────────
   testWidgets('renders earning card fields', (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeEarningsRepo(
      result: EarningsResult(
        items: [
          _earning(
            id: 1,
            type: EarningType.rider_baseline,
            status: EarningStatus.pending,
            amount: 1500,
            trackingId: 'ODS-TEST-ABC',
          ),
        ],
        // Deliberately different from the card amount (1500) so the
        // string "TZS 1500" appears exactly once — otherwise the summary
        // and the card both render it and findsOneWidget fails.
        owedTsh: 5000,
        paidThisMonthTsh: 0,
        paidTotalTsh: 0,
      ),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Rider baseline'), findsOneWidget);
    expect(find.text('ODS-TEST-ABC'), findsOneWidget);
    expect(find.text('Pending'), findsWidgets); // badge + chip
    expect(find.text('TZS 1500'), findsOneWidget); // card amount only
    expect(find.text('TZS 5000'), findsOneWidget); // summary owed only
    expect(find.text('4 Nov 2026'), findsOneWidget);
  });
  testWidgets('renders negative adjustment with minus sign',
      (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeEarningsRepo(
      result: EarningsResult(
        items: [
          _earning(
            id: 1,
            type: EarningType.adjustment,
            status: EarningStatus.approved,
            amount: -500,
          ),
        ],
        owedTsh: -500,
        paidThisMonthTsh: 0,
        paidTotalTsh: 0,
      ),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Adjustment'), findsOneWidget);
    expect(find.text('-TZS 500'), findsOneWidget);
  });

  testWidgets('hides delivery line when no tracking ID',
      (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeEarningsRepo(
      result: EarningsResult(
        items: [
          _earning(
            id: 1,
            type: EarningType.adjustment,
            status: EarningStatus.pending,
            amount: 1000,
            trackingId: null,
          ),
        ],
        owedTsh: 1000,
        paidThisMonthTsh: 0,
        paidTotalTsh: 0,
      ),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.local_shipping_outlined), findsNothing);
  });

  // ─── Filter chips ───────────────────────────────────────
  testWidgets('status filter chips narrow the list', (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeEarningsRepo(
      result: EarningsResult(
        items: [
          _earning(
            id: 1,
            status: EarningStatus.pending,
            trackingId: 'ODS-PENDING',
            amount: 1000,
          ),
          _earning(
            id: 2,
            status: EarningStatus.paid,
            trackingId: 'ODS-PAID',
            amount: 2000,
          ),
        ],
        owedTsh: 1000,
        paidThisMonthTsh: 2000,
        paidTotalTsh: 2000,
      ),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('ODS-PENDING'), findsOneWidget);
    expect(find.text('ODS-PAID'), findsOneWidget);

    // Filter to Paid
    await tester.tap(find.widgetWithText(ChoiceChip, 'Paid'));
    await tester.pumpAndSettle();

    expect(find.text('ODS-PENDING'), findsNothing);
    expect(find.text('ODS-PAID'), findsOneWidget);
  });

  testWidgets('filter empty state shows when status filter excludes all',
      (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeEarningsRepo(
      result: EarningsResult(
        items: [
          _earning(id: 1, status: EarningStatus.pending, amount: 1000),
        ],
        owedTsh: 1000,
        paidThisMonthTsh: 0,
        paidTotalTsh: 0,
      ),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Paid'));
    await tester.pumpAndSettle();

    expect(find.text('No earnings match this filter'), findsOneWidget);
    expect(find.text('Clear filter'), findsOneWidget);
  });

  testWidgets('Clear filter restores the full list', (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeEarningsRepo(
      result: EarningsResult(
        items: [
          _earning(id: 1, status: EarningStatus.pending, amount: 1000),
        ],
        owedTsh: 1000,
        paidThisMonthTsh: 0,
        paidTotalTsh: 0,
      ),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Paid'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear filter'));
    await tester.pumpAndSettle();

    expect(find.text('Rider baseline'), findsOneWidget);
  });
}

class _FailingEarningsRepo extends EarningsRepository {
  _FailingEarningsRepo() : super(dio: Dio());

  @override
  Future<ApiResult<EarningsResult>> listMine({
    EarningStatus? status,
    int? perPage,
  }) async =>
      const ApiFailure(
        Failure(type: FailureType.network, message: 'Offline'),
      );
}