import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/distributor_dashboard_kpis.dart';
import '../../../../shared/providers/repository_providers.dart';

/// The signed-in Distributor's dashboard KPIs.
///
/// Cached for the session. Refresh via
/// `ref.invalidate(distributorDashboardProvider)` — the Home tab's
/// pull-to-refresh does exactly that.
final distributorDashboardProvider =
    FutureProvider<DistributorDashboardKpis>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  final result = await repo.getDistributorKpis();

  return result.fold(
    onSuccess: (kpis) => kpis,
    onFailure: (failure) => throw failure,
  );
});