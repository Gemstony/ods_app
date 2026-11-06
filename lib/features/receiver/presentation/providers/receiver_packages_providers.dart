import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/delivery.dart';
import '../../../../shared/providers/repository_providers.dart';

/// Filter state for the Packages tab. `null` = "All".
class ReceiverPackagesFilter {
  final DeliveryStatus? status;
  const ReceiverPackagesFilter({this.status});

  bool get isEmpty => status == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceiverPackagesFilter && other.status == status;

  @override
  int get hashCode => status.hashCode;
}

class ReceiverPackagesFilterNotifier
    extends StateNotifier<ReceiverPackagesFilter> {
  ReceiverPackagesFilterNotifier() : super(const ReceiverPackagesFilter());

  void setStatus(DeliveryStatus? status) {
    if (status == state.status) return;
    state = ReceiverPackagesFilter(status: status);
  }

  void clear() {
    if (state.isEmpty) return;
    state = const ReceiverPackagesFilter();
  }
}

final receiverPackagesFilterProvider = StateNotifierProvider<
    ReceiverPackagesFilterNotifier, ReceiverPackagesFilter>(
  (ref) => ReceiverPackagesFilterNotifier(),
);

/// Fetches the receiver's branch packages.
///
/// Server-side default statuses = everything still at the branch
/// (paid / batched / assigned / accepted). Filtering by status runs
/// client-side per [receiverPackagesFilterProvider] — instant chip
/// toggles without a re-fetch.
final receiverPackagesProvider = FutureProvider<List<Delivery>>((ref) async {
  final repo = ref.watch(deliveryRepositoryProvider);
  final result = await repo.listReceiverPackages(perPage: 100);
  return result.fold(
    onSuccess: (list) => list,
    onFailure: (failure) => throw failure,
  );
});

final filteredReceiverPackagesProvider = Provider<List<Delivery>>((ref) {
  final packages =
      ref.watch(receiverPackagesProvider).valueOrNull ?? const [];
  final filter = ref.watch(receiverPackagesFilterProvider);
  if (filter.status == null) return packages;
  return packages
      .where((d) => d.status == filter.status)
      .toList(growable: false);
});