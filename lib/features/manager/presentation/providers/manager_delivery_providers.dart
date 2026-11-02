import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/delivery.dart';
import '../../../../shared/providers/repository_providers.dart';

/// Filter state for the Manager's Deliveries tab.
///
/// Grouped status filters help managers see operational slices at a
/// glance. `In transit` requires comma-separated status support from
/// the backend (added in 6.4).
class ManagerDeliveriesFilter {
  /// Null = all statuses. Non-null = only matching statuses.
  final List<DeliveryStatus>? statuses;
  final ServiceType? serviceType;

  /// Client-side search on tracking ID. The backend doesn't support
  /// delivery search — we filter the loaded list here.
  final String? search;

  const ManagerDeliveriesFilter({
    this.statuses,
    this.serviceType,
    this.search,
  });

  ManagerDeliveriesFilter copyWith({
    Object? statuses = _sentinel,
    Object? serviceType = _sentinel,
    Object? search = _sentinel,
  }) {
    return ManagerDeliveriesFilter(
      statuses: identical(statuses, _sentinel)
          ? this.statuses
          : statuses as List<DeliveryStatus>?,
      serviceType: identical(serviceType, _sentinel)
          ? this.serviceType
          : serviceType as ServiceType?,
      search: identical(search, _sentinel) ? this.search : search as String?,
    );
  }

  static const Object _sentinel = Object();
}

final managerDeliveriesFilterProvider =
    StateProvider<ManagerDeliveriesFilter>(
  (ref) => const ManagerDeliveriesFilter(),
);

/// All deliveries for the manager's branch matching the current filter.
///
/// Fetches up to 100 per page. Client-side search is applied on the
/// result — no server support for tracking-ID search yet.
final managerDeliveriesProvider = FutureProvider<List<Delivery>>((ref) async {
  final filter = ref.watch(managerDeliveriesFilterProvider);
  final repo = ref.watch(deliveryRepositoryProvider);

  final result = await repo.listForBranch(
    statuses: filter.statuses,
    serviceType: filter.serviceType,
    perPage: 100,
  );

  return result.fold(
    onSuccess: (deliveries) {
      final search = filter.search?.toLowerCase().trim();
      if (search == null || search.isEmpty) return deliveries;
      return deliveries
          .where((d) => d.trackingId.toLowerCase().contains(search))
          .toList(growable: false);
    },
    onFailure: (failure) => throw failure,
  );
});

/// A single delivery, refetched for the detail screen's pull-to-refresh.
final managerDeliveryDetailProvider =
    FutureProvider.family<Delivery, int>((ref, id) async {
  final repo = ref.watch(deliveryRepositoryProvider);
  final result = await repo.getForBranch(id);

  return result.fold(
    onSuccess: (delivery) => delivery,
    onFailure: (failure) => throw failure,
  );
});