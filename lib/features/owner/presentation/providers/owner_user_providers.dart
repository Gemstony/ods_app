import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/auth/auth_user.dart';
import '../../../../shared/providers/repository_providers.dart';

/// Value class describing the current filter on the Users tab.
///
/// Defined as an immutable value class with `==`/`hashCode` so
/// `StateProvider` correctly detects changes and rebuilds dependents.
class OwnerUsersFilter {
  final String? role;
  final String? status;
  final int? branchId;
  final String? search;

  const OwnerUsersFilter({
    this.role,
    this.status,
    this.branchId,
    this.search,
  });

  OwnerUsersFilter copyWith({
    Object? role = _sentinel,
    Object? status = _sentinel,
    Object? branchId = _sentinel,
    Object? search = _sentinel,
  }) {
    return OwnerUsersFilter(
      role: identical(role, _sentinel) ? this.role : role as String?,
      status: identical(status, _sentinel) ? this.status : status as String?,
      branchId: identical(branchId, _sentinel)
          ? this.branchId
          : branchId as int?,
      search: identical(search, _sentinel) ? this.search : search as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OwnerUsersFilter &&
          runtimeType == other.runtimeType &&
          role == other.role &&
          status == other.status &&
          branchId == other.branchId &&
          search == other.search;

  @override
  int get hashCode => Object.hash(role, status, branchId, search);

  static const Object _sentinel = Object();
}

/// Current filter on the Users tab.
final ownerUsersFilterProvider =
    StateProvider<OwnerUsersFilter>((ref) => const OwnerUsersFilter());

/// Users matching the current filter.
final ownerUsersProvider = FutureProvider<List<AuthUser>>((ref) async {
  final filter = ref.watch(ownerUsersFilterProvider);
  final repo = ref.watch(userRepositoryProvider);

  final result = await repo.list(
    role: filter.role,
    status: filter.status,
    branchId: filter.branchId,
    search: filter.search,
    perPage: 100,
  );

  return result.fold(
    onSuccess: (users) => users,
    onFailure: (failure) => throw failure,
  );
});

/// A single user by ID — used by the detail screen.
final ownerUserProvider =
    FutureProvider.family<AuthUser, int>((ref, id) async {
  final repo = ref.watch(userRepositoryProvider);
  final result = await repo.get(id);

  return result.fold(
    onSuccess: (user) => user,
    onFailure: (failure) => throw failure,
  );
});