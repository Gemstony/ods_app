import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/models/delivery.dart';
import 'package:ods_app/data/repositories/delivery_repository.dart';
import 'package:ods_app/features/manager/presentation/providers/manager_delivery_providers.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';

Delivery _delivery({int id = 1, String trackingId = 'ODS-1'}) => Delivery(
      id: id,
      trackingId: trackingId,
      distributorId: 42,
      serviceType: ServiceType.receive,
      status: DeliveryStatus.paid,
      rawStatus: 'paid',
      discountAmount: 0,
      currency: 'TZS',
    );

class _FakeRepo extends DeliveryRepository {
  _FakeRepo(this._result) : super(dio: Dio());
  final ApiResult<List<Delivery>> _result;
  List<DeliveryStatus>? lastStatuses;
  ServiceType? lastServiceType;

  @override
  Future<ApiResult<List<Delivery>>> listForBranch({
    List<DeliveryStatus>? statuses,
    ServiceType? serviceType,
    int? perPage,
    int page = 1,
  }) async {
    lastStatuses = statuses;
    lastServiceType = serviceType;
    return _result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  group('ManagerDeliveriesFilter', () {
    test('copyWith preserves untouched fields', () {
      const orig = ManagerDeliveriesFilter(
        statuses: [DeliveryStatus.paid],
      );
      final copy = orig.copyWith(search: 'x');
      expect(copy.statuses, [DeliveryStatus.paid]);
      expect(copy.search, 'x');
    });
  });

  group('managerDeliveriesProvider', () {
    test('passes statuses list to repo', () async {
      final repo = _FakeRepo(ApiSuccess([_delivery()]));
      final container = ProviderContainer(overrides: [
        deliveryRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      container.read(managerDeliveriesFilterProvider.notifier).state =
          const ManagerDeliveriesFilter(
        statuses: [DeliveryStatus.picked_up, DeliveryStatus.dispatched],
      );

      final result = await container.read(managerDeliveriesProvider.future);
      expect(result.length, 1);
      expect(repo.lastStatuses,
          [DeliveryStatus.picked_up, DeliveryStatus.dispatched]);
    });

    test('applies client-side search on tracking ID', () async {
      final repo = _FakeRepo(ApiSuccess([
        _delivery(id: 1, trackingId: 'ODS-ALPHA'),
        _delivery(id: 2, trackingId: 'ODS-BETA'),
      ]));
      final container = ProviderContainer(overrides: [
        deliveryRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      container.read(managerDeliveriesFilterProvider.notifier).state =
          const ManagerDeliveriesFilter(search: 'ALPHA');

      final result = await container.read(managerDeliveriesProvider.future);
      expect(result.length, 1);
      expect(result.first.trackingId, 'ODS-ALPHA');
    });

    test('throws failure on repo error', () async {
      final repo = _FakeRepo(ApiFailure(
        const Failure(type: FailureType.network, message: 'Offline'),
      ));
      final container = ProviderContainer(overrides: [
        deliveryRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      await expectLater(
        container.read(managerDeliveriesProvider.future),
        throwsA(isA<Failure>()),
      );
    });
  });
}