import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/models/distributor_dashboard_kpis.dart';
import 'package:ods_app/data/models/reward.dart';
import 'package:ods_app/data/repositories/reward_repository.dart';
import 'package:ods_app/features/distributor/presentation/providers/distributor_rewards_providers.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';

DistributorRewardKpis _overview({
  int monthly = 5,
  int rolling = 45,
  bool tier1Available = false,
}) {
  return DistributorRewardKpis(
    progress: Reward(
      id: 1,
      distributorId: 42,
      currentMonth: '2026-11',
      monthlyCount: monthly,
      tier1Available: tier1Available,
      rollingCount: rolling,
      tier2Available: false,
    ),
    tier1Threshold: 20,
    tier2Threshold: 50,
    tier1DiscountPercent: 50,
  );
}

class _FakeRepo extends RewardRepository {
  _FakeRepo(this._result) : super(dio: Dio());
  final ApiResult<DistributorRewardKpis> _result;

  @override
  Future<ApiResult<DistributorRewardKpis>> getMyOverview() async => _result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  test('returns overview on success', () async {
    final container = ProviderContainer(overrides: [
      rewardRepositoryProvider.overrideWithValue(_FakeRepo(
        ApiSuccess(_overview(monthly: 8, rolling: 30)),
      )),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(distributorRewardsProvider.future);
    expect(result.progress.monthlyCount, 8);
    expect(result.progress.rollingCount, 30);
    expect(result.tier1Threshold, 20);
  });

  test('throws Failure on repo failure', () async {
    final container = ProviderContainer(overrides: [
      rewardRepositoryProvider.overrideWithValue(_FakeRepo(
        ApiFailure(const Failure(type: FailureType.network, message: 'Offline')),
      )),
    ]);
    addTearDown(container.dispose);

    await expectLater(
      container.read(distributorRewardsProvider.future),
      throwsA(isA<Failure>()),
    );
  });
}