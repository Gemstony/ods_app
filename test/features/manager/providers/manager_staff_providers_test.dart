import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/models/auth/auth_user.dart';
import 'package:ods_app/data/repositories/staff_repository.dart';
import 'package:ods_app/features/manager/presentation/providers/manager_staff_providers.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';

AuthUser _user(int id) => AuthUser(
      id: id,
      name: 'User $id',
      email: 'u$id@ods.test',
      phone: '0712345678',
      role: 'receiver',
      status: 'active',
      dispatcherEnabled: false,
      permissions: const [],
    );

class _FakeRepo extends StaffRepository {
  _FakeRepo(this._result) : super(dio: Dio());
  final ApiResult<List<AuthUser>> _result;
  String? lastRole;
  String? lastStatus;
  String? lastSearch;

  @override
  Future<ApiResult<List<AuthUser>>> list({
    String? role,
    String? status,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  group('ManagerStaffFilter', () {
    test('equality includes all fields', () {
      expect(
        const ManagerStaffFilter(role: 'rider'),
        const ManagerStaffFilter(role: 'rider'),
      );
      expect(
        const ManagerStaffFilter(role: 'rider'),
        isNot(const ManagerStaffFilter(role: 'receiver')),
      );
    });

    test('copyWith preserves untouched fields', () {
      const orig = ManagerStaffFilter(role: 'rider', status: 'active');
      final copy = orig.copyWith(search: 'tom');
      expect(copy.role, 'rider');
      expect(copy.status, 'active');
      expect(copy.search, 'tom');
    });

    test('copyWith supports clearing via null', () {
      const orig = ManagerStaffFilter(role: 'rider');
      final copy = orig.copyWith(role: null);
      expect(copy.role, isNull);
    });
  });

  group('managerStaffProvider', () {
    test('passes current filter to repo', () async {
      final repo = _FakeRepo(ApiSuccess([_user(1)]));
      final container = ProviderContainer(overrides: [
        staffRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      container.read(managerStaffFilterProvider.notifier).state =
          const ManagerStaffFilter(role: 'rider', status: 'active');

      final result = await container.read(managerStaffProvider.future);
      expect(result.length, 1);
      expect(repo.lastRole, 'rider');
      expect(repo.lastStatus, 'active');
    });

    test('refetches when filter changes', () async {
      final repo = _FakeRepo(ApiSuccess([_user(1)]));
      final container = ProviderContainer(overrides: [
        staffRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      await container.read(managerStaffProvider.future);
      expect(repo.lastRole, isNull);

      container.read(managerStaffFilterProvider.notifier).state =
          const ManagerStaffFilter(role: 'receiver');
      await container.read(managerStaffProvider.future);
      expect(repo.lastRole, 'receiver');
    });
  });
}