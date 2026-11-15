import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/auth/auth_user.dart';
import 'package:ods_app/data/models/delivery.dart';
import 'package:ods_app/data/models/payment.dart';
import 'package:ods_app/data/repositories/payment_repository.dart';
import 'package:ods_app/features/distributor/presentation/widgets/payment_flow_sheet.dart';
import 'package:ods_app/shared/providers/auth_provider.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';

Delivery _delivery() => Delivery(
      id: 100,
      trackingId: 'ODS-TEST-1',
      distributorId: 42,
      serviceType: ServiceType.receive,
      status: DeliveryStatus.pending_payment,
      rawStatus: 'pending_payment',
      discountAmount: 0,
      currency: 'TZS',
      totalAmount: 5000,
    );

Payment _manualPayment({
  int id = 1,
  PaymentStatus status = PaymentStatus.pending,
}) {
  return Payment(
    id: id,
    deliveryId: 100,
    deliveryStatusRaw: 'pending_payment',
    stage: PaymentStage.full,
    amount: 5000,
    currency: 'TZS',
    method: PaymentMethod.cash,
    status: status,
    reference: 'PAY-CASH-1',
    initiatedBy: 42,
    initiatedAt: DateTime.now(),
  );
}

class _FakePaymentRepo extends PaymentRepository {
  _FakePaymentRepo({this.manualResult}) : super(dio: Dio());
  final ApiResult<Payment>? manualResult;
  int manualCalls = 0;

  @override
  Future<ApiResult<Payment>> manual({
    required int deliveryId,
    required String method,
    PaymentStage stage = PaymentStage.full,
    String? notes,
  }) async {
    manualCalls++;
    return manualResult ?? ApiSuccess(_manualPayment());
  }
}

AuthUser _user() => AuthUser(
      id: 42,
      name: 'Test Distributor',
      email: 'dist@ods.test',
      phone: '0712345678',
      role: 'distributor',
      status: 'active',
      dispatcherEnabled: false,
      permissions: const [],
    );

Widget _host({
  required PaymentRepository repo,
  required void Function(bool?) onResult,
}) {
  return ProviderScope(
    overrides: [
      paymentRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWithValue(_user()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                final r = await PaymentFlowSheet.show(context, _delivery());
                onResult(r);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  testWidgets('idle state shows Pay at branch affordance', (tester) async {
    await tester.pumpWidget(_host(
      repo: _FakePaymentRepo(),
      onResult: (_) {},
    ));
    await _openSheet(tester);

    expect(find.text('Send USSD prompt'), findsOneWidget);
    expect(find.text('Pay at branch (cash)'), findsOneWidget);
  });

  testWidgets('tap Pay at branch opens confirm dialog', (tester) async {
    await tester.pumpWidget(_host(
      repo: _FakePaymentRepo(),
      onResult: (_) {},
    ));
    await _openSheet(tester);

    await tester.tap(find.text('Pay at branch (cash)'));
    await tester.pumpAndSettle();

    expect(find.text('Pay at branch?'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Manual / other'), findsOneWidget);
    expect(find.text('Record'), findsOneWidget);
  });

  testWidgets('cancel confirm dialog keeps sheet idle', (tester) async {
    final repo = _FakePaymentRepo();
    await tester.pumpWidget(_host(repo: repo, onResult: (_) {}));
    await _openSheet(tester);

    await tester.tap(find.text('Pay at branch (cash)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();

    expect(repo.manualCalls, 0);
    expect(find.text('Send USSD prompt'), findsOneWidget);
  });

  testWidgets('confirming manual payment calls repo + shows awaiting state',
      (tester) async {
    final repo = _FakePaymentRepo();
    await tester.pumpWidget(_host(repo: repo, onResult: (_) {}));
    await _openSheet(tester);

    await tester.tap(find.text('Pay at branch (cash)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Record'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.manualCalls, 1);
    expect(find.text('Awaiting approval'), findsOneWidget);
    expect(find.text('Check status'), findsOneWidget);
  });

  testWidgets('manual payment failure shows error state', (tester) async {
    final repo = _FakePaymentRepo(
      manualResult: const ApiFailure(
        Failure(
          type: FailureType.validation,
          message: 'A payment for this delivery is already pending.',
        ),
      ),
    );
    await tester.pumpWidget(_host(repo: repo, onResult: (_) {}));
    await _openSheet(tester);

    await tester.tap(find.text('Pay at branch (cash)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Record'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.textContaining('already pending'),
      findsOneWidget,
    );
  });

  testWidgets('close awaiting state returns null', (tester) async {
    bool? result;
    final repo = _FakePaymentRepo();
    await tester.pumpWidget(_host(repo: repo, onResult: (r) => result = r));
    await _openSheet(tester);

    await tester.tap(find.text('Pay at branch (cash)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(result, isNull); // Not `true` — delivery still pending
  });
}