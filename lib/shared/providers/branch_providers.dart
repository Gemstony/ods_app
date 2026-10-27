import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failure.dart';
import '../../data/models/branch.dart';
import 'auth_provider.dart';
import 'repository_providers.dart';

/// The signed-in user's branch ID, or null.
///
/// Reads only `user.branchId` from session — never re-runs on token refresh
/// (which replaces the session object but not the underlying user data).
///
/// Returns null for Owner and Distributor (no branch binding).
final currentBranchIdProvider = Provider<int?>((ref) {
  return ref.watch(
    sessionProvider.select((s) => s.valueOrNull?.user.branchId),
  );
});

/// The signed-in user's full [Branch], or null.
///
/// Behaviour:
///   - No branchId (Owner, Distributor, signed out) → returns null without
///     any network call.
///   - Branch deleted server-side (404)             → returns null.
///   - Network / server error                        → **throws** so the UI
///     can show a retry affordance. Silent failure would hide bugs.
///   - Auth failure                                  → **throws** so the
///     `RefreshInterceptor`'s `onSessionExpired` handler can act on it.
///
/// Cached for the session. Call `ref.invalidate(currentBranchProvider)`
/// after updating the branch (Phase 6) or on pull-to-refresh.
final currentBranchProvider = FutureProvider<Branch?>((ref) async {
  final branchId = ref.watch(currentBranchIdProvider);
  if (branchId == null) return null;

  final repo = ref.watch(branchRepositoryProvider);
  final result = await repo.get(branchId);

  return result.fold(
    onSuccess: (branch) => branch,
    onFailure: (Failure failure) {
      if (failure.type == FailureType.notFound) return null;
      throw failure;
    },
  );
});