import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/ledger_entries.dart';
import '../../../../data/models/payment_detail.dart';
import '../../../../data/models/reconciliation_report.dart';
import '../../../../shared/providers/repository_providers.dart';

// ═══════════════════════════════════════════════════════════════
// Payments
// ═══════════════════════════════════════════════════════════════

class PaymentsFilter {
  final List<String> statuses; // empty = all
  final String? method;
  final String? reference;

  const PaymentsFilter({
    this.statuses = const [],
    this.method,
    this.reference,
  });

  PaymentsFilter copyWith({
    List<String>? statuses,
    String? method,
    String? reference,
    bool clearMethod = false,
    bool clearReference = false,
  }) {
    return PaymentsFilter(
      statuses: statuses ?? this.statuses,
      method: clearMethod ? null : (method ?? this.method),
      reference: clearReference ? null : (reference ?? this.reference),
    );
  }
}

class PaymentsFilterNotifier extends StateNotifier<PaymentsFilter> {
  PaymentsFilterNotifier() : super(const PaymentsFilter());

  void setStatuses(List<String> statuses) {
    state = state.copyWith(statuses: statuses);
  }

  void setMethod(String? method) {
    state = method == null
        ? state.copyWith(clearMethod: true)
        : state.copyWith(method: method);
  }

  void setReference(String? reference) {
    final t = reference?.trim();
    state = (t == null || t.isEmpty)
        ? state.copyWith(clearReference: true)
        : state.copyWith(reference: t);
  }

  void clear() => state = const PaymentsFilter();
}

final paymentsFilterProvider =
    StateNotifierProvider<PaymentsFilterNotifier, PaymentsFilter>(
  (ref) => PaymentsFilterNotifier(),
);

final ownerPaymentsProvider =
    FutureProvider<List<OwnerPaymentEntry>>((ref) async {
  final repo = ref.watch(ownerLedgerRepositoryProvider);
  final filter = ref.watch(paymentsFilterProvider);

  final result = await repo.listPayments(
    statuses: filter.statuses.isEmpty ? null : filter.statuses,
    method: filter.method,
    reference: filter.reference,
    perPage: 50,
  );
  return result.fold(
    onSuccess: (list) => list,
    onFailure: (f) => throw f,
  );
});

final ownerPaymentDetailProvider = FutureProvider.autoDispose
    .family<PaymentDetail, int>((ref, id) async {
  final repo = ref.watch(ownerLedgerRepositoryProvider);
  final result = await repo.showPayment(id);
  return result.fold(
    onSuccess: (detail) => detail,
    onFailure: (f) => throw f,
  );
});

// ═══════════════════════════════════════════════════════════════
// Earnings
// ═══════════════════════════════════════════════════════════════

class EarningsFilter {
  final List<String> statuses;
  final List<String> types;

  const EarningsFilter({
    this.statuses = const [],
    this.types = const [],
  });

  EarningsFilter copyWith({
    List<String>? statuses,
    List<String>? types,
  }) {
    return EarningsFilter(
      statuses: statuses ?? this.statuses,
      types: types ?? this.types,
    );
  }
}

class EarningsFilterNotifier extends StateNotifier<EarningsFilter> {
  EarningsFilterNotifier() : super(const EarningsFilter());

  void setStatuses(List<String> statuses) =>
      state = state.copyWith(statuses: statuses);
  void setTypes(List<String> types) => state = state.copyWith(types: types);
  void clear() => state = const EarningsFilter();
}

final earningsFilterProvider =
    StateNotifierProvider<EarningsFilterNotifier, EarningsFilter>(
  (ref) => EarningsFilterNotifier(),
);

final ownerEarningsProvider =
    FutureProvider<List<OwnerEarningEntry>>((ref) async {
  final repo = ref.watch(ownerLedgerRepositoryProvider);
  final filter = ref.watch(earningsFilterProvider);

  final result = await repo.listEarnings(
    statuses: filter.statuses.isEmpty ? null : filter.statuses,
    types: filter.types.isEmpty ? null : filter.types,
    perPage: 50,
  );
  return result.fold(
    onSuccess: (list) => list,
    onFailure: (f) => throw f,
  );
});

// ═══════════════════════════════════════════════════════════════
// Payouts
// ═══════════════════════════════════════════════════════════════

class PayoutsFilter {
  final List<String> statuses;
  final String? method;

  const PayoutsFilter({
    this.statuses = const [],
    this.method,
  });

  PayoutsFilter copyWith({
    List<String>? statuses,
    String? method,
    bool clearMethod = false,
  }) {
    return PayoutsFilter(
      statuses: statuses ?? this.statuses,
      method: clearMethod ? null : (method ?? this.method),
    );
  }
}

class PayoutsFilterNotifier extends StateNotifier<PayoutsFilter> {
  PayoutsFilterNotifier() : super(const PayoutsFilter());

  void setStatuses(List<String> statuses) =>
      state = state.copyWith(statuses: statuses);
  void setMethod(String? method) => state = method == null
      ? state.copyWith(clearMethod: true)
      : state.copyWith(method: method);
  void clear() => state = const PayoutsFilter();
}

final payoutsFilterProvider =
    StateNotifierProvider<PayoutsFilterNotifier, PayoutsFilter>(
  (ref) => PayoutsFilterNotifier(),
);

final ownerPayoutsProvider =
    FutureProvider<List<OwnerPayoutEntry>>((ref) async {
  final repo = ref.watch(ownerLedgerRepositoryProvider);
  final filter = ref.watch(payoutsFilterProvider);

  final result = await repo.listPayouts(
    statuses: filter.statuses.isEmpty ? null : filter.statuses,
    method: filter.method,
    perPage: 50,
  );
  return result.fold(
    onSuccess: (list) => list,
    onFailure: (f) => throw f,
  );
});

// ═══════════════════════════════════════════════════════════════
// Reconciliation
// ═══════════════════════════════════════════════════════════════

final reconciliationLastRunProvider =
    FutureProvider<ReconciliationLastRun>((ref) async {
  final repo = ref.watch(ownerLedgerRepositoryProvider);
  final result = await repo.lastReconciliation();
  return result.fold(
    onSuccess: (r) => r,
    onFailure: (f) => throw f,
  );
});

/// State notifier for one reconciliation run. Providers watching
/// `ownerPaymentsProvider` should be invalidated by the caller on
/// success (see OwnerReconciliationScreen).
class ReconciliationRunner
    extends StateNotifier<AsyncValue<ReconciliationReport?>> {
  ReconciliationRunner(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<ReconciliationReport?> run({
    DateTime? since,
    bool dryRun = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(ownerLedgerRepositoryProvider);
      final result = await repo.runReconciliation(since: since, dryRun: dryRun);
      return result.fold(
        onSuccess: (report) {
          state = AsyncValue.data(report);
          _ref.invalidate(reconciliationLastRunProvider);
          if (!dryRun) {
            _ref.invalidate(ownerPaymentsProvider);
          }
          return report;
        },
        onFailure: (f) {
          state = AsyncValue.error(f, StackTrace.current);
          return null;
        },
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  void reset() => state = const AsyncValue.data(null);
}

final reconciliationRunnerProvider = StateNotifierProvider<
    ReconciliationRunner, AsyncValue<ReconciliationReport?>>(
  (ref) => ReconciliationRunner(ref),
);