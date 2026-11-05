import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/delivery.dart';
import '../../../../shared/providers/repository_providers.dart';

/// Filter state for the Tasks tab. `null` fields mean "no filter on
/// this dimension" — which is also how the "All" chip is represented.
class RiderTasksFilter {
  final DeliveryStatus? status;
  final ServiceType? serviceType;

  const RiderTasksFilter({this.status, this.serviceType});

  bool get isEmpty => status == null && serviceType == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiderTasksFilter &&
          other.status == status &&
          other.serviceType == serviceType;

  @override
  int get hashCode => Object.hash(status, serviceType);
}

class RiderTasksFilterNotifier extends StateNotifier<RiderTasksFilter> {
  RiderTasksFilterNotifier() : super(const RiderTasksFilter());

  void setStatus(DeliveryStatus? status) {
    if (status == state.status) return;
    state = RiderTasksFilter(status: status, serviceType: state.serviceType);
  }

  void setServiceType(ServiceType? type) {
    if (type == state.serviceType) return;
    state = RiderTasksFilter(status: state.status, serviceType: type);
  }

  void clear() {
    if (state.isEmpty) return;
    state = const RiderTasksFilter();
  }
}

final riderTasksFilterProvider = StateNotifierProvider<
    RiderTasksFilterNotifier, RiderTasksFilter>(
  (ref) => RiderTasksFilterNotifier(),
);

/// Unfiltered list of the rider's deliveries — newest first.
///
/// Capped at 50 server-side. A rider rarely has more than that in flight
/// at once; if history becomes heavy in Phase 14 we'll switch to
/// server-side filtering.
final riderTasksProvider = FutureProvider<List<Delivery>>((ref) async {
  final repo = ref.watch(deliveryRepositoryProvider);
  final result = await repo.listForRider(perPage: 50);
  return result.fold(
    onSuccess: (list) => list,
    onFailure: (failure) => throw failure,
  );
});

/// Filtered view of [riderTasksProvider] — recomputes when either the
/// task list or the filter changes.
final filteredRiderTasksProvider = Provider<List<Delivery>>((ref) {
  final tasks = ref.watch(riderTasksProvider).valueOrNull ?? const [];
  final filter = ref.watch(riderTasksFilterProvider);

  return tasks.where((d) {
    if (filter.status != null && d.status != filter.status) return false;
    if (filter.serviceType != null && d.serviceType != filter.serviceType) {
      return false;
    }
    return true;
  }).toList(growable: false);
});