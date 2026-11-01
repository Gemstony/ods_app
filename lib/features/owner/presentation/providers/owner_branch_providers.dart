import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/auth/auth_user.dart';
import '../../../../data/models/branch.dart';
import '../../../../data/models/branch_manager_assignment.dart';
import '../../../../shared/providers/repository_providers.dart';

/// All branches visible to the Owner. Invalidated after every mutation
/// (create, update, deactivate, manager changes).
final ownerBranchesProvider = FutureProvider<List<Branch>>((ref) async {
  final repo = ref.watch(branchRepositoryProvider);
  final result = await repo.list();

  return result.fold(
    onSuccess: (branches) => branches,
    onFailure: (failure) => throw failure,
  );
});

/// A single branch by id.
final ownerBranchProvider =
    FutureProvider.family<Branch, int>((ref, id) async {
  final repo = ref.watch(branchRepositoryProvider);
  final result = await repo.get(id);

  return result.fold(
    onSuccess: (branch) => branch,
    onFailure: (failure) => throw failure,
  );
});

/// Manager assignment history for a branch. Newest first.
final ownerBranchManagerHistoryProvider =
    FutureProvider.family<List<BranchManagerAssignment>, int>(
        (ref, id) async {
  final repo = ref.watch(branchRepositoryProvider);
  final result = await repo.getManagerHistory(id);

  return result.fold(
    onSuccess: (history) => history,
    onFailure: (failure) => throw failure,
  );
});

/// Active Manager users available for branch assignment.
///
/// Returns all active Managers. Callers exclude the currently-assigned
/// one client-side.
final availableManagersProvider = FutureProvider<List<AuthUser>>((ref) async {
  final repo = ref.watch(userRepositoryProvider);
  final result = await repo.list(
    role: 'manager',
    status: 'active',
    perPage: 100,
  );

  return result.fold(
    onSuccess: (users) => users,
    onFailure: (failure) => throw failure,
  );
});