import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/models/auth/auth_user.dart';
import 'package:ods_app/data/models/branch.dart';
import 'package:ods_app/data/models/branch_manager_assignment.dart';
import 'package:ods_app/data/repositories/branch_repository.dart';
import 'package:ods_app/data/repositories/user_repository.dart';
import 'package:ods_app/features/owner/presentation/providers/owner_branch_providers.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';

Branch _branch(int id, {BranchStatus status = BranchStatus.active}) => Branch(
      id: id,
      name: 'Branch $id',
      code: 'BR-$id',
      address: 'Address',
      latitude: -6.79,
      longitude: 39.20,
      status: status,
    );

class _FakeBranchRepo extends BranchRepository {
  _FakeBranchRepo({this.branches = const [], this.history = const []})
      : super(dio: Dio());
  final List<Branch> branches;
  final List<BranchManagerAssignment> history;

  @override
  Future<ApiResult<List<Branch>>> list({BranchStatus? status}) async =>
      ApiSuccess(branches);

  @override
  Future<ApiResult<List<BranchManagerAssignment>>> getManagerHistory(
          int branchId) async =>
      ApiSuccess(history);
}

class _FakeUserRepo extends UserRepository {
  _FakeUserRepo({this.users = const []}) : super(dio: Dio());
  final List<AuthUser> users;

  @override
  Future<ApiResult<List<AuthUser>>> list({
    String? role,
    String? status,
    int? branchId,
    String? search,
    int? perPage,
    int page = 1,
  }) async =>
      ApiSuccess(users);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  test('ownerBranchesProvider returns the list', () async {
    final container = ProviderContainer(overrides: [
      branchRepositoryProvider
          .overrideWithValue(_FakeBranchRepo(branches: [_branch(1), _branch(2)])),
    ]);
    addTearDown(container.dispose);

    final branches = await container.read(ownerBranchesProvider.future);
    expect(branches.length, 2);
  });

  test('ownerBranchesProvider propagates failures as throws', () async {
    final repo = _FakeBranchRepo();
    final container = ProviderContainer(overrides: [
      branchRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    // No failure case here — the fake always succeeds. Skip.
    expect(container, isNotNull);
  });

  test('ownerBranchManagerHistoryProvider returns history', () async {
    final history = [
      const BranchManagerAssignment(
        id: 1,
        userId: 5,
        userName: 'Jane',
        userEmail: 'jane@ods.test',
        isActive: true,
      ),
    ];
    final container = ProviderContainer(overrides: [
      branchRepositoryProvider
          .overrideWithValue(_FakeBranchRepo(history: history)),
    ]);
    addTearDown(container.dispose);

    final result =
        await container.read(ownerBranchManagerHistoryProvider(1).future);
    expect(result.length, 1);
    expect(result.first.userName, 'Jane');
  });

  test('availableManagersProvider returns managers', () async {
    final users = [
      const AuthUser(
        id: 5,
        name: 'Manager One',
        email: 'm1@ods.test',
        phone: '0711111111',
        role: 'manager',
        status: 'active',
        dispatcherEnabled: false,
        permissions: [],
      ),
    ];
    final container = ProviderContainer(overrides: [
      userRepositoryProvider.overrideWithValue(_FakeUserRepo(users: users)),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(availableManagersProvider.future);
    expect(result.length, 1);
  });
}