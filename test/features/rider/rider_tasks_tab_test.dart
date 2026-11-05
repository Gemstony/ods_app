import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/delivery.dart';
import 'package:ods_app/data/repositories/delivery_repository.dart';
import 'package:ods_app/features/rider/presentation/screens/rider_tasks_tab.dart';
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
  DeliveryStatus status = DeliveryStatus.assigned,
  ServiceType serviceType = ServiceType.receive,
  String? recipientName,
  String? destinationAddress,
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
    recipientName: recipientName,
    destinationAddress: destinationAddress,
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
  );
}

class _FakeDeliveryRepo extends DeliveryRepository {
  _FakeDeliveryRepo({
    this.listResult,
    this.acceptResult,
    this.listCompleter,
  }) : super(dio: Dio());

  final ApiResult<List<Delivery>>? listResult;
  final ApiResult<Delivery>? acceptResult;
  final Completer<ApiResult<List<Delivery>>>? listCompleter;

  int listCallCount = 0;
  int acceptCallCount = 0;
  int? lastAcceptedId;

  @override
  Future<ApiResult<List<Delivery>>> listForRider({
    List<DeliveryStatus>? statuses,
    ServiceType? serviceType,
    int? perPage,
  }) {
    listCallCount++;
    if (listCompleter != null) return listCompleter!.future;
    return Future.value(
      listResult ?? const ApiSuccess<List<Delivery>>([]),
    );
  }

  @override
  Future<ApiResult<Delivery>> acceptRiderDelivery(int id) async {
    acceptCallCount++;
    lastAcceptedId = id;
    if (acceptResult == null) {
      throw StateError('acceptResult not stubbed');
    }
    return acceptResult!;
  }
}

Widget _wrap({required DeliveryRepository repo}) {
  return ProviderScope(
    overrides: [
      deliveryRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: RiderTasksTab()),
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
  testWidgets('shows no-tasks empty state when list is empty',
      (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeDeliveryRepo(
      listResult: const ApiSuccess<List<Delivery>>([]),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('No tasks yet'), findsOneWidget);
  });

  testWidgets('shows filter-empty state + clear button when filter excludes all',
      (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([
        _delivery(id: 1, status: DeliveryStatus.delivered),
      ]),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    // Filter to assigned — the only delivery is delivered → empty
    await tester.tap(find.widgetWithText(ChoiceChip, 'Assigned'));
    await tester.pumpAndSettle();

    expect(find.text('No tasks match your filter'), findsOneWidget);
    expect(find.text('Clear filters'), findsOneWidget);
  });

  testWidgets('clear filters restores the full list', (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([
        _delivery(id: 1, trackingId: 'ODS-DELIVERED', status: DeliveryStatus.delivered),
        _delivery(id: 2, trackingId: 'ODS-ASSIGNED', status: DeliveryStatus.assigned),
      ]),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Delivered'));
    await tester.pumpAndSettle();
    expect(find.text('ODS-DELIVERED'), findsOneWidget);
    expect(find.text('ODS-ASSIGNED'), findsNothing);

    // Clear by tapping the All chip (equivalent to the clear button)
    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.pumpAndSettle();
    expect(find.text('ODS-DELIVERED'), findsOneWidget);
    expect(find.text('ODS-ASSIGNED'), findsOneWidget);
  });

  // ─── Rendering ──────────────────────────────────────────
  testWidgets('renders all task cards', (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([
        _delivery(id: 1, trackingId: 'ODS-1', status: DeliveryStatus.assigned),
        _delivery(id: 2, trackingId: 'ODS-2', status: DeliveryStatus.accepted),
        _delivery(id: 3, trackingId: 'ODS-3', status: DeliveryStatus.delivered),
      ]),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('ODS-1'), findsOneWidget);
    expect(find.text('ODS-2'), findsOneWidget);
    expect(find.text('ODS-3'), findsOneWidget);
  });

  // ─── Accept button visibility ───────────────────────────
  testWidgets('Accept button renders only on assigned deliveries',
      (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([
        _delivery(id: 1, trackingId: 'ODS-1', status: DeliveryStatus.assigned),
        _delivery(id: 2, trackingId: 'ODS-2', status: DeliveryStatus.accepted),
        _delivery(id: 3, trackingId: 'ODS-3', status: DeliveryStatus.picked_up),
      ]),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    // Exactly one Accept button (on the assigned delivery)
    expect(find.widgetWithText(TextButton, 'Accept'), findsOneWidget);
  });

  // ─── Accept flow ────────────────────────────────────────
  testWidgets('tapping Accept shows confirmation dialog', (tester) async {
    _useLargeViewport(tester);
    final assigned = _delivery(
      id: 7,
      trackingId: 'ODS-ACCEPT',
      status: DeliveryStatus.assigned,
    );
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([assigned]),
      acceptResult: ApiSuccess(assigned),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Accept'));
    await tester.pumpAndSettle();

    expect(find.text('Accept this task?'), findsOneWidget);
    expect(find.textContaining('ODS-ACCEPT'), findsWidgets);
  });

  testWidgets('Cancel in dialog does not call accept API', (tester) async {
    _useLargeViewport(tester);
    final assigned = _delivery(id: 7, status: DeliveryStatus.assigned);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([assigned]),
      acceptResult: ApiSuccess(assigned),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Accept'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(repo.acceptCallCount, 0);
  });

  testWidgets('confirming dialog calls accept API + shows snackbar',
      (tester) async {
    _useLargeViewport(tester);
    final assigned = _delivery(
      id: 7,
      trackingId: 'ODS-ACCEPT',
      status: DeliveryStatus.assigned,
    );
    final accepted = _delivery(
      id: 7,
      trackingId: 'ODS-ACCEPT',
      status: DeliveryStatus.accepted,
    );
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([assigned]),
      acceptResult: ApiSuccess(accepted),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Accept'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Accept'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.acceptCallCount, 1);
    expect(repo.lastAcceptedId, 7);
    expect(find.textContaining('Task accepted'), findsOneWidget);
  });

  testWidgets('accept API failure shows error snackbar', (tester) async {
    _useLargeViewport(tester);
    final assigned = _delivery(id: 7, status: DeliveryStatus.assigned);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([assigned]),
      acceptResult: const ApiFailure(
        Failure(type: FailureType.validation, message: 'Task already accepted'),
      ),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Accept'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Accept'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.acceptCallCount, 1);
    expect(find.text('Task already accepted'), findsOneWidget);
  });

  // ─── Filter interactions ────────────────────────────────
  testWidgets('status filter chip narrows the list', (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([
        _delivery(id: 1, trackingId: 'ODS-ASSIGNED', status: DeliveryStatus.assigned),
        _delivery(id: 2, trackingId: 'ODS-DELIVERED', status: DeliveryStatus.delivered),
      ]),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Assigned'));
    await tester.pumpAndSettle();

    expect(find.text('ODS-ASSIGNED'), findsOneWidget);
    expect(find.text('ODS-DELIVERED'), findsNothing);
  });
}