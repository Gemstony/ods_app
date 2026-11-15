import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/payment.dart';
import '../../../../shared/providers/repository_providers.dart';

/// State machine for a single payment attempt.
sealed class PaymentFlowState {
  const PaymentFlowState();
}

class PaymentFlowIdle extends PaymentFlowState {
  const PaymentFlowIdle();
}

class PaymentFlowBusy extends PaymentFlowState {
  final String message;
  const PaymentFlowBusy(this.message);
}

class PaymentFlowInFlight extends PaymentFlowState {
  final Payment payment;
  const PaymentFlowInFlight(this.payment);
}

/// Phase 13.7 — Manual payment recorded, awaiting Manager approval.
/// No polling — the user checks status manually or on next app open.
class PaymentFlowAwaitingApproval extends PaymentFlowState {
  final Payment payment;
  const PaymentFlowAwaitingApproval(this.payment);
}

class PaymentFlowSuccess extends PaymentFlowState {
  final Payment payment;
  const PaymentFlowSuccess(this.payment);
}

class PaymentFlowFailed extends PaymentFlowState {
  final Payment payment;
  const PaymentFlowFailed(this.payment);
}

class PaymentFlowError extends PaymentFlowState {
  final String message;
  const PaymentFlowError(this.message);
}

/// Owns one payment flow for a single delivery (Phase 11.5 / 13.7).
class PaymentFlowNotifier extends StateNotifier<PaymentFlowState> {
  PaymentFlowNotifier({
    required this.ref,
    required this.deliveryId,
  }) : super(const PaymentFlowIdle());

  final Ref ref;
  final int deliveryId;

  static const _pollInterval = Duration(seconds: 5);
  static const _pollTimeout = Duration(minutes: 10);

  Timer? _pollTimer;
  Timer? _timeoutTimer;
  bool _disposed = false;
  int? _activePaymentId;

  // ─── Public API ──────────────────────────────────────────

  Future<void> initiate({
    required String phoneNumber,
    PaymentStage stage = PaymentStage.full,
  }) async {
    _cancelTimers();
    state = const PaymentFlowBusy('Sending USSD prompt…');

    final repo = ref.read(paymentRepositoryProvider);
    final result = await repo.initiate(
      deliveryId: deliveryId,
      phoneNumber: phoneNumber,
      stage: stage,
    );

    if (_disposed) return;

    result.fold(
      onSuccess: (payment) {
        _activePaymentId = payment.id;
        _enterState(payment);
      },
      onFailure: (f) => state = PaymentFlowError(f.message),
    );
  }

  /// Phase 13.7 — Manual payment. No polling after this call.
  Future<void> initiateManual({
    required String method, // 'cash' | 'manual'
    PaymentStage stage = PaymentStage.full,
    String? notes,
  }) async {
    _cancelTimers();
    state = const PaymentFlowBusy('Recording manual payment…');

    final repo = ref.read(paymentRepositoryProvider);
    final result = await repo.manual(
      deliveryId: deliveryId,
      method: method,
      stage: stage,
      notes: notes,
    );

    if (_disposed) return;

    result.fold(
      onSuccess: (payment) {
        _activePaymentId = payment.id;
        // Manual payments are always `pending` at this point — go
        // straight to the awaiting-approval state without polling.
        state = PaymentFlowAwaitingApproval(payment);
      },
      onFailure: (f) => state = PaymentFlowError(f.message),
    );
  }

  Future<void> refreshNow() async {
    final id = _activePaymentId ?? _currentPaymentId();
    if (id == null) return;

    final repo = ref.read(paymentRepositoryProvider);
    final result = await repo.refresh(id);

    if (_disposed) return;

    result.fold(
      onSuccess: (payment) => _enterState(payment),
      onFailure: (f) => state = PaymentFlowError(f.message),
    );
  }

  void reset() {
    _cancelTimers();
    _activePaymentId = null;
    state = const PaymentFlowIdle();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelTimers();
    super.dispose();
  }

  // ─── Internal ────────────────────────────────────────────

  void _enterState(Payment payment) {
    if (payment.status.isTerminal) {
      _cancelTimers();
      state = payment.status.isSuccess
          ? PaymentFlowSuccess(payment)
          : PaymentFlowFailed(payment);
      return;
    }

    // Manual payments never poll — the Manager controls the transition.
    if (payment.method == PaymentMethod.cash ||
        payment.method == PaymentMethod.manual) {
      _cancelTimers();
      state = PaymentFlowAwaitingApproval(payment);
      return;
    }

    state = PaymentFlowInFlight(payment);
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) async {
      if (_disposed) return;
      final id = _activePaymentId;
      if (id == null) return;

      final repo = ref.read(paymentRepositoryProvider);
      final result = await repo.refresh(id);

      if (_disposed) return;

      result.fold(
        onSuccess: (payment) => _enterState(payment),
        onFailure: (_) {},
      );
    });

    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_pollTimeout, () {
      if (_disposed) return;
      _pollTimer?.cancel();
      _pollTimer = null;
      state = const PaymentFlowError(
        'Taking longer than expected. Check your phone, or tap Refresh status.',
      );
    });
  }

  void _cancelTimers() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  int? _currentPaymentId() {
    return switch (state) {
      PaymentFlowInFlight(:final payment) => payment.id,
      PaymentFlowAwaitingApproval(:final payment) => payment.id,
      PaymentFlowSuccess(:final payment) => payment.id,
      PaymentFlowFailed(:final payment) => payment.id,
      _ => null,
    };
  }
}

/// Per-delivery payment flow. Auto-disposes when the modal closes.
final paymentFlowProvider = StateNotifierProvider.autoDispose
    .family<PaymentFlowNotifier, PaymentFlowState, int>((ref, deliveryId) {
  return PaymentFlowNotifier(ref: ref, deliveryId: deliveryId);
});