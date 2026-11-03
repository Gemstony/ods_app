import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/models/distributor_dashboard_kpis.dart';
import 'package:ods_app/data/repositories/dashboard_repository.dart';
import 'package:ods_app/features/distributor/presentation/providers/distributor_dashboard_providers.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';

class _FakeRepo extends DashboardRepository {
  _FakeRepo(this._result) : super(dio: Dio());
  final ApiResult<DistributorDashboardKpis> _result;

  @override
  Future<ApiResult<DistributorDashboardKpis>> getDistributorKpis() async =>
      _result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  test('returns KPIs on success', () async {
    final container = ProviderContainer(overrides: [
      dashboardRepositoryProvider
          .overrideWithValue(_FakeRepo(ApiSuccess(DistributorDashboardKpis.empty()))),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(distributorDashboardProvider.future);
    expect(result.deliveries.activeCount, 0);
  });

  test('throws on failure', () async {
    final container = ProviderContainer(overrides: [
      dashboardRepositoryProvider.overrideWithValue(
        _FakeRepo(ApiFailure(const Failure(
          type: FailureType.network,
          message: 'Offline',
        ))),
      ),
    ]);
    addTearDown(container.dispose);

    await expectLater(
      container.read(distributorDashboardProvider.future),
      throwsA(isA<Failure>()),
    );
  });
}