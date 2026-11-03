import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/models/delivery.dart';
import 'package:ods_app/data/repositories/delivery_repository.dart';
import 'package:ods_app/features/manager/presentation/providers/manager_packages_providers.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';

Delivery _pkg({int id = 1, int? hours}) => Delivery(
      id: id,
      trackingId: 'ODS-$id',
      distributorId: 42,
      serviceType: ServiceType.receive,
      status: DeliveryStatus.paid,
      rawStatus: 'paid',
      discountAmount: 0,
      currency: 'TZS',
      hoursAtBranch: hours,
    );

class _FakeRepo extends DeliveryRepository {
  _FakeRepo(this._result) : super(dio: Dio());
  final ApiResult<List<Delivery>> _result;

  @override
  Future<ApiResult<List<Delivery>>> listAtBranch() async => _result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  group('managerPackagesProvider', () {
    test('returns all packages when filter is "all"', () async {
      final repo = _FakeRepo(ApiSuccess([
        _pkg(id: 1, hours: 2),
        _pkg(id: 2, hours: 8),
        _pkg(id: 3, hours: 30),
      ]));
      final container = ProviderContainer(overrides: [
        deliveryRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(managerPackagesProvider.future);
      expect(result.length, 3);
    });

    test('filters to fresh when age filter is fresh', () async {
      final repo = _FakeRepo(ApiSuccess([
        _pkg(id: 1, hours: 2),
        _pkg(id: 2, hours: 8),
        _pkg(id: 3, hours: 30),
      ]));
      final container = ProviderContainer(overrides: [
        deliveryRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      container.read(packageAgeFilterProvider.notifier).state =
          PackageAgeFilter.fresh;

      final result = await container.read(managerPackagesProvider.future);
      expect(result.length, 1);
      expect(result.first.id, 1);
    });

    test('filters to aging (4-24h)', () async {
      final repo = _FakeRepo(ApiSuccess([
        _pkg(id: 1, hours: 2),
        _pkg(id: 2, hours: 8),
        _pkg(id: 3, hours: 24),
        _pkg(id: 4, hours: 30),
      ]));
      final container = ProviderContainer(overrides: [
        deliveryRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      container.read(packageAgeFilterProvider.notifier).state =
          PackageAgeFilter.aging;

      final result = await container.read(managerPackagesProvider.future);
      expect(result.length, 2);
      expect(result.map((d) => d.id), [2, 3]);
    });

    test('filters to stale (>24h)', () async {
      final repo = _FakeRepo(ApiSuccess([
        _pkg(id: 1, hours: 2),
        _pkg(id: 2, hours: 30),
        _pkg(id: 3, hours: 72),
      ]));
      final container = ProviderContainer(overrides: [
        deliveryRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      container.read(packageAgeFilterProvider.notifier).state =
          PackageAgeFilter.stale;

      final result = await container.read(managerPackagesProvider.future);
      expect(result.length, 2);
      expect(result.map((d) => d.id), [2, 3]);
    });

    test('excludes packages with null hoursAtBranch from age filters',
        () async {
      final repo = _FakeRepo(ApiSuccess([
        _pkg(id: 1, hours: 2),
        _pkg(id: 2, hours: null),
      ]));
      final container = ProviderContainer(overrides: [
        deliveryRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      container.read(packageAgeFilterProvider.notifier).state =
          PackageAgeFilter.fresh;

      final result = await container.read(managerPackagesProvider.future);
      expect(result.length, 1);
      expect(result.first.id, 1);
    });

    test('throws on repo failure', () async {
      final repo = _FakeRepo(ApiFailure(
        const Failure(type: FailureType.network, message: 'Offline'),
      ));
      final container = ProviderContainer(overrides: [
        deliveryRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      await expectLater(
        container.read(managerPackagesProvider.future),
        throwsA(isA<Failure>()),
      );
    });
  });
}