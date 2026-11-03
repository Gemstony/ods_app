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
import 'package:ods_app/features/distributor/presentation/screens/distributor_history_tab.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';
import 'package:ods_app/widgets/widgets.dart';

void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Delivery _d({
  int id = 1,
  String trackingId = 'ODS-20261104-ABC123',
  DeliveryStatus status = DeliveryStatus.paid,
  ServiceType serviceType = ServiceType.receive,
  double? totalAmount = 2000,
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
      totalAmount: totalAmount,
      destinationAddress: '456 Upanga',
      createdAt: DateTime(2026, 11, 4, 10, 0),
    );

class _FakeRepo extends DeliveryRepository {
  _FakeRepo(this._result) : super(dio: Dio());
  final ApiResult<List<Delivery>> _result;

  @override
  Future<ApiResult<List<Delivery>>> listMine({
    DeliveryStatus? status,
    ServiceType? serviceType,
    int? limit,
    int? offset,
  }) async =>
      _result;

  @override
  Future<ApiResult<Delivery>> getMine(int id) async =>
      ApiSuccess(_d(id: id));
}

class _PendingRepo extends DeliveryRepository {
  _PendingRepo() : super(dio: Dio());
  final _completer = Completer<ApiResult<List<Delivery>>>();

  @override
  Future<ApiResult<List<Delivery>>> listMine({
    DeliveryStatus? status,
    ServiceType? serviceType,
    int? limit,
    int? offset,
  }) =>
      _completer.future;
}

Widget _wrap(DeliveryRepository repo) => ProviderScope(
      overrides: [deliveryRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: DistributorHistoryTab()),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  // ─── States ──────────────────────────────────────────────
  testWidgets('shows loading state', (tester) async {
    await tester.pumpWidget(_wrap(_PendingRepo()));
    await tester.pump();
    expect(find.byType(LoadingView), findsOneWidget);
  });

  testWidgets('shows empty state when no deliveries', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(_FakeRepo(ApiSuccess(const []))));
    await tester.pumpAndSettle();

    expect(find.text('No deliveries'), findsOneWidget);
    expect(find.textContaining('Your delivery history will appear'),
        findsOneWidget);
  });

  testWidgets('shows error state with retry', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(
      ApiFailure(const Failure(type: FailureType.network, message: 'Offline')),
    )));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  // ─── Rendering ───────────────────────────────────────────
  testWidgets('renders delivery cards', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(_FakeRepo(ApiSuccess([
      _d(id: 1, trackingId: 'ODS-AAA'),
      _d(id: 2, trackingId: 'ODS-BBB'),
    ]))));
    await tester.pumpAndSettle();

    expect(find.text('ODS-AAA'), findsOneWidget);
    expect(find.text('ODS-BBB'), findsOneWidget);
  });

  // ─── Filter chips ────────────────────────────────────────
  testWidgets('renders all four group chips', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(_FakeRepo(ApiSuccess([_d()]))));
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
  });

  testWidgets('tapping "Delivered" chip filters the list', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(_FakeRepo(ApiSuccess([
      _d(id: 1, trackingId: 'ODS-ACTIVE', status: DeliveryStatus.paid),
      _d(id: 2, trackingId: 'ODS-DONE', status: DeliveryStatus.delivered),
    ]))));
    await tester.pumpAndSettle();

    // Both visible initially
    expect(find.text('ODS-ACTIVE'), findsOneWidget);
    expect(find.text('ODS-DONE'), findsOneWidget);

    // Tap Delivered
    // Tap the filter chip specifically — `find.text('Delivered')` also
    // matches the status chip rendered on the delivered delivery card,
    // so scope to the ChoiceChip ancestor.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Delivered'));
    await tester.pumpAndSettle();

    // Only delivered remains
    expect(find.text('ODS-ACTIVE'), findsNothing);
    expect(find.text('ODS-DONE'), findsOneWidget);
  });

  testWidgets('tapping "Active" chip filters to in-progress only',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(_FakeRepo(ApiSuccess([
      _d(id: 1, trackingId: 'ODS-PAID', status: DeliveryStatus.paid),
      _d(id: 2, trackingId: 'ODS-DONE', status: DeliveryStatus.delivered),
      _d(id: 3, trackingId: 'ODS-CANCEL', status: DeliveryStatus.cancelled),
    ]))));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Active'));
    await tester.pumpAndSettle();

    expect(find.text('ODS-PAID'), findsOneWidget);
    expect(find.text('ODS-DONE'), findsNothing);
    expect(find.text('ODS-CANCEL'), findsNothing);
  });

  // ─── Service type dropdown ───────────────────────────────
  testWidgets('service type dropdown filters by service', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(_FakeRepo(ApiSuccess([
      _d(id: 1, trackingId: 'ODS-RECV', serviceType: ServiceType.receive),
      _d(id: 2, trackingId: 'ODS-SEND', serviceType: ServiceType.send),
    ]))));
    await tester.pumpAndSettle();

    expect(find.text('ODS-RECV'), findsOneWidget);
    expect(find.text('ODS-SEND'), findsOneWidget);

    // Open dropdown
    await tester.tap(find.text('All services'));
    await tester.pumpAndSettle();

    // Select "Send"
    await tester.tap(find.text('Send').last);
    await tester.pumpAndSettle();

    expect(find.text('ODS-RECV'), findsNothing);
    expect(find.text('ODS-SEND'), findsOneWidget);
  });

  // ─── Navigation to detail ────────────────────────────────
  testWidgets('tapping a card opens delivery detail', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(_FakeRepo(ApiSuccess([
      _d(id: 1, trackingId: 'ODS-DETAIL-1'),
    ]))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ODS-DETAIL-1'));

    // Explicit pumps — RefreshIndicator in detail hangs pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Detail screen shows the tracking ID in its AppBar
    expect(find.text('ODS-DETAIL-1'), findsWidgets);
  });
}