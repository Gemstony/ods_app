import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/models/branch.dart';
import 'package:ods_app/data/repositories/branch_repository.dart';
import 'package:ods_app/features/manager/presentation/providers/manager_branch_providers.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';

Branch _branch() => const Branch(
      id: 5,
      name: 'Kariakoo Branch',
      code: 'KRK-01',
      address: '123 Kariakoo',
      latitude: -6.79,
      longitude: 39.20,
      status: BranchStatus.active,
    );

class _FakeRepo extends BranchRepository {
  _FakeRepo(this._result) : super(dio: Dio());
  final ApiResult<Branch> _result;

  @override
  Future<ApiResult<Branch>> getMyBranch() async => _result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  test('managerBranchProvider returns branch', () async {
    final container = ProviderContainer(overrides: [
      branchRepositoryProvider
          .overrideWithValue(_FakeRepo(ApiSuccess(_branch()))),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(managerBranchProvider.future);
    expect(result.id, 5);
    expect(result.name, 'Kariakoo Branch');
  });

  test('managerBranchProvider throws on failure', () async {
    final container = ProviderContainer(overrides: [
      branchRepositoryProvider.overrideWithValue(
        _FakeRepo(
          ApiFailure(const Failure(
            type: FailureType.auth,
            message: 'Not assigned to a branch',
          )),
        ),
      ),
    ]);
    addTearDown(container.dispose);

    await expectLater(
      container.read(managerBranchProvider.future),
      throwsA(isA<Failure>()),
    );
  });
}