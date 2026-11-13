import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/models/payment.dart';
import 'package:ods_app/data/repositories/payment_repository.dart';
import 'package:ods_app/features/distributor/presentation/providers/payment_flow_providers.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';

Payment _payment({
  int id = 1,
  PaymentStatus status = PaymentStatus.processing,
  String? failureReason,
}) {
  return Payment(
    id: id,
    deliveryId: 100,
    stage: PaymentStage.full,
    amount: 5000,
    currency: 'TZS',
    method: PaymentMethod.clickpesa,
    status: status,
    reference: 'PAY-TEST-$id',
    initiatedBy: 7,
    initiatedAt: DateTime.now(),
    failureReason: failureReason,
  );
}

class _FakePaymentRepo extends PaymentRepository {
  _FakePaymentRepo({
    this.initiateResult,
    this.refreshResults = const [],
    this.refreshCompleter,
  }) : super(dio: Dio());

  final ApiResult<Payment>? initiateResult;
  final List<ApiResult<Payment>> refreshResults;
  final Completer<ApiResult<Payment>>? refreshCompleter;

  int initiateCalls = 0;
  int refreshCalls = 0;
  String? lastInitiatePhone;
  int? lastInitiateDeliveryId;

  @override
  Future<ApiResult<Payment>> initiate({
    required int deliveryId,
    String? phoneNumber,
    PaymentStage stage = PaymentStage.full,
  }) async {
    initiateCalls++;
    lastInitiateDeliveryId = deliveryId;
    lastInitiatePhone = phoneNumber;
    return initiateResult ??
        ApiSuccess(_payment(status: PaymentStatus.processing));
  }

  @override
  Future<ApiResult<Payment>> refresh(int paymentId) async {
    refreshCalls++;
    if (refreshCompleter != null) return refreshCompleter!.future;
    if (refreshCalls <= refreshResults.length) {
      return refreshResults[refreshCalls - 1];
    }
    return ApiSuccess(_payment(status: PaymentStatus.processing));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  group('PaymentFlowNotifier', () {
    test('initial state is idle', () {
      final container = ProviderContainer(overrides: [
        paymentRepositoryProvider.overrideWithValue(_FakePaymentRepo()),
      ]);
      addTearDown(container.dispose);

      final state = container.read(paymentFlowProvider(100));
      expect(state, isA<PaymentFlowIdle>());
    });

    test('initiate success → in-flight with payment', () async {
      final repo = _FakePaymentRepo(
        initiateResult: ApiSuccess(_payment(status: PaymentStatus.processing)),
      );
      final container = ProviderContainer(overrides: [
        paymentRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      final notifier = container.read(paymentFlowProvider(100).notifier);
      await notifier.initiate(phoneNumber: '255712345678');

      final state = container.read(paymentFlowProvider(100));
      expect(state, isA<PaymentFlowInFlight>());
      expect((state as PaymentFlowInFlight).payment.id, 1);
      expect(repo.initiateCalls, 1);
      expect(repo.lastInitiatePhone, '255712345678');
      expect(repo.lastInitiateDeliveryId, 100);
    });

    test('initiate completes immediately → success', () async {
      final repo = _FakePaymentRepo(
        initiateResult: ApiSuccess(_payment(status: PaymentStatus.completed)),
      );
      final container = ProviderContainer(overrides: [
        paymentRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      final notifier = container.read(paymentFlowProvider(100).notifier);
      await notifier.initiate(phoneNumber: '255712345678');

      expect(
        container.read(paymentFlowProvider(100)),
        isA<PaymentFlowSuccess>(),
      );
    });

    test('initiate failure → error', () async {
      final repo = _FakePaymentRepo(
        initiateResult: const ApiFailure(
          Failure(type: FailureType.network, message: 'Connection refused'),
        ),
      );
      final container = ProviderContainer(overrides: [
        paymentRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      final notifier = container.read(paymentFlowProvider(100).notifier);
      await notifier.initiate(phoneNumber: '255712345678');

      final state = container.read(paymentFlowProvider(100));
      expect(state, isA<PaymentFlowError>());
      expect((state as PaymentFlowError).message, 'Connection refused');
    });

    test('refreshNow transitions to success', () async {
      final repo = _FakePaymentRepo(
        initiateResult: ApiSuccess(_payment(status: PaymentStatus.processing)),
        refreshResults: [
          ApiSuccess(_payment(status: PaymentStatus.completed)),
        ],
      );
      final container = ProviderContainer(overrides: [
        paymentRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      final notifier = container.read(paymentFlowProvider(100).notifier);
      await notifier.initiate(phoneNumber: '255712345678');
      await notifier.refreshNow();

      expect(
        container.read(paymentFlowProvider(100)),
        isA<PaymentFlowSuccess>(),
      );
    });

    test('reset returns to idle', () async {
      final repo = _FakePaymentRepo();
      final container = ProviderContainer(overrides: [
        paymentRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      final notifier = container.read(paymentFlowProvider(100).notifier);
      await notifier.initiate(phoneNumber: '255712345678');
      notifier.reset();

      expect(container.read(paymentFlowProvider(100)), isA<PaymentFlowIdle>());
    });
  });
}