import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/delivery.dart';
import '../../../../shared/providers/repository_providers.dart';

/// Filter state for the History tab. `null` = "All".
class ReceiverHistoryFilter {
  final DeliveryStatus? status;
  const ReceiverHistoryFilter({this.status});

  bool get isEmpty => status == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceiverHistoryFilter && other.status == status;

  @override
  int get hashCode => status.hashCode;
}

class ReceiverHistoryFilterNotifier
    extends StateNotifier<ReceiverHistoryFilter> {
  ReceiverHistoryFilterNotifier() : super(const ReceiverHistoryFilter());

  void setStatus(DeliveryStatus? status) {
    if (status == state.status) return;
    state = ReceiverHistoryFilter(status: status);
  }

  void clear() {
    if (state.isEmpty) return;
    state = const ReceiverHistoryFilter();
  }
}

final receiverHistoryFilterProvider = StateNotifierProvider<
    ReceiverHistoryFilterNotifier, ReceiverHistoryFilter>(
  (ref) => ReceiverHistoryFilterNotifier(),
);

/// Completed handovers at the receiver's branch:
///   - receive deliveries that were `picked_up` (released to rider)
///     or later `delivered` (rider confirmed the handover downstream)
///   - regional deliveries that were `dispatched` (on the bus) or later
///     `delivered`
///
/// The two queries run in parallel; results merge and sort by the
/// meaningful "completed at" timestamp for each row, descending.
final receiverHistoryProvider = FutureProvider<List<Delivery>>((ref) async {
  final repo = ref.watch(deliveryRepositoryProvider);

  final packagesFuture = repo.listReceiverPackages(
    statuses: const [
      DeliveryStatus.picked_up,
      DeliveryStatus.delivered,
    ],
    perPage: 100,
  );
  final regionalFuture = repo.listReceiverRegional(
    statuses: const [
      DeliveryStatus.dispatched,
      DeliveryStatus.delivered,
    ],
    perPage: 100,
  );

  final packagesResult = await packagesFuture;
  final regionalResult = await regionalFuture;

  final packages = packagesResult.fold(
    onSuccess: (l) => l,
    onFailure: (f) => throw f,
  );
  final regional = regionalResult.fold(
    onSuccess: (l) => l,
    onFailure: (f) => throw f,
  );

  final combined = [...packages, ...regional];
  combined.sort((a, b) {
    final aTime = _sortTimeFor(a);
    final bTime = _sortTimeFor(b);
    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    return bTime.compareTo(aTime);
  });

  return combined;
});

DateTime? _sortTimeFor(Delivery d) {
  switch (d.status) {
    case DeliveryStatus.picked_up:
      return d.pickedUpAt ?? d.updatedAt ?? d.createdAt;
    case DeliveryStatus.dispatched:
      return d.dispatchedAt ?? d.updatedAt ?? d.createdAt;
    case DeliveryStatus.delivered:
      return d.deliveredAt ?? d.updatedAt ?? d.createdAt;
    default:
      return d.updatedAt ?? d.createdAt;
  }
}

final filteredReceiverHistoryProvider = Provider<List<Delivery>>((ref) {
  final history =
      ref.watch(receiverHistoryProvider).valueOrNull ?? const [];
  final filter = ref.watch(receiverHistoryFilterProvider);
  if (filter.status == null) return history;
  return history
      .where((d) => d.status == filter.status)
      .toList(growable: false);
});