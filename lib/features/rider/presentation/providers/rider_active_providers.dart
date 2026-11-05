import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/delivery.dart';
import 'rider_tasks_providers.dart';

/// Deliveries currently in the rider's hands — status is `accepted`
/// (on the way to pickup) or `picked_up` (package in hand, en route to
/// recipient).
///
/// Derived from [riderTasksProvider] so the Active tab reuses the same
/// fetch that the Tasks tab and Home tab already run — one HTTP call
/// per refresh, no cross-tab staleness. Invalidating [riderTasksProvider]
/// (or [riderHomeProvider]) automatically refreshes this view.
final riderActiveDeliveriesProvider = Provider<List<Delivery>>((ref) {
  final tasks = ref.watch(riderTasksProvider).valueOrNull ?? const [];
  return tasks
      .where((d) =>
          d.status == DeliveryStatus.accepted ||
          d.status == DeliveryStatus.picked_up)
      .toList(growable: false);
});