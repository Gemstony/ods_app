import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/earning.dart';
import '../../../../data/repositories/earnings_repository.dart';
import '../../../../shared/providers/repository_providers.dart';

/// Status filter for the Earnings tab. `null` = "All".
class RiderEarningsFilter {
  final EarningStatus? status;
  const RiderEarningsFilter({this.status});

  bool get isEmpty => status == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiderEarningsFilter && other.status == status;

  @override
  int get hashCode => status.hashCode;
}

class RiderEarningsFilterNotifier
    extends StateNotifier<RiderEarningsFilter> {
  RiderEarningsFilterNotifier() : super(const RiderEarningsFilter());

  void setStatus(EarningStatus? status) {
    if (status == state.status) return;
    state = RiderEarningsFilter(status: status);
  }

  void clear() {
    if (state.isEmpty) return;
    state = const RiderEarningsFilter();
  }
}

final riderEarningsFilterProvider =
    StateNotifierProvider<RiderEarningsFilterNotifier, RiderEarningsFilter>(
  (ref) => RiderEarningsFilterNotifier(),
);

/// Fetches the rider's earnings ledger.
///
/// Refresh via `ref.invalidate(riderEarningsProvider)` — the tab's
/// pull-to-refresh does exactly that.
final riderEarningsProvider = FutureProvider<EarningsResult>((ref) async {
  final repo = ref.watch(earningsRepositoryProvider);
  final result = await repo.listMine(perPage: 50);
  return result.fold(
    onSuccess: (r) => r,
    onFailure: (f) => throw f,
  );
});

/// Client-side filtered view of the earnings list.
///
/// Filtering client-side (rather than re-fetching with `?status=`) keeps
/// chip toggles instantaneous and avoids a loading flicker per tap. With
/// a 50-row cap that's negligible memory, and totals in the header always
/// stay scoped to the *unfiltered* summary from the server.
final filteredRiderEarningsProvider = Provider<List<Earning>>((ref) {
  final earnings =
      ref.watch(riderEarningsProvider).valueOrNull?.items ?? const [];
  final filter = ref.watch(riderEarningsFilterProvider);
  if (filter.status == null) return earnings;
  return earnings
      .where((e) => e.status == filter.status)
      .toList(growable: false);
});