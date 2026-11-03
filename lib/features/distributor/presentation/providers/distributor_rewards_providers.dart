import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/distributor_dashboard_kpis.dart';
import '../../../../shared/providers/repository_providers.dart';

/// The signed-in Distributor's rewards progress + thresholds.
///
/// Unlike [myRewardProgressProvider] (4.6, used by the dashboard's small
/// rewards card), this provider surfaces errors — the Rewards tab is
/// where the user goes to understand their progress, so silent failures
/// are wrong here. Refresh via `ref.invalidate(distributorRewardsProvider)`.
final distributorRewardsProvider =
    FutureProvider<DistributorRewardKpis>((ref) async {
  final repo = ref.watch(rewardRepositoryProvider);
  final result = await repo.getMyOverview();

  return result.fold(
    onSuccess: (overview) => overview,
    onFailure: (failure) => throw failure,
  );
});