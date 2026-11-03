import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/branch.dart';
import '../../../../shared/providers/repository_providers.dart';

/// The signed-in Manager's branch.
///
/// Calls `GET /manager/branch` — the correct endpoint for the Manager
/// role. (`currentBranchProvider` from 4.6 hits `/owner/branches/{id}`
/// and is Owner-only.)
///
/// Cached for the session. Refresh via `ref.invalidate(managerBranchProvider)`.
final managerBranchProvider = FutureProvider<Branch>((ref) async {
  final repo = ref.watch(branchRepositoryProvider);
  final result = await repo.getMyBranch();

  return result.fold(
    onSuccess: (branch) => branch,
    onFailure: (failure) => throw failure,
  );
});