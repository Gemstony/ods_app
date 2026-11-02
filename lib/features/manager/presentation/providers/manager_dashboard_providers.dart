import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/manager_dashboard_kpis.dart';
import '../../../../shared/providers/repository_providers.dart';

/// The signed-in Manager's dashboard KPIs.
///
/// Cached for the session. Refresh by calling
/// `ref.invalidate(managerDashboardProvider)` — the `ManagerHomeTab`'s
/// pull-to-refresh does exactly that.
final managerDashboardProvider =
    FutureProvider<ManagerDashboardKpis>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  final result = await repo.getManagerKpis();

  return result.fold(
    onSuccess: (kpis) => kpis,
    onFailure: (failure) => throw failure,
  );
});