import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/models/auth/auth_user.dart';
import 'package:ods_app/data/repositories/user_repository.dart';
import 'package:ods_app/features/owner/presentation/providers/owner_user_providers.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';

class _FakeRepo extends UserRepository {
  _FakeRepo(this._result) : super(dio: Dio());
  final ApiResult<List<AuthUser>> _result;
  String? lastRole;
  String? lastStatus;
  String? lastSearch;

  @override
  Future<ApiResult<List<AuthUser>>> list({
    String? role,
    String? status,
    int? branchId,
    String? search,
    int? perPage,
    int page = 1,
  }) async {
    lastRole = role;
    lastStatus = status;
    lastSearch = search;
    return _result;
  }
}

AuthUser _user(int id) => AuthUser(
      id: id,
      name: 'User $id',
      email: 'u$id@ods.test',
      phone: '0712345678',
      role: 'manager',
      status: 'active',
      dispatcherEnabled: false,
      permissions: const [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  group('OwnerUsersFilter', () {
    test('equality includes all fields', () {
      expect(
        const OwnerUsersFilter(role: 'rider'),
        const OwnerUsersFilter(role: 'rider'),
      );
      expect(
        const OwnerUsersFilter(role: 'rider'),
        isNot(const OwnerUsersFilter(role: 'manager')),
      );
    });

    test('copyWith keeps untouched fields', () {
      const original = OwnerUsersFilter(role: 'rider', status: 'active');
      final copy = original.copyWith(search: 'tom');
      expect(copy.role, 'rider');
      expect(copy.status, 'active');
      expect(copy.search, 'tom');
    });

    test('copyWith supports clearing via null', () {
      const original = OwnerUsersFilter(role: 'rider');
      final copy = original.copyWith(role: null);
      expect(copy.role, isNull);
    });
  });

  group('ownerUsersProvider', () {
    test('returns list with current filter passed through', () async {
      final repo = _FakeRepo(ApiSuccess([_user(1), _user(2)]));
      final container = ProviderContainer(overrides: [
        userRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      container.read(ownerUsersFilterProvider.notifier).state =
          const OwnerUsersFilter(role: 'rider', status: 'active');

      final users = await container.read(ownerUsersProvider.future);

      expect(users.length, 2);
      expect(repo.lastRole, 'rider');
      expect(repo.lastStatus, 'active');
    });

    test('refetches when filter changes', () async {
      final repo = _FakeRepo(ApiSuccess([_user(1)]));
      final container = ProviderContainer(overrides: [
        userRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      await container.read(ownerUsersProvider.future);
      expect(repo.lastRole, isNull);

      container.read(ownerUsersFilterProvider.notifier).state =
          const OwnerUsersFilter(role: 'manager');
      await container.read(ownerUsersProvider.future);
      expect(repo.lastRole, 'manager');
    });
  });
}