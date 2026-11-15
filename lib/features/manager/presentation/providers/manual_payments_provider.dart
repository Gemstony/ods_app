import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/manager_manual_payment.dart';
import '../../../../data/repositories/manual_payment_repository.dart';

/// Provider for [ManualPaymentRepository]. Override in tests with a
/// fake to avoid network calls.
final manualPaymentRepositoryProvider =
    Provider<ManualPaymentRepository>((ref) => ManualPaymentRepository());

/// Pending manual payments scoped to the Manager's own branch.
final managerPendingManualPaymentsProvider =
    FutureProvider<List<ManagerManualPayment>>((ref) async {
  final repo = ref.watch(manualPaymentRepositoryProvider);
  final result = await repo.listPending(forOwner: false);
  return result.fold(
    onSuccess: (list) => list,
    onFailure: (f) => throw f,
  );
});

/// Pending manual payments across ALL branches — Owner fallback.
final ownerPendingManualPaymentsProvider =
    FutureProvider<List<ManagerManualPayment>>((ref) async {
  final repo = ref.watch(manualPaymentRepositoryProvider);
  final result = await repo.listPending(forOwner: true);
  return result.fold(
    onSuccess: (list) => list,
    onFailure: (f) => throw f,
  );
});