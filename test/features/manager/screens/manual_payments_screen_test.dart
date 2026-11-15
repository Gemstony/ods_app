import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/manager_manual_payment.dart';
import 'package:ods_app/data/repositories/manual_payment_repository.dart';
import 'package:ods_app/features/manager/presentation/providers/manual_payments_provider.dart';
import 'package:ods_app/features/manager/presentation/screens/manual_payments_screen.dart';

ManagerManualPayment _payment({
  int id = 1,
  String reference = 'PAY-CASH-1',
  String method = 'cash',
}) {
  return ManagerManualPayment(
    id: id,
    reference: reference,
    amount: 5000,
    currency: 'TZS',
    method: method,
    stage: 'full',
    status: 'pending',
    initiatedAt: DateTime.now(),
    delivery: const ManualPaymentDeliveryRef(
      id: 100,
      trackingId: 'ODS-TEST-1',
      serviceType: 'receive',
      status: 'pending_payment',
    ),
    initiatedBy: const ManualPaymentUserRef(id: 42, name: 'Jane Distributor'),
  );
}

class _FakeRepo extends ManualPaymentRepository {
  _FakeRepo({
    this.listResult,
    this.approveResult,
    this.rejectResult,
  }) : super(dio: Dio());

  final ApiResult<List<ManagerManualPayment>>? listResult;
  final ApiResult<void>? approveResult;
  final ApiResult<void>? rejectResult;

  int approveCalls = 0;
  int rejectCalls = 0;

  @override
  Future<ApiResult<List<ManagerManualPayment>>> listPending({
    bool forOwner = false,
    int perPage = 20,
    int page = 1,
  }) async =>
      listResult ?? ApiSuccess([_payment()]);

  @override
  Future<ApiResult<void>> approve({
    required int paymentId,
    bool forOwner = false,
  }) async {
    approveCalls++;
    return approveResult ?? const ApiSuccess<void>(null);
  }

  @override
  Future<ApiResult<void>> reject({
    required int paymentId,
    required String reason,
    bool forOwner = false,
  }) async {
    rejectCalls++;
    return rejectResult ?? const ApiSuccess<void>(null);
  }
}

Widget _wrap({required ManualPaymentRepository repo, bool forOwner = false}) {
  return ProviderScope(
    overrides: [
      manualPaymentRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: ManualPaymentsScreen(forOwner: forOwner),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  testWidgets('shows empty state when no pending payments', (tester) async {
    await tester.pumpWidget(_wrap(
      repo: _FakeRepo(listResult: const ApiSuccess([])),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No pending approvals'), findsOneWidget);
  });

  testWidgets('shows error state with retry', (tester) async {
    await tester.pumpWidget(_wrap(
      repo: _FakeRepo(
        listResult: const ApiFailure(
          Failure(type: FailureType.network, message: 'Offline'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Could not load pending payments.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('renders pending payment card', (tester) async {
    await tester.pumpWidget(_wrap(repo: _FakeRepo()));
    await tester.pumpAndSettle();

    expect(find.text('PAY-CASH-1'), findsOneWidget);
    expect(find.text('TZS 5000'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('ODS-TEST-1'), findsOneWidget);
    expect(find.text('Jane Distributor'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
  });

  testWidgets('tap Approve opens confirm dialog', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(find.text('Approve payment?'), findsOneWidget);

    await tester.tap(find.text('Approve').last);
    await tester.pumpAndSettle();

    expect(repo.approveCalls, 1);
  });

  testWidgets('cancel confirm does not call approve', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repo.approveCalls, 0);
  });

  testWidgets('tap Reject opens reason dialog', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();

    expect(find.text('Reject payment'), findsOneWidget);
  });

  testWidgets('reject requires at least 5 chars', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'nope');
    await tester.tap(find.text('Reject').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('5 characters'), findsOneWidget);
    expect(repo.rejectCalls, 0);
  });

  testWidgets('valid reason calls reject', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'Cash not received at branch',
    );
    await tester.tap(find.text('Reject').last);
    await tester.pumpAndSettle();

    expect(repo.rejectCalls, 1);
  });

  testWidgets('Owner variant works with same UI', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(_wrap(repo: repo, forOwner: true));
    await tester.pumpAndSettle();

    expect(find.text('Manual Payment Approvals'), findsOneWidget);
    expect(find.text('PAY-CASH-1'), findsOneWidget);
  });
}