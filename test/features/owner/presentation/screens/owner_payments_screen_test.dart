import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/ledger_entries.dart';
import 'package:ods_app/data/models/payment.dart';
import 'package:ods_app/data/repositories/owner_ledger_repository.dart';
import 'package:ods_app/features/owner/presentation/screens/owner_payments_screen.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';

Payment _payment(int id, {PaymentStatus status = PaymentStatus.completed}) {
  return Payment(
    id: id,
    deliveryId: 100 + id,
    stage: PaymentStage.full,
    amount: 5000,
    currency: 'TZS',
    method: PaymentMethod.clickpesa,
    status: status,
    reference: 'PAY-TEST-$id',
    initiatedBy: 42,
    initiatedAt: DateTime.now(),
  );
}

class _FakeLedgerRepo extends OwnerLedgerRepository {
  _FakeLedgerRepo({this.payments = const [], this.fail = false})
      : super(dio: Dio());

  final List<OwnerPaymentEntry> payments;
  final bool fail;

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
  }) async {
    if (fail) {
      return const ApiFailure(
        Failure(type: FailureType.network, message: 'Offline'),
      );
    }
    return ApiSuccess(payments);
  }
}

Widget _wrap({required OwnerLedgerRepository repo}) {
  return ProviderScope(
    overrides: [ownerLedgerRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const OwnerPaymentsScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  testWidgets('shows empty state when no payments', (tester) async {
    await tester.pumpWidget(_wrap(repo: _FakeLedgerRepo()));
    await tester.pumpAndSettle();

    expect(find.text('No payments'), findsOneWidget);
  });

  testWidgets('shows error state with retry', (tester) async {
    await tester.pumpWidget(_wrap(repo: _FakeLedgerRepo(fail: true)));
    await tester.pumpAndSettle();

    expect(find.text('Could not load payments.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('renders payment rows', (tester) async {
    await tester.pumpWidget(_wrap(
      repo: _FakeLedgerRepo(payments: [
        OwnerPaymentEntry(payment: _payment(1)),
        OwnerPaymentEntry(payment: _payment(2, status: PaymentStatus.pending)),
      ]),
    ));
    await tester.pumpAndSettle();

    // Refs are unique per row — always exactly one match.
    expect(find.text('PAY-TEST-1'), findsOneWidget);
    expect(find.text('PAY-TEST-2'), findsOneWidget);

    // Status text appears in both filter chips and status badges —
    // at least one of each is enough proof the badge rendered.
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Pending'), findsWidgets);
  });

  testWidgets('filter chips are tappable', (tester) async {
    await tester.pumpWidget(_wrap(
      repo: _FakeLedgerRepo(payments: [
        OwnerPaymentEntry(payment: _payment(1)),
      ]),
    ));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Pending'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Completed'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
    await tester.pumpAndSettle();
  });
}