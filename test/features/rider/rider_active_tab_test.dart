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
import 'package:ods_app/features/rider/presentation/screens/rider_active_tab.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';
import 'package:ods_app/widgets/widgets.dart';

void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Delivery _delivery({
  int id = 1,
  String trackingId = 'ODS-TEST-1',
  DeliveryStatus status = DeliveryStatus.accepted,
  ServiceType serviceType = ServiceType.receive,
  String? pickupAddress,
  String? destinationAddress,
  String? recipientName,
  String? recipientPhone,
}) {
  return Delivery(
    id: id,
    trackingId: trackingId,
    distributorId: 42,
    serviceType: serviceType,
    status: status,
    rawStatus: status.name,
    discountAmount: 0,
    currency: 'TZS',
    totalAmount: 5000,
    pickupAddress: pickupAddress,
    destinationAddress: destinationAddress,
    recipientName: recipientName,
    recipientPhone: recipientPhone,
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
  );
}

class _FakeDeliveryRepo extends DeliveryRepository {
  _FakeDeliveryRepo({
    this.listResult,
    this.pickupResult,
    this.deliverResult,
    this.listCompleter,
  }) : super(dio: Dio());

  final ApiResult<List<Delivery>>? listResult;
  final ApiResult<Delivery>? pickupResult;
  final ApiResult<Delivery>? deliverResult;
  final Completer<ApiResult<List<Delivery>>>? listCompleter;

  int pickupCallCount = 0;
  int deliverCallCount = 0;
  int? lastPickupId;
  int? lastDeliverId;

  @override
  Future<ApiResult<List<Delivery>>> listForRider({
    List<DeliveryStatus>? statuses,
    ServiceType? serviceType,
    int? perPage,
  }) {
    if (listCompleter != null) return listCompleter!.future;
    return Future.value(
      listResult ?? const ApiSuccess<List<Delivery>>([]),
    );
  }

  @override
  Future<ApiResult<Delivery>> pickupRiderDelivery(int id) async {
    pickupCallCount++;
    lastPickupId = id;
    if (pickupResult == null) {
      throw StateError('pickupResult not stubbed');
    }
    return pickupResult!;
  }

  @override
  Future<ApiResult<Delivery>> deliverRiderDelivery(int id) async {
    deliverCallCount++;
    lastDeliverId = id;
    if (deliverResult == null) {
      throw StateError('deliverResult not stubbed');
    }
    return deliverResult!;
  }
}

Widget _wrap({required DeliveryRepository repo}) {
  return ProviderScope(
    overrides: [
      deliveryRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: RiderActiveTab()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  // ─── Loading / error ────────────────────────────────────
  testWidgets('shows loading state', (tester) async {
    final completer = Completer<ApiResult<List<Delivery>>>();
    final repo = _FakeDeliveryRepo(listCompleter: completer);

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pump();

    expect(find.byType(LoadingView), findsOneWidget);
  });

  testWidgets('shows error state with retry', (tester) async {
    final repo = _FakeDeliveryRepo(
      listResult: const ApiFailure(
        Failure(type: FailureType.network, message: 'Offline'),
      ),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  // ─── Empty states ───────────────────────────────────────
  testWidgets('shows empty state when no active deliveries',
      (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeDeliveryRepo(
      listResult: const ApiSuccess<List<Delivery>>([]),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('No active deliveries'), findsOneWidget);
    expect(find.textContaining('Accept a task from the Tasks tab'),
        findsOneWidget);
  });

  testWidgets('hides non-active deliveries (assigned / delivered)',
      (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([
        _delivery(id: 1, trackingId: 'ODS-ASSIGNED', status: DeliveryStatus.assigned),
        _delivery(id: 2, trackingId: 'ODS-ACCEPTED', status: DeliveryStatus.accepted),
        _delivery(id: 3, trackingId: 'ODS-DELIVERED', status: DeliveryStatus.delivered),
      ]),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('ODS-ACCEPTED'), findsOneWidget);
    expect(find.text('ODS-ASSIGNED'), findsNothing);
    expect(find.text('ODS-DELIVERED'), findsNothing);
  });

  // ─── Rendering by status ────────────────────────────────
  testWidgets('accepted delivery shows "Pickup package" CTA',
      (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([
        _delivery(
          id: 1,
          trackingId: 'ODS-ACC',
          status: DeliveryStatus.accepted,
          pickupAddress: 'Kariakoo Branch',
          destinationAddress: '456 Upanga',
        ),
      ]),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('ODS-ACC'), findsOneWidget);
    expect(find.text('Pickup package'), findsOneWidget);
    expect(find.text('Confirm delivery'), findsNothing);
    expect(find.text('Kariakoo Branch'), findsOneWidget);
    expect(find.text('456 Upanga'), findsOneWidget);
  });

  testWidgets('picked_up delivery shows "Confirm delivery" CTA',
      (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([
        _delivery(
          id: 1,
          trackingId: 'ODS-PICK',
          status: DeliveryStatus.picked_up,
        ),
      ]),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('ODS-PICK'), findsOneWidget);
    expect(find.text('Confirm delivery'), findsOneWidget);
    expect(find.text('Pickup package'), findsNothing);
  });

  testWidgets('renders recipient name and phone', (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([
        _delivery(
          id: 1,
          status: DeliveryStatus.accepted,
          recipientName: 'Jane Customer',
          recipientPhone: '0712345678',
        ),
      ]),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Jane Customer'), findsOneWidget);
    expect(find.text('0712345678'), findsOneWidget);
  });

  // ─── Pickup flow ────────────────────────────────────────
  testWidgets('tapping Pickup shows confirmation dialog', (tester) async {
    _useLargeViewport(tester);
    final accepted = _delivery(
      id: 7,
      trackingId: 'ODS-PICKUP',
      status: DeliveryStatus.accepted,
    );
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([accepted]),
      pickupResult: ApiSuccess(accepted),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pickup package'));
    await tester.pumpAndSettle();

    expect(find.text('Pickup package?'), findsOneWidget);
    expect(find.textContaining('ODS-PICKUP'), findsWidgets);
  });

  testWidgets('Cancel in pickup dialog does not call API', (tester) async {
    _useLargeViewport(tester);
    final accepted = _delivery(id: 7, status: DeliveryStatus.accepted);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([accepted]),
      pickupResult: ApiSuccess(accepted),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pickup package'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(repo.pickupCallCount, 0);
  });

  testWidgets('confirming pickup calls API + shows snackbar',
      (tester) async {
    _useLargeViewport(tester);
    final accepted = _delivery(
      id: 7,
      trackingId: 'ODS-PICKUP',
      status: DeliveryStatus.accepted,
    );
    final picked = _delivery(
      id: 7,
      trackingId: 'ODS-PICKUP',
      status: DeliveryStatus.picked_up,
    );
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([accepted]),
      pickupResult: ApiSuccess(picked),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pickup package'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Pickup'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.pickupCallCount, 1);
    expect(repo.lastPickupId, 7);
    expect(find.textContaining('Package picked up'), findsOneWidget);
  });

  testWidgets('pickup API failure shows error snackbar', (tester) async {
    _useLargeViewport(tester);
    final accepted = _delivery(id: 7, status: DeliveryStatus.accepted);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([accepted]),
      pickupResult: const ApiFailure(
        Failure(type: FailureType.validation, message: 'Already picked up'),
      ),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pickup package'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Pickup'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.pickupCallCount, 1);
    expect(find.text('Already picked up'), findsOneWidget);
  });

  // ─── Deliver flow ───────────────────────────────────────
  testWidgets('tapping Confirm delivery shows dialog', (tester) async {
    _useLargeViewport(tester);
    final picked = _delivery(
      id: 9,
      trackingId: 'ODS-DELIVER',
      status: DeliveryStatus.picked_up,
    );
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([picked]),
      deliverResult: ApiSuccess(picked),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm delivery'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm delivery?'), findsOneWidget);
    expect(find.textContaining('ODS-DELIVER'), findsWidgets);
  });

  testWidgets('Cancel in deliver dialog does not call API', (tester) async {
    _useLargeViewport(tester);
    final picked = _delivery(id: 9, status: DeliveryStatus.picked_up);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([picked]),
      deliverResult: ApiSuccess(picked),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm delivery'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(repo.deliverCallCount, 0);
  });

  testWidgets('confirming deliver calls API + shows snackbar',
      (tester) async {
    _useLargeViewport(tester);
    final picked = _delivery(
      id: 9,
      trackingId: 'ODS-DELIVER',
      status: DeliveryStatus.picked_up,
    );
    final delivered = _delivery(
      id: 9,
      trackingId: 'ODS-DELIVER',
      status: DeliveryStatus.delivered,
    );
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([picked]),
      deliverResult: ApiSuccess(delivered),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm delivery'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.deliverCallCount, 1);
    expect(repo.lastDeliverId, 9);
    expect(find.textContaining('Delivery completed'), findsOneWidget);
  });

  testWidgets('deliver API failure shows error snackbar', (tester) async {
    _useLargeViewport(tester);
    final picked = _delivery(id: 9, status: DeliveryStatus.picked_up);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([picked]),
      deliverResult: const ApiFailure(
        Failure(type: FailureType.validation, message: 'Delivery not in picked_up state'),
      ),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm delivery'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.deliverCallCount, 1);
    expect(find.text('Delivery not in picked_up state'), findsOneWidget);
  });

  // ─── Mixed statuses ─────────────────────────────────────
  testWidgets('renders mixed accepted + picked_up deliveries',
      (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([
        _delivery(id: 1, trackingId: 'ODS-ACC-1', status: DeliveryStatus.accepted),
        _delivery(id: 2, trackingId: 'ODS-PICK-2', status: DeliveryStatus.picked_up),
      ]),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('ODS-ACC-1'), findsOneWidget);
    expect(find.text('ODS-PICK-2'), findsOneWidget);
    expect(find.text('Pickup package'), findsOneWidget);
    expect(find.text('Confirm delivery'), findsOneWidget);
  });
}