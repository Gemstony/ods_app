import 'dart:async';

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

Delivery _delivery() {
  return Delivery(
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
}

Payment _payment({
  int id = 1,
  PaymentStatus status = PaymentStatus.processing,
  String? failureReason,
  PaymentUssd? ussd,
}) {
  return Payment(
    id: id,
    deliveryId: 100,
    deliveryStatusRaw: 'pending_payment',
    stage: PaymentStage.full,
    amount: 5000,
    currency: 'TZS',
    method: PaymentMethod.clickpesa,
    status: status,
    reference: 'PAY-TEST-$id',
    initiatedBy: 42,
    initiatedAt: DateTime.now(),
    failureReason: failureReason,
    ussd: ussd,
  );
}

class _FakePaymentRepo extends PaymentRepository {
  _FakePaymentRepo({this.initiateResult, this.refreshResult})
      : super(dio: Dio());

  final ApiResult<Payment>? initiateResult;
  final ApiResult<Payment>? refreshResult;
  int initiateCalls = 0;
  int refreshCalls = 0;

  @override
  Future<ApiResult<Payment>> initiate({
    required int deliveryId,
    String? phoneNumber,
    PaymentStage stage = PaymentStage.full,
  }) async {
    initiateCalls++;
    return initiateResult ??
        ApiSuccess(_payment(status: PaymentStatus.processing));
  }

  @override
  Future<ApiResult<Payment>> refresh(int paymentId) async {
    refreshCalls++;
    return refreshResult ??
        ApiSuccess(_payment(status: PaymentStatus.processing));
  }
}

AuthUser _user() {
  return AuthUser(
    id: 42,
    name: 'Test Distributor',
    email: 'dist@ods.test',
    phone: '0712345678',
    role: 'distributor',
    status: 'active',
    dispatcherEnabled: false,
    permissions: const [],
  );
}

Widget _wrapSheet({
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

  testWidgets('idle shows phone field pre-filled with user phone',
      (tester) async {
    await tester.pumpWidget(_wrapSheet(
      repo: _FakePaymentRepo(),
      onResult: (_) {},
    ));
    await _openSheet(tester);

    expect(find.text('Pay for delivery'), findsOneWidget);
    expect(find.text('ODS-TEST-1'), findsOneWidget);
    // Pre-filled from user's 0712345678 → 255712345678
    final textField = tester.widget<TextField>(find.byType(TextField).first);
    expect(textField.controller?.text, '255712345678');
  });

  testWidgets('invalid phone shows snackbar', (tester) async {
    await tester.pumpWidget(_wrapSheet(
      repo: _FakePaymentRepo(),
      onResult: (_) {},
    ));
    await _openSheet(tester);

    // Clear and enter short phone
    await tester.enterText(find.byType(TextField).first, '123');
    await tester.tap(find.text('Send USSD prompt'));
    await tester.pump();

    expect(
      find.textContaining('valid phone'),
      findsOneWidget,
    );
  });

  testWidgets('submit calls repository', (tester) async {
    final repo = _FakePaymentRepo();
    await tester.pumpWidget(_wrapSheet(repo: repo, onResult: (_) {}));
    await _openSheet(tester);

    await tester.enterText(find.byType(TextField).first, '255712345678');
    await tester.tap(find.text('Send USSD prompt'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repo.initiateCalls, 1);
  });

  testWidgets('in-flight state shows check phone message', (tester) async {
    final repo = _FakePaymentRepo(
      initiateResult: ApiSuccess(_payment(
        status: PaymentStatus.processing,
        ussd: const PaymentUssd(
          providerStatus: 'PENDING',
          message: 'A USSD prompt has been sent.',
        ),
      )),
    );
    await tester.pumpWidget(_wrapSheet(repo: repo, onResult: (_) {}));
    await _openSheet(tester);

    await tester.tap(find.text('Send USSD prompt'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Check your phone'), findsOneWidget);
    expect(find.text('A USSD prompt has been sent.'), findsOneWidget);
    expect(find.text('Refresh status'), findsOneWidget);
  });

  testWidgets('failed state shows reason and Try again', (tester) async {
    final repo = _FakePaymentRepo(
      initiateResult: ApiSuccess(_payment(
        status: PaymentStatus.failed,
        failureReason: 'Insufficient funds',
      )),
    );
    await tester.pumpWidget(_wrapSheet(repo: repo, onResult: (_) {}));
    await _openSheet(tester);

    await tester.tap(find.text('Send USSD prompt'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Payment failed'), findsOneWidget);
    expect(find.text('Insufficient funds'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('error state shows message and Refresh status', (tester) async {
    final repo = _FakePaymentRepo(
      initiateResult: const ApiFailure(
        Failure(type: FailureType.network, message: 'Connection refused'),
      ),
    );
    await tester.pumpWidget(_wrapSheet(repo: repo, onResult: (_) {}));
    await _openSheet(tester);

    await tester.tap(find.text('Send USSD prompt'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Connection refused'), findsOneWidget);
    expect(find.text('Refresh status'), findsOneWidget);
  });

  testWidgets('success state shows Payment received then pops true',
      (tester) async {
    final repo = _FakePaymentRepo(
      initiateResult: ApiSuccess(_payment(status: PaymentStatus.completed)),
    );
    bool? result;
    await tester.pumpWidget(_wrapSheet(
      repo: repo,
      onResult: (r) => result = r,
    ));
    await _openSheet(tester);

    await tester.tap(find.text('Send USSD prompt'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Payment received'), findsOneWidget);

    // Wait for auto-close delay (900ms) + sheet dismiss animation
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 500));

    expect(result, isTrue);
  });

  testWidgets('cancel during idle pops null', (tester) async {
    bool? result;
    await tester.pumpWidget(_wrapSheet(
      repo: _FakePaymentRepo(),
      onResult: (r) => result = r,
    ));
    await _openSheet(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(result, isNull);
  });
}