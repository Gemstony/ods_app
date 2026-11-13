import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/ledger_entries.dart';
import 'package:ods_app/data/models/reconciliation_report.dart';
import 'package:ods_app/data/repositories/owner_ledger_repository.dart';
import 'package:ods_app/features/owner/presentation/widgets/owner_ledger_section.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';

class _FakeLedgerRepo extends OwnerLedgerRepository {
  _FakeLedgerRepo({
    this.payments = const [],
    this.earnings = const [],
    this.payouts = const [],
    this.lastRun,
  }) : super(dio: Dio());

  final List<OwnerPaymentEntry> payments;
  final List<OwnerEarningEntry> earnings;
  final List<OwnerPayoutEntry> payouts;
  final ReconciliationLastRun? lastRun;

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
      ApiSuccess(payments);

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
      ApiSuccess(earnings);

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
      ApiSuccess(payouts);

  @override
  Future<ApiResult<ReconciliationLastRun>> lastReconciliation() async =>
      ApiSuccess(lastRun ?? const ReconciliationLastRun(hasRun: false));
}

Widget _wrap({required OwnerLedgerRepository repo}) {
  return ProviderScope(
    overrides: [
      ownerLedgerRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: const OwnerLedgerSection(),
          ),
        ),
      ),
    ),
  );
}
// ... imports and fake repo as above ...

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  testWidgets('renders Ledger section with three tap cards + recon', (tester) async {
    await tester.pumpWidget(_wrap(repo: _FakeLedgerRepo()));
    await tester.pumpAndSettle();

    expect(find.text('Ledger'), findsOneWidget);
    expect(find.text('Payments'), findsOneWidget);
    expect(find.text('Earnings'), findsOneWidget);
    expect(find.text('Payouts'), findsOneWidget);
    expect(find.text('Reconciliation'), findsOneWidget);
    expect(find.text('Run reconciliation'), findsOneWidget);
  });

  testWidgets('shows 0 entries when lists are empty', (tester) async {
    await tester.pumpWidget(_wrap(repo: _FakeLedgerRepo()));
    await tester.pumpAndSettle();

    expect(find.text('0 entries'), findsWidgets);
  });

  testWidgets('shows Never run when no reconciliation', (tester) async {
    await tester.pumpWidget(_wrap(repo: _FakeLedgerRepo()));
    await tester.pumpAndSettle();

    expect(find.text('Never run'), findsOneWidget);
  });

  testWidgets('shows last run relative time', (tester) async {
    await tester.pumpWidget(_wrap(
      repo: _FakeLedgerRepo(
        lastRun: ReconciliationLastRun(
          hasRun: true,
          ranAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Last run'), findsOneWidget);
    expect(find.textContaining('2h ago'), findsOneWidget);
  });
}

/// Minimal Payment stub for the count display.
dynamic _paymentStub(int id) => throw UnimplementedError(
      'Stub Payment constructor in your copy — placeholder for compile-time',
    );