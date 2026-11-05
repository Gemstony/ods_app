import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/delivery.dart';
import '../../../../data/models/rider_dashboard_kpis.dart';
import '../../../../shared/providers/repository_providers.dart';

/// Combined Rider Home-tab data.
///
/// Bundles two endpoints into one provider so the widget has a single
/// loading state, a single error state, and a single retry action:
///   - `GET /rider/dashboard`   → KPI counts + earnings
///   - `GET /rider/deliveries`  → used for the hero + recent activity
///
/// Derived getters (`activeTask`, `recentDeliveries`) live here so the
/// widget stays declarative and the derivation is testable in isolation.
class RiderHomeData {
  final RiderDashboardKpis kpis;
  final List<Delivery> deliveries;

  const RiderHomeData({required this.kpis, required this.deliveries});

  /// The first `accepted` or `picked_up` delivery, or null if none.
  /// At most one such delivery is expected per rider in normal operation;
  /// if there are multiple, we show the most recent (list is newest-first).
  Delivery? get activeTask {
    for (final d in deliveries) {
      if (d.status == DeliveryStatus.accepted ||
          d.status == DeliveryStatus.picked_up) {
        return d;
      }
    }
    return null;
  }

  /// The three newest deliveries that are NOT the active task.
  ///
  /// The active task is rendered in its own hero card, so showing it
  /// again in "Recent activity" would duplicate the same tracking ID
  /// on the same screen.
  List<Delivery> get recentDeliveries {
    final activeId = activeTask?.id;
    return deliveries
        .where((d) => d.id != activeId)
        .take(3)
        .toList(growable: false);
  }
}

/// Fetches the two Home-tab data sources in parallel.
final riderHomeProvider = FutureProvider<RiderHomeData>((ref) async {
  final dashRepo = ref.watch(dashboardRepositoryProvider);
  final delRepo = ref.watch(deliveryRepositoryProvider);

  // Kick both off before awaiting either — saves one round-trip worth
  // of latency.
  final kpisFuture = dashRepo.getRiderKpis();
  final deliveriesFuture = delRepo.listForRider(perPage: 20);

  final kpisResult = await kpisFuture;
  final deliveriesResult = await deliveriesFuture;

  final kpis = kpisResult.fold(
    onSuccess: (k) => k,
    onFailure: (f) => throw f,
  );
  final deliveries = deliveriesResult.fold(
    onSuccess: (l) => l,
    onFailure: (f) => throw f,
  );

  return RiderHomeData(kpis: kpis, deliveries: deliveries);
});