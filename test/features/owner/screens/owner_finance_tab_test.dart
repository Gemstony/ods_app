import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/finance_summary.dart';
import 'package:ods_app/data/models/ledger_entries.dart';
// `show` clause prevents any accidental collision with
// `ReconciliationSummary` from finance_summary.dart.
import 'package:ods_app/data/models/reconciliation_report.dart'
    show ReconciliationLastRun;
import 'package:ods_app/data/repositories/owner_ledger_repository.dart';
import 'package:ods_app/features/owner/presentation/providers/owner_finance_providers.dart';
import 'package:ods_app/features/owner/presentation/screens/owner_finance_tab.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';
import 'package:ods_app/widgets/widgets.dart';

/// Makes the test viewport tall enough that the entire ListView renders.
void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Prevents the Phase 11.6 `OwnerLedgerSection` from hanging the widget
/// tree in tests — its three providers would otherwise hit the real
/// backend with no auth session and never resolve.
class _FakeOwnerLedgerRepo extends OwnerLedgerRepository {
  _FakeOwnerLedgerRepo() : super(dio: Dio());

  @override
  Future<ApiResult<List<OwnerPaymentEntry>>> listPayments({
    List<String>? statuses,
    String? method,
    int? deliveryId,
    String? reference,
    DateTime? from,
    DateTime? to,
    int perPage = 20,
    int page = 1,
  }) async =>
      const ApiSuccess<List<OwnerPaymentEntry>>([]);

  @override
  Future<ApiResult<List<OwnerEarningEntry>>> listEarnings({
    List<String>? statuses,
    List<String>? types,
    int? userId,
    int? deliveryId,
    DateTime? from,
    DateTime? to,
    int perPage = 20,
    int page = 1,
  }) async =>
      const ApiSuccess<List<OwnerEarningEntry>>([]);

  @override
  Future<ApiResult<List<OwnerPayoutEntry>>> listPayouts({
    List<String>? statuses,
    String? method,
    int? userId,
    DateTime? from,
    DateTime? to,
    int perPage = 20,
    int page = 1,
  }) async =>
      const ApiSuccess<List<OwnerPayoutEntry>>([]);

  @override
  Future<ApiResult<ReconciliationLastRun>> lastReconciliation() async =>
      const ApiSuccess(ReconciliationLastRun(hasRun: false));
}

FinanceSummary _sample({
  double revenueMonth = 892000,
  double payablesTotal = 100000,
  double surplus = 532000,
  List<RecentPayout> payouts = const [],
}) {
  return FinanceSummary(
    revenue: RevenueSummary(
      todayTsh: 24000,
      thisWeekTsh: 156000,
      thisMonthTsh: revenueMonth,
      allTimeTsh: 5000000,
    ),
    payables: const PayablesSummary(
      riderPendingTsh: 30000,
      riderApprovedTsh: 15000,
      dispatcherPendingTsh: 8000,
      dispatcherApprovedTsh: 2000,
      transportFareOwedTsh: 45000,
    ),
    payouts: const PayoutsSummary(
      thisMonthCount: 12,
      thisMonthTsh: 250000,
      pendingCount: 3,
      pendingTsh: 45000,
    ),
    transportPaid: const TransportPaidSummary(thisMonthTsh: 35000),
    expenses: const ExpensesSummary(
      thisMonthTsh: 75000,
      allTimeTsh: 300000,
    ),
    reconciliation: ReconciliationSummary(
      revenueThisMonthTsh: revenueMonth,
      minusPayoutsThisMonthTsh: 250000,
      minusTransportPaidThisMonthTsh: 35000,
      minusExpensesThisMonthTsh: 75000,
      operatingSurplusTsh: surplus,
    ),
    recentPayouts: payouts,
    generatedAt: DateTime.now(),
  );
}

Widget _wrap({
  FinanceSummary? data,
  Failure? error,
}) {
  return ProviderScope(
    overrides: [
      ownerFinanceProvider.overrideWith((ref) async {
        if (error != null) throw error;
        return data ?? FinanceSummary.empty();
      }),
      // Phase 11.6 — feed the ledger hub empty data so it doesn't try
      // to hit the real backend during widget tests.
      ownerLedgerRepositoryProvider.overrideWithValue(_FakeOwnerLedgerRepo()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: OwnerFinanceTab()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  testWidgets('shows error state with retry', (tester) async {
    await tester.pumpWidget(_wrap(error: const Failure(
      type: FailureType.network,
      message: 'Offline',
    )));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('renders all four main sections', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sample()));
    await tester.pumpAndSettle();

    // "Revenue" appears twice: as a card title AND as a
    // reconciliation line item.
    expect(find.text('Revenue'), findsWidgets);
    expect(find.text('Outstanding payables'), findsOneWidget);
    expect(find.text('Reconciliation'), findsOneWidget);
    expect(find.text('Payouts'), findsOneWidget);
    expect(find.text('Recent payouts'), findsOneWidget);
  });

  testWidgets('revenue KPIs render today / week / month / all-time',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sample()));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    // "This month" appears in Revenue, Payouts, and Costs.
    expect(find.text('This month'), findsWidgets);
    expect(find.text('All time'), findsOneWidget);
  });

  testWidgets('payables section shows total owed prominently',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sample()));
    await tester.pumpAndSettle();

    expect(find.text('Total owed'), findsOneWidget);
    // 100000 → TZS 100.0k
    expect(find.text('TZS 100.0k'), findsWidgets);
    expect(find.text('Rider earnings'), findsOneWidget);
    expect(find.text('Dispatcher earnings'), findsOneWidget);
    expect(find.text('Transport fare owed'), findsOneWidget);
  });

  testWidgets('reconciliation shows the ODS equation', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sample()));
    await tester.pumpAndSettle();

    expect(find.text('Revenue'), findsWidgets);
    // U+2212 MINUS SIGN, not ASCII hyphen.
    expect(find.text('\u2212 Payouts'), findsOneWidget);
    expect(find.text('\u2212 Transport paid'), findsOneWidget);
    expect(find.text('\u2212 Expenses'), findsOneWidget);
    expect(find.text('Operating surplus'), findsOneWidget);
    // 532000 → TZS 532.0k
    expect(find.text('TZS 532.0k'), findsOneWidget);
  });

  testWidgets('recent payouts shows empty state when none', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sample(payouts: const [])));
    await tester.pumpAndSettle();

    expect(find.text('No payouts recorded yet.'), findsOneWidget);
  });

  testWidgets('recent payouts renders list when present', (tester) async {
    _useLargeViewport(tester);
    final payouts = [
      RecentPayout(
        id: 1,
        userName: 'Jane Rider',
        amount: 50000,
        currency: 'TZS',
        status: 'paid',
        reference: 'PO-1',
        processedAt: DateTime(2026, 11, 1),
      ),
      RecentPayout(
        id: 2,
        userName: 'Tom Rider',
        amount: 30000,
        currency: 'TZS',
        status: 'pending',
        reference: 'PO-2',
        requestedAt: DateTime(2026, 11, 3),
      ),
    ];
    await tester.pumpWidget(_wrap(data: _sample(payouts: payouts)));
    await tester.pumpAndSettle();

    expect(find.text('Jane Rider'), findsOneWidget);
    expect(find.text('Tom Rider'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    // "Pending" appears both in the Payouts summary row and in the
    // status badge for Tom's payout.
    expect(find.text('Pending'), findsWidgets);
  });
}