import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failure.dart';
import '../../data/models/dashboard_kpis.dart';
import 'repository_providers.dart';

/// The Owner's dashboard KPIs.
///
/// Cached for the session. Refresh by calling
/// `ref.invalidate(ownerDashboardProvider)` — the `OwnerHomeTab`'s
/// pull-to-refresh does exactly that.
///
/// Errors are surfaced as `Failure`, so the tab can render
/// `ErrorView(message, onRetry: ...)` with the actual server message.
final ownerDashboardProvider = FutureProvider<DashboardKpis>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  final result = await repo.getKpis();

  return result.fold(
    onSuccess: (kpis) => kpis,
    onFailure: (failure) => throw failure,
  );
});