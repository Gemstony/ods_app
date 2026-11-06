import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/auth/auth_user.dart';
import 'package:ods_app/data/models/delivery.dart';
import 'package:ods_app/data/models/dispatcher_ticket.dart';
import 'package:ods_app/data/repositories/delivery_repository.dart';
import 'package:ods_app/features/receiver/presentation/screens/receiver_regional_tab.dart';
import 'package:ods_app/shared/providers/auth_provider.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';
import 'package:ods_app/widgets/widgets.dart';

void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

AuthUser _dispatcherUser({bool enabled = true}) {
  return AuthUser(
    id: 42,
    name: 'Test Receiver',
    email: 'r@ods.test',
    phone: '0712345678',
    role: 'receiver',
    status: 'active',
    dispatcherEnabled: enabled,
    permissions: const [],
  );
}

DispatcherTicket _ticket({
  int id = 100,
  int deliveryId = 7,
  String providerName = 'Kilimanjaro Express',
  String providerType = 'bus',
  String ticketNumber = 'TKT-1234',
  String routeFrom = 'Dar es Salaam',
  String routeTo = 'Arusha',
  double transportFare = 3500,
}) {
  return DispatcherTicket(
    id: id,
    deliveryId: deliveryId,
    dispatcherId: 42,
    providerName: providerName,
    providerType: providerType,
    ticketNumber: ticketNumber,
    routeFrom: routeFrom,
    routeTo: routeTo,
    transportFare: transportFare,
    currency: 'TZS',
    issuedAt: DateTime.now(),
  );
}

Delivery _regional({
  int id = 1,
  String trackingId = 'ODS-REG-1',
  DeliveryStatus status = DeliveryStatus.batched,
  String? recipientName,
  String? region,
  String? district,
  String? busStop,
  double? busFare,
  DispatcherTicket? ticket,
}) {
  return Delivery(
    id: id,
    trackingId: trackingId,
    distributorId: 42,
    serviceType: ServiceType.regional,
    status: status,
    rawStatus: status.name,
    discountAmount: 0,
    currency: 'TZS',
    totalAmount: 5000,
    recipientName: recipientName,
    destinationRegion: region,
    destinationDistrict: district,
    destinationBusStop: busStop,
    busCargoFare: busFare,
    dispatcherTicket: ticket,
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
  );
}

class _FakeDeliveryRepo extends DeliveryRepository {
  _FakeDeliveryRepo({
    this.listResult,
    this.listCompleter,
    this.assignResult,
    this.dispatchResult,
  }) : super(dio: Dio());

  final ApiResult<List<Delivery>>? listResult;
  final Completer<ApiResult<List<Delivery>>>? listCompleter;
  final ApiResult<Delivery>? assignResult;
  final ApiResult<Delivery>? dispatchResult;

  int listCallCount = 0;
  int assignCallCount = 0;
  int dispatchCallCount = 0;
  int? lastAssignedId;
  int? lastDispatchedId;

  @override
  Future<ApiResult<List<Delivery>>> listReceiverRegional({
    List<DeliveryStatus>? statuses,
    int? perPage,
  }) {
    listCallCount++;
    if (listCompleter != null) return listCompleter!.future;
    return Future.value(
      listResult ?? const ApiSuccess<List<Delivery>>([]),
    );
  }

  @override
  Future<ApiResult<Delivery>> assignRegionalDispatcher(int id) async {
    assignCallCount++;
    lastAssignedId = id;
    if (assignResult == null) {
      throw StateError('assignResult not stubbed');
    }
    return assignResult!;
  }

  @override
  Future<ApiResult<Delivery>> dispatchRegionalProvider(
    int id, {
    required String providerName,
    required String providerType,
    required String ticketNumber,
    required String routeFrom,
    required String routeTo,
    double? transportFare,
    String? notes,
  }) async {
    dispatchCallCount++;
    lastDispatchedId = id;
    if (dispatchResult == null) {
      throw StateError('dispatchResult not stubbed');
    }
    return dispatchResult!;
  }
}

Widget _wrap({
  required DeliveryRepository repo,
  AuthUser? user,
}) {
  return ProviderScope(
    overrides: [
      deliveryRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWithValue(user ?? _dispatcherUser()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: ReceiverRegionalTab()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  // ─── Dispatcher gate ────────────────────────────────────
  testWidgets('shows gate message for non-dispatcher receiver', (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeDeliveryRepo(
      listResult: const ApiSuccess<List<Delivery>>([]),
    );

    await tester.pumpWidget(_wrap(
      repo: repo,
      user: _dispatcherUser(enabled: false),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Dispatcher access required'), findsOneWidget);
    expect(find.text('Assign to me'), findsNothing);
    // List should not even load
    expect(repo.listCallCount, 0);
  });

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
  testWidgets('shows no-regional empty state when list is empty',
      (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeDeliveryRepo(
      listResult: const ApiSuccess<List<Delivery>>([]),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('No regional deliveries'), findsOneWidget);
  });

  testWidgets('filter chip narrows the list', (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([
        _regional(
            id: 1, trackingId: 'ODS-BATCH', status: DeliveryStatus.batched),
        _regional(
            id: 2, trackingId: 'ODS-ASSIGN', status: DeliveryStatus.assigned),
      ]),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('ODS-BATCH'), findsOneWidget);
    expect(find.text('ODS-ASSIGN'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Batched'));
    await tester.pumpAndSettle();

    expect(find.text('ODS-BATCH'), findsOneWidget);
    expect(find.text('ODS-ASSIGN'), findsNothing);
  });

  // ─── CTA visibility ─────────────────────────────────────
  testWidgets('batched shows "Assign to me" CTA, not dispatch', (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([
        _regional(id: 1, status: DeliveryStatus.batched),
      ]),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Assign to me'), findsOneWidget);
    expect(find.text('Dispatch via provider'), findsNothing);
  });

  testWidgets('assigned shows "Dispatch via provider" CTA, not assign',
      (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([
        _regional(id: 1, status: DeliveryStatus.assigned),
      ]),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Dispatch via provider'), findsOneWidget);
    expect(find.text('Assign to me'), findsNothing);
  });

  testWidgets('dispatched shows ticket block, no CTAs', (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([
        _regional(
          id: 1,
          status: DeliveryStatus.dispatched,
          ticket: _ticket(),
        ),
      ]),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('TKT-1234'), findsWidgets);
    expect(find.textContaining('Kilimanjaro Express'), findsOneWidget);
    expect(find.textContaining('Dar es Salaam → Arusha'), findsOneWidget);
    expect(find.text('Assign to me'), findsNothing);
    expect(find.text('Dispatch via provider'), findsNothing);
  });

  // ─── Assign flow ────────────────────────────────────────
  testWidgets('assign calls API + shows snackbar + refreshes', (tester) async {
    _useLargeViewport(tester);
    final batched = _regional(id: 7, status: DeliveryStatus.batched);
    final assigned = _regional(id: 7, status: DeliveryStatus.assigned);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([batched]),
      assignResult: ApiSuccess(assigned),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Assign to me'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.assignCallCount, 1);
    expect(repo.lastAssignedId, 7);
    expect(
      find.text('Dispatcher assigned. Ready to dispatch.'),
      findsOneWidget,
    );
  });

  testWidgets('assign failure shows error snackbar', (tester) async {
    _useLargeViewport(tester);
    final batched = _regional(id: 7, status: DeliveryStatus.batched);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([batched]),
      assignResult: const ApiFailure(
        Failure(
          type: FailureType.validation,
          message: 'Delivery is not in batched state.',
        ),
      ),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Assign to me'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.assignCallCount, 1);
    expect(find.text('Delivery is not in batched state.'), findsOneWidget);
  });

  // ─── Dispatch flow ──────────────────────────────────────
  testWidgets('dispatch opens form dialog with required fields',
      (tester) async {
    _useLargeViewport(tester);
    final assigned = _regional(
      id: 7,
      status: DeliveryStatus.assigned,
      region: 'Arusha',
      busFare: 3500,
    );
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([assigned]),
      dispatchResult: ApiSuccess(assigned),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dispatch via provider'));
    await tester.pumpAndSettle();

    // Dialog opens with header + fields
    expect(find.text('Dispatch ODS-REG-1'), findsOneWidget);
    expect(find.text('Provider name'), findsOneWidget);
    expect(find.text('Ticket number'), findsOneWidget);
    expect(find.text('Route from'), findsOneWidget);
    expect(find.text('Route to'), findsOneWidget);
    // Route to is pre-filled from destination region
    expect(find.text('Arusha'), findsWidgets);
    // Fare is pre-filled from bus_cargo_fare
    expect(find.text('3500'), findsWidgets);
  });

  testWidgets('dispatch form Cancel does not call API', (tester) async {
    _useLargeViewport(tester);
    final assigned = _regional(id: 7, status: DeliveryStatus.assigned);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([assigned]),
      dispatchResult: ApiSuccess(assigned),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dispatch via provider'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(repo.dispatchCallCount, 0);
  });

  testWidgets('dispatch form validation catches empty required fields',
      (tester) async {
    _useLargeViewport(tester);
    final assigned = _regional(
      id: 7,
      status: DeliveryStatus.assigned,
      region: 'Arusha', // Route to pre-filled
    );
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([assigned]),
      dispatchResult: ApiSuccess(assigned),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dispatch via provider'));
    await tester.pumpAndSettle();

    // Tap Dispatch without filling required fields
    await tester.tap(find.widgetWithText(FilledButton, 'Dispatch'));
    await tester.pumpAndSettle();

    // Validation messages shown for empty fields
    expect(find.text('Required'), findsWidgets);
    expect(repo.dispatchCallCount, 0);
  });

  testWidgets('dispatch calls API + shows snackbar with ticket number',
      (tester) async {
    _useLargeViewport(tester);
    // region: 'Arusha' makes Route-to pre-fill in the dialog, so the
    // form passes validation. Without it, _routeTo starts empty and
    // _submit() returns early without calling the API.
    final assigned = _regional(
      id: 7,
      status: DeliveryStatus.assigned,
      region: 'Arusha',
    );
    final dispatched = _regional(
      id: 7,
      status: DeliveryStatus.dispatched,
      ticket: _ticket(),
    );
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([assigned]),
      dispatchResult: ApiSuccess(dispatched),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dispatch via provider'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Provider name'),
      'Kilimanjaro Express',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ticket number'),
      'TKT-1234',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Route from'),
      'Dar es Salaam',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Dispatch'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.dispatchCallCount, 1);
    expect(repo.lastDispatchedId, 7);
    expect(
      find.textContaining('Dispatched via Kilimanjaro Express'),
      findsOneWidget,
    );
    expect(find.textContaining('Ticket TKT-1234'), findsOneWidget);
  });

  testWidgets('dispatch failure shows error snackbar', (tester) async {
    _useLargeViewport(tester);
    // Same fix as above — route_to needs a value for the form to submit.
    final assigned = _regional(
      id: 7,
      status: DeliveryStatus.assigned,
      region: 'Arusha',
    );
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([assigned]),
      dispatchResult: const ApiFailure(
        Failure(
          type: FailureType.validation,
          message: 'This delivery already has a dispatch ticket.',
        ),
      ),
    );
    
    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dispatch via provider'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Provider name'),
      'Express',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ticket number'),
      'TKT-1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Route from'),
      'DSM',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Dispatch'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.dispatchCallCount, 1);
    expect(
      find.text('This delivery already has a dispatch ticket.'),
      findsOneWidget,
    );
  });
}
