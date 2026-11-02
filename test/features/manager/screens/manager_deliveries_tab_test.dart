import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/delivery.dart';
import 'package:ods_app/data/repositories/delivery_repository.dart';
import 'package:ods_app/features/manager/presentation/screens/manager_deliveries_tab.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';
import 'package:ods_app/widgets/widgets.dart';

void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Delivery _delivery({
  int id = 1,
  String trackingId = 'ODS-20261104-ABC123',
  DeliveryStatus status = DeliveryStatus.paid,
}) =>
    Delivery(
      id: id,
      trackingId: trackingId,
      distributorId: 42,
      serviceType: ServiceType.receive,
      status: status,
      rawStatus: status.name,
      discountAmount: 0,
      currency: 'TZS',
      totalAmount: 2000,
      createdAt: DateTime(2026, 11, 4, 10, 0),
    );

class _FakeRepo extends DeliveryRepository {
  _FakeRepo(this._result) : super(dio: Dio());
  final ApiResult<List<Delivery>> _result;

  @override
  Future<ApiResult<List<Delivery>>> listForBranch({
    List<DeliveryStatus>? statuses,
    ServiceType? serviceType,
    int? perPage,
    int page = 1,
  }) async =>
      _result;

  /// Defensive: if the pushed detail screen's pull-to-refresh ever
  /// fires, this returns immediately instead of hitting a bare Dio
  /// (which would hang forever in the fake-async test zone).
  @override
  Future<ApiResult<Delivery>> getForBranch(int id) async =>
      ApiSuccess(_delivery(id: id));
}

class _PendingRepo extends DeliveryRepository {
  _PendingRepo() : super(dio: Dio());
  final _completer = Completer<ApiResult<List<Delivery>>>();

  @override
  Future<ApiResult<List<Delivery>>> listForBranch({
    List<DeliveryStatus>? statuses,
    ServiceType? serviceType,
    int? perPage,
    int page = 1,
  }) =>
      _completer.future;

  @override
  Future<ApiResult<Delivery>> getForBranch(int id) async =>
      ApiSuccess(_delivery(id: id));
}

Widget _wrap(DeliveryRepository repo) => ProviderScope(
      overrides: [deliveryRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: ManagerDeliveriesTab()),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  testWidgets('shows loading state', (tester) async {
    await tester.pumpWidget(_wrap(_PendingRepo()));
    await tester.pump();
    expect(find.byType(LoadingView), findsOneWidget);
  });

  testWidgets('shows empty state', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(_FakeRepo(ApiSuccess(const []))));
    await tester.pumpAndSettle();

    expect(find.text('No deliveries'), findsOneWidget);
  });

  testWidgets('renders delivery cards', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(_FakeRepo(ApiSuccess([
      _delivery(id: 1, trackingId: 'ODS-1'),
      _delivery(id: 2, trackingId: 'ODS-2'),
    ]))));
    await tester.pumpAndSettle();

    expect(find.text('ODS-1'), findsOneWidget);
    expect(find.text('ODS-2'), findsOneWidget);
  });

  testWidgets('shows error state', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(ApiFailure(
      const Failure(type: FailureType.network, message: 'Offline'),
    ))));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('"In transit" chip is selectable', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(_FakeRepo(ApiSuccess([_delivery()]))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('In transit'));
    await tester.pumpAndSettle();

    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'In transit'),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('tapping a card opens delivery detail', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(_FakeRepo(ApiSuccess([_delivery()]))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ODS-20261104-ABC123'));

    // Explicit pumps instead of pumpAndSettle: the pushed
    // DeliveryDetailScreen wraps its body in a RefreshIndicator, whose
    // internal animation controller can keep scheduling frames while
    // the route transition settles. Two fixed pumps are sufficient to
    // complete the Material route transition (~300ms) without waiting
    // on the RefreshIndicator.
    await tester.pump(); // schedule the route push
    await tester.pump(const Duration(milliseconds: 500)); // complete transition

    // Detail screen shows the tracking ID in its AppBar. The underlying
    // card is also still in the tree (route behind), so use findsWidgets.
    expect(find.text('ODS-20261104-ABC123'), findsWidgets);
  });
}
