import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/auth/auth_user.dart';
import '../../../../shared/providers/repository_providers.dart';

/// Filter state for the Staff tab.
///
/// Value-class equality so `StateProvider` correctly detects changes and
/// rebuilds dependents.
class ManagerStaffFilter {
  final String? role;     // 'receiver' | 'rider' | null (all)
  final String? status;   // 'active' | 'suspended' | 'deactivated' | null
  final String? search;

  const ManagerStaffFilter({
    this.role,
    this.status,
    this.search,
  });

  ManagerStaffFilter copyWith({
    Object? role = _sentinel,
    Object? status = _sentinel,
    Object? search = _sentinel,
  }) {
    return ManagerStaffFilter(
      role: identical(role, _sentinel) ? this.role : role as String?,
      status: identical(status, _sentinel) ? this.status : status as String?,
      search: identical(search, _sentinel) ? this.search : search as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ManagerStaffFilter &&
          runtimeType == other.runtimeType &&
          role == other.role &&
          status == other.status &&
          search == other.search;

  @override
  int get hashCode => Object.hash(role, status, search);

  static const Object _sentinel = Object();
}

final managerStaffFilterProvider =
    StateProvider<ManagerStaffFilter>((ref) => const ManagerStaffFilter());

/// Staff list matching the current filter.
final managerStaffProvider = FutureProvider<List<AuthUser>>((ref) async {
  final filter = ref.watch(managerStaffFilterProvider);
  final repo = ref.watch(staffRepositoryProvider);

  final result = await repo.list(
    role: filter.role,
    status: filter.status,
    search: filter.search,
    perPage: 100,
  );

  return result.fold(
    onSuccess: (users) => users,
    onFailure: (failure) => throw failure,
  );
});

/// A single staff member by ID.
final managerStaffDetailProvider =
    FutureProvider.family<AuthUser, int>((ref, id) async {
  final repo = ref.watch(staffRepositoryProvider);
  final result = await repo.get(id);

  return result.fold(
    onSuccess: (user) => user,
    onFailure: (failure) => throw failure,
  );
});