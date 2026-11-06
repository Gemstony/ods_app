import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/delivery.dart';
import '../../../../shared/providers/repository_providers.dart';

/// Filter state for the Regional tab. `null` = "All".
class ReceiverRegionalFilter {
  final DeliveryStatus? status;
  const ReceiverRegionalFilter({this.status});

  bool get isEmpty => status == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceiverRegionalFilter && other.status == status;

  @override
  int get hashCode => status.hashCode;
}

class ReceiverRegionalFilterNotifier
    extends StateNotifier<ReceiverRegionalFilter> {
  ReceiverRegionalFilterNotifier() : super(const ReceiverRegionalFilter());

  void setStatus(DeliveryStatus? status) {
    if (status == state.status) return;
    state = ReceiverRegionalFilter(status: status);
  }

  void clear() {
    if (state.isEmpty) return;
    state = const ReceiverRegionalFilter();
  }
}

final receiverRegionalFilterProvider = StateNotifierProvider<
    ReceiverRegionalFilterNotifier, ReceiverRegionalFilter>(
  (ref) => ReceiverRegionalFilterNotifier(),
);

/// Regional deliveries at the receiver's branch.
///
/// Backend 9.1 gates this on `dispatcher_enabled`. The tab UI checks
/// `currentUserProvider.dispatcherEnabled` before rendering this
/// provider, so a plain receiver never triggers the 403.
final receiverRegionalProvider =
    FutureProvider<List<Delivery>>((ref) async {
  final repo = ref.watch(deliveryRepositoryProvider);
  // Explicit broad statuses so the filter chips have data to work with:
  // batched (default), assigned (mid-flow), dispatched (post-dispatch
  // history view).
  final result = await repo.listReceiverRegional(
    statuses: const [
      DeliveryStatus.batched,
      DeliveryStatus.assigned,
      DeliveryStatus.dispatched,
    ],
    perPage: 100,
  );
  return result.fold(
    onSuccess: (list) => list,
    onFailure: (failure) => throw failure,
  );
});

final filteredReceiverRegionalProvider = Provider<List<Delivery>>((ref) {
  final regional = ref.watch(receiverRegionalProvider).valueOrNull ?? const [];
  final filter = ref.watch(receiverRegionalFilterProvider);
  if (filter.status == null) return regional;
  return regional
      .where((d) => d.status == filter.status)
      .toList(growable: false);
});