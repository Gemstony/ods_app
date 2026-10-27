import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/reward.dart';
import 'auth_provider.dart';
import 'repository_providers.dart';

/// The signed-in distributor's reward progress.
///
/// Returns null when:
///   - the caller isn't a distributor (no reward concept),
///   - the caller is signed out,
///   - or the fetch fails (rewards are a bonus feature; a network blip
///     should hide the widget rather than show an error dialog).
///
/// Invalidated after every successful delivery (Phase 13's post-delivery
/// hook calls `ref.invalidate(myRewardProgressProvider)`).
final myRewardProgressProvider = FutureProvider<Reward?>((ref) async {
  final isDistributor = ref.watch(
    sessionProvider.select((s) => s.valueOrNull?.user.isDistributor ?? false),
  );
  if (!isDistributor) return null;

  final repo = ref.watch(rewardRepositoryProvider);
  final result = await repo.getMyProgress();

  return result.fold(
    onSuccess: (reward) => reward,
    onFailure: (_) => null,
  );
});