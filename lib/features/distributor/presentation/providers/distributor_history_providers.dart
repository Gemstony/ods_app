import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/delivery.dart';
import '../../../../shared/providers/repository_providers.dart';

/// Grouped status filter for the History tab.
enum DistributorHistoryGroup {
  all,
  active,    // paid, batched, assigned, accepted, picked_up, dispatched
  delivered,
  cancelled, // cancelled, failed, expired
}

/// Filter state for the History tab.
///
/// Value class with `==` / `hashCode` so `StateProvider` correctly
/// detects changes and rebuilds dependents.
class DistributorHistoryFilter {
  final DistributorHistoryGroup group;
  final ServiceType? serviceType;
  final String? search;

  const DistributorHistoryFilter({
    this.group = DistributorHistoryGroup.all,
    this.serviceType,
    this.search,
  });

  DistributorHistoryFilter copyWith({
    DistributorHistoryGroup? group,
    Object? serviceType = _sentinel,
    Object? search = _sentinel,
  }) {
    return DistributorHistoryFilter(
      group: group ?? this.group,
      serviceType: identical(serviceType, _sentinel)
          ? this.serviceType
          : serviceType as ServiceType?,
      search: identical(search, _sentinel) ? this.search : search as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DistributorHistoryFilter &&
          runtimeType == other.runtimeType &&
          group == other.group &&
          serviceType == other.serviceType &&
          search == other.search;

  @override
  int get hashCode => Object.hash(group, serviceType, search);

  static const Object _sentinel = Object();
}

final distributorHistoryFilterProvider =
    StateProvider<DistributorHistoryFilter>(
  (ref) => const DistributorHistoryFilter(),
);

/// The distributor's own deliveries, filtered client-side.
///
/// Fetches up to 100 deliveries from `GET /distributor/deliveries`. The
/// backend supports server-side filters, but for the History tab we
/// fetch once and filter in memory — instant response on every chip
/// tap and keystroke, no re-fetch, no spinner flicker.
final distributorHistoryProvider = FutureProvider<List<Delivery>>((ref) async {
  final filter = ref.watch(distributorHistoryFilterProvider);
  final repo = ref.watch(deliveryRepositoryProvider);

  final result = await repo.listMine(limit: 100);

  return result.fold(
    onSuccess: (deliveries) => _applyFilter(deliveries, filter),
    onFailure: (failure) => throw failure,
  );
});

/// A single delivery, re-fetched for the detail screen's pull-to-refresh.
final distributorDeliveryDetailProvider =
    FutureProvider.family<Delivery, int>((ref, id) async {
  final repo = ref.watch(deliveryRepositoryProvider);
  final result = await repo.getMine(id);

  return result.fold(
    onSuccess: (delivery) => delivery,
    onFailure: (failure) => throw failure,
  );
});

// ─────────────────────────────────────────────────────────────
// Internal filter
// ─────────────────────────────────────────────────────────────

const _activeStatuses = <DeliveryStatus>{
  DeliveryStatus.paid,
  DeliveryStatus.batched,
  DeliveryStatus.assigned,
  DeliveryStatus.accepted,
  DeliveryStatus.picked_up,
  DeliveryStatus.dispatched,
};

const _cancelledStatuses = <DeliveryStatus>{
  DeliveryStatus.cancelled,
  DeliveryStatus.failed,
  DeliveryStatus.expired,
};

List<Delivery> _applyFilter(
  List<Delivery> deliveries,
  DistributorHistoryFilter filter,
) {
  Iterable<Delivery> result = deliveries;

  switch (filter.group) {
    case DistributorHistoryGroup.all:
      break;
    case DistributorHistoryGroup.active:
      result = result.where((d) => _activeStatuses.contains(d.status));
    case DistributorHistoryGroup.delivered:
      result = result.where((d) => d.status == DeliveryStatus.delivered);
    case DistributorHistoryGroup.cancelled:
      result = result.where((d) => _cancelledStatuses.contains(d.status));
  }

  if (filter.serviceType != null) {
    result = result.where((d) => d.serviceType == filter.serviceType);
  }

  final search = filter.search?.toLowerCase().trim();
  if (search != null && search.isNotEmpty) {
    result = result.where(
      (d) => d.trackingId.toLowerCase().contains(search),
    );
  }

  return result.toList(growable: false);
}