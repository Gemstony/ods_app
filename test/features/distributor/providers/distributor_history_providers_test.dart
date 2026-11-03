import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/models/delivery.dart';
import 'package:ods_app/data/repositories/delivery_repository.dart';
import 'package:ods_app/features/distributor/presentation/providers/distributor_history_providers.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';

Delivery _d({
  int id = 1,
  String trackingId = 'ODS-1',
  DeliveryStatus status = DeliveryStatus.paid,
  ServiceType serviceType = ServiceType.receive,
}) =>
    Delivery(
      id: id,
      trackingId: trackingId,
      distributorId: 42,
      serviceType: serviceType,
      status: status,
      rawStatus: status.name,
      discountAmount: 0,
      currency: 'TZS',
    );

class _FakeRepo extends DeliveryRepository {
  _FakeRepo(this._result) : super(dio: Dio());
  final ApiResult<List<Delivery>> _result;
  int listMineCalls = 0;

  @override
  Future<ApiResult<List<Delivery>>> listMine({
    DeliveryStatus? status,
    ServiceType? serviceType,
    int? limit,
    int? offset,
  }) async {
    listMineCalls++;
    return _result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  group('distributorHistoryProvider — status groups', () {
    test('all group returns everything', () async {
      final repo = _FakeRepo(ApiSuccess([
        _d(id: 1, status: DeliveryStatus.paid),
        _d(id: 2, status: DeliveryStatus.delivered),
        _d(id: 3, status: DeliveryStatus.cancelled),
      ]));
      final container = ProviderContainer(overrides: [
        deliveryRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(distributorHistoryProvider.future);
      expect(result.length, 3);
    });

    test('active group keeps only in-progress statuses', () async {
      final repo = _FakeRepo(ApiSuccess([
        _d(id: 1, status: DeliveryStatus.paid),
        _d(id: 2, status: DeliveryStatus.picked_up),
        _d(id: 3, status: DeliveryStatus.delivered),
        _d(id: 4, status: DeliveryStatus.cancelled),
        _d(id: 5, status: DeliveryStatus.pending_payment),
      ]));
      final container = ProviderContainer(overrides: [
        deliveryRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      container.read(distributorHistoryFilterProvider.notifier).state =
          const DistributorHistoryFilter(group: DistributorHistoryGroup.active);

      final result = await container.read(distributorHistoryProvider.future);
      expect(result.map((d) => d.id), [1, 2]);
    });

    test('delivered group keeps only delivered', () async {
      final repo = _FakeRepo(ApiSuccess([
        _d(id: 1, status: DeliveryStatus.paid),
        _d(id: 2, status: DeliveryStatus.delivered),
        _d(id: 3, status: DeliveryStatus.delivered),
      ]));
      final container = ProviderContainer(overrides: [
        deliveryRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      container.read(distributorHistoryFilterProvider.notifier).state =
          const DistributorHistoryFilter(
              group: DistributorHistoryGroup.delivered);

      final result = await container.read(distributorHistoryProvider.future);
      expect(result.map((d) => d.id), [2, 3]);
    });

    test('cancelled group keeps cancelled + failed + expired', () async {
      final repo = _FakeRepo(ApiSuccess([
        _d(id: 1, status: DeliveryStatus.cancelled),
        _d(id: 2, status: DeliveryStatus.failed),
        _d(id: 3, status: DeliveryStatus.expired),
        _d(id: 4, status: DeliveryStatus.delivered),
      ]));
      final container = ProviderContainer(overrides: [
        deliveryRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      container.read(distributorHistoryFilterProvider.notifier).state =
          const DistributorHistoryFilter(
              group: DistributorHistoryGroup.cancelled);

      final result = await container.read(distributorHistoryProvider.future);
      expect(result.map((d) => d.id), [1, 2, 3]);
    });
  });

  group('distributorHistoryProvider — service type', () {
    test('filters by receive', () async {
      final repo = _FakeRepo(ApiSuccess([
        _d(id: 1, serviceType: ServiceType.receive),
        _d(id: 2, serviceType: ServiceType.send),
        _d(id: 3, serviceType: ServiceType.regional),
      ]));
      final container = ProviderContainer(overrides: [
        deliveryRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      container.read(distributorHistoryFilterProvider.notifier).state =
          const DistributorHistoryFilter(serviceType: ServiceType.receive);

      final result = await container.read(distributorHistoryProvider.future);
      expect(result.map((d) => d.id), [1]);
    });
  });

  group('distributorHistoryProvider — search', () {
    test('search matches tracking ID case-insensitively', () async {
      final repo = _FakeRepo(ApiSuccess([
        _d(id: 1, trackingId: 'ODS-ABC-123'),
        _d(id: 2, trackingId: 'ODS-XYZ-456'),
      ]));
      final container = ProviderContainer(overrides: [
        deliveryRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      container.read(distributorHistoryFilterProvider.notifier).state =
          const DistributorHistoryFilter(search: 'abc');

      final result = await container.read(distributorHistoryProvider.future);
      expect(result.map((d) => d.id), [1]);
    });

    test('empty search returns all', () async {
      final repo = _FakeRepo(ApiSuccess([
        _d(id: 1),
        _d(id: 2),
      ]));
      final container = ProviderContainer(overrides: [
        deliveryRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      container.read(distributorHistoryFilterProvider.notifier).state =
          const DistributorHistoryFilter(search: '');

      final result = await container.read(distributorHistoryProvider.future);
      expect(result.length, 2);
    });
  });

  group('distributorHistoryProvider — combined filters', () {
    test('status + service type + search all apply together', () async {
      final repo = _FakeRepo(ApiSuccess([
        _d(id: 1, trackingId: 'ODS-A', status: DeliveryStatus.paid, serviceType: ServiceType.receive),
        _d(id: 2, trackingId: 'ODS-B', status: DeliveryStatus.paid, serviceType: ServiceType.send),
        _d(id: 3, trackingId: 'ODS-C', status: DeliveryStatus.delivered, serviceType: ServiceType.receive),
      ]));
      final container = ProviderContainer(overrides: [
        deliveryRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      container.read(distributorHistoryFilterProvider.notifier).state =
          const DistributorHistoryFilter(
        group: DistributorHistoryGroup.active,
        serviceType: ServiceType.receive,
        search: 'A',
      );

      final result = await container.read(distributorHistoryProvider.future);
      expect(result.map((d) => d.id), [1]);
    });
  });

  group('distributorHistoryProvider — failure', () {
    test('throws on repo error', () async {
      final repo = _FakeRepo(
        ApiFailure(const Failure(type: FailureType.network, message: 'Offline')),
      );
      final container = ProviderContainer(overrides: [
        deliveryRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      await expectLater(
        container.read(distributorHistoryProvider.future),
        throwsA(isA<Failure>()),
      );
    });
  });

  group('DistributorHistoryFilter equality', () {
    test('same fields are equal', () {
      expect(
        const DistributorHistoryFilter(group: DistributorHistoryGroup.active),
        const DistributorHistoryFilter(group: DistributorHistoryGroup.active),
      );
    });

    test('different fields are not equal', () {
      expect(
        const DistributorHistoryFilter(group: DistributorHistoryGroup.active),
        isNot(const DistributorHistoryFilter(group: DistributorHistoryGroup.all)),
      );
    });

    test('copyWith preserves untouched fields', () {
      const orig = DistributorHistoryFilter(
        group: DistributorHistoryGroup.active,
        serviceType: ServiceType.send,
      );
      final copy = orig.copyWith(search: 'x');
      expect(copy.group, DistributorHistoryGroup.active);
      expect(copy.serviceType, ServiceType.send);
      expect(copy.search, 'x');
    });
  });
}