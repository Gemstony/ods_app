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
import 'package:ods_app/data/models/package_verify_result.dart';
import 'package:ods_app/data/repositories/delivery_repository.dart';
import 'package:ods_app/features/receiver/presentation/screens/receiver_packages_tab.dart';
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
  String? destinationAddress,
  String? recipientName,
  int? riderId,
}) {
  return Delivery(
    id: id,
    trackingId: trackingId,
    distributorId: 42,
    serviceType: ServiceType.receive,
    status: status,
    rawStatus: status.name,
    discountAmount: 0,
    currency: 'TZS',
    totalAmount: 5000,
    destinationAddress: destinationAddress,
    recipientName: recipientName,
    riderId: riderId,
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
  );
}

class _FakeDeliveryRepo extends DeliveryRepository {
  _FakeDeliveryRepo({
    this.listResult,
    this.listCompleter,
    this.verifyResult,
    this.releaseResult,
  }) : super(dio: Dio());

  final ApiResult<List<Delivery>>? listResult;
  final Completer<ApiResult<List<Delivery>>>? listCompleter;
  final ApiResult<PackageVerifyResult>? verifyResult;
  final ApiResult<Delivery>? releaseResult;

  int listCallCount = 0;
  int verifyCallCount = 0;
  int releaseCallCount = 0;
  int? lastVerifiedId;
  int? lastReleasedId;

  @override
  Future<ApiResult<List<Delivery>>> listReceiverPackages({
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
  Future<ApiResult<PackageVerifyResult>> verifyReceiverPackage(int id) async {
    verifyCallCount++;
    lastVerifiedId = id;
    if (verifyResult == null) {
      throw StateError('verifyResult not stubbed');
    }
    return verifyResult!;
  }

  @override
  Future<ApiResult<Delivery>> releaseReceiverPackage(int id) async {
    releaseCallCount++;
    lastReleasedId = id;
    if (releaseResult == null) {
      throw StateError('releaseResult not stubbed');
    }
    return releaseResult!;
  }
}

Widget _wrap({required DeliveryRepository repo}) {
  return ProviderScope(
    overrides: [
      deliveryRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: ReceiverPackagesTab()),
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
  testWidgets('shows no-packages empty state when list is empty',
      (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeDeliveryRepo(
      listResult: const ApiSuccess<List<Delivery>>([]),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('No packages at your branch'), findsOneWidget);
  });

  testWidgets('shows filter-empty state when filter excludes all',
      (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([
        _delivery(id: 1, status: DeliveryStatus.accepted),
      ]),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Paid'));
    await tester.pumpAndSettle();

    expect(find.text('No packages match your filter'), findsOneWidget);
    expect(find.text('Clear filter'), findsOneWidget);
  });

  testWidgets('clear filter restores full list', (tester) async {
    _useLargeViewport(tester);
    // Both deliveries are in states that no chip matches trivially:
    // accepted + paid. Tapping "Batched" filters to an empty list →
    // the Clear filter button appears in the filter-empty state.
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([
        _delivery(
            id: 1,
            trackingId: 'ODS-ACCEPTED',
            status: DeliveryStatus.accepted),
        _delivery(id: 2, trackingId: 'ODS-PAID', status: DeliveryStatus.paid),
      ]),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    // Sanity: both visible with All
    expect(find.text('ODS-ACCEPTED'), findsOneWidget);
    expect(find.text('ODS-PAID'), findsOneWidget);

    // Pick a chip with no matches → filter-empty state
    await tester.tap(find.widgetWithText(ChoiceChip, 'Batched'));
    await tester.pumpAndSettle();
    expect(find.text('No packages match your filter'), findsOneWidget);
    expect(find.text('ODS-ACCEPTED'), findsNothing);
    expect(find.text('ODS-PAID'), findsNothing);

    // Clear restores the full list
    await tester.tap(find.text('Clear filter'));
    await tester.pumpAndSettle();
    expect(find.text('ODS-ACCEPTED'), findsOneWidget);
    expect(find.text('ODS-PAID'), findsOneWidget);
  });

  // ─── Card rendering ─────────────────────────────────────
  testWidgets('renders package card fields', (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([
        _delivery(
          id: 1,
          trackingId: 'ODS-TEST-ABC',
          status: DeliveryStatus.accepted,
          destinationAddress: '456 Upanga',
          recipientName: 'Jane Customer',
        ),
      ]),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('ODS-TEST-ABC'), findsOneWidget);
    expect(find.text('456 Upanga'), findsOneWidget);
    expect(find.text('Jane Customer'), findsOneWidget);
  });

  testWidgets('Release button only on accepted deliveries',
      (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([
        _delivery(id: 1, status: DeliveryStatus.paid),
        _delivery(id: 2, status: DeliveryStatus.batched),
        _delivery(id: 3, status: DeliveryStatus.assigned),
        _delivery(id: 4, status: DeliveryStatus.accepted),
      ]),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(ElevatedButton, 'Release to rider'),
      findsOneWidget,
    );
  });

  testWidgets('shows helper hint for paid / batched / assigned',
      (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([
        _delivery(id: 1, status: DeliveryStatus.paid),
        _delivery(id: 2, status: DeliveryStatus.batched),
        _delivery(id: 3, status: DeliveryStatus.assigned),
      ]),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Awaiting rider assignment.'), findsOneWidget);
    expect(find.text('Batched — awaiting rider assignment.'), findsOneWidget);
    expect(find.text('Rider notified, awaiting acceptance.'), findsOneWidget);
  });

  // ─── Release flow — verify then confirm ─────────────────
  testWidgets('tapping Release calls verify then shows confirm dialog',
      (tester) async {
    _useLargeViewport(tester);
    final accepted = _delivery(
      id: 7,
      trackingId: 'ODS-ACCEPT-7',
      status: DeliveryStatus.accepted,
    );
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([accepted]),
      verifyResult: ApiSuccess(PackageVerifyResult(
        delivery: accepted,
        canRelease: true,
        rider: const RiderRef(
          id: 5,
          name: 'Jane Rider',
          phone: '0712345678',
        ),
      )),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Release to rider'));
    await tester.pumpAndSettle();

    expect(repo.verifyCallCount, 1);
    expect(repo.lastVerifiedId, 7);
    expect(find.text('Release package?'), findsOneWidget);
    expect(find.textContaining('Jane Rider'), findsOneWidget);
  });

  testWidgets('Cancel in confirm dialog does not call release',
      (tester) async {
    _useLargeViewport(tester);
    final accepted = _delivery(id: 7, status: DeliveryStatus.accepted);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([accepted]),
      verifyResult: ApiSuccess(PackageVerifyResult(
        delivery: accepted,
        canRelease: true,
        rider: const RiderRef(
          id: 5,
          name: 'Jane Rider',
          phone: '0712345678',
        ),
      )),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Release to rider'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(repo.releaseCallCount, 0);
  });

  testWidgets('confirming dialog calls release + shows snackbar',
      (tester) async {
    _useLargeViewport(tester);
    final accepted = _delivery(
      id: 7,
      trackingId: 'ODS-ACCEPT-7',
      status: DeliveryStatus.accepted,
    );
    final pickedUp = _delivery(
      id: 7,
      trackingId: 'ODS-ACCEPT-7',
      status: DeliveryStatus.picked_up,
    );
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([accepted]),
      verifyResult: ApiSuccess(PackageVerifyResult(
        delivery: accepted,
        canRelease: true,
        rider: const RiderRef(
          id: 5,
          name: 'Jane Rider',
          phone: '0712345678',
        ),
      )),
      releaseResult: ApiSuccess(pickedUp),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Release to rider'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Release'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.releaseCallCount, 1);
    expect(repo.lastReleasedId, 7);
    expect(find.text('Package released.'), findsOneWidget);
  });

  testWidgets('verify can_release=false shows cannot-release dialog',
      (tester) async {
    _useLargeViewport(tester);
    final accepted = _delivery(id: 7, status: DeliveryStatus.accepted);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([accepted]),
      verifyResult: ApiSuccess(PackageVerifyResult(
        delivery: accepted,
        canRelease: false,
        reason: "Package is currently 'picked_up', not 'accepted'.",
      )),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Release to rider'));
    await tester.pumpAndSettle();

    expect(find.text('Cannot release'), findsOneWidget);
    expect(find.textContaining("currently 'picked_up'"), findsOneWidget);
    expect(repo.releaseCallCount, 0);
  });

  testWidgets('verify failure shows error snackbar', (tester) async {
    _useLargeViewport(tester);
    final accepted = _delivery(id: 7, status: DeliveryStatus.accepted);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([accepted]),
      verifyResult: const ApiFailure(
        Failure(type: FailureType.network, message: 'Connection refused'),
      ),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Release to rider'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Connection refused'), findsOneWidget);
    expect(repo.releaseCallCount, 0);
  });

  testWidgets('release failure shows error snackbar', (tester) async {
    _useLargeViewport(tester);
    final accepted = _delivery(id: 7, status: DeliveryStatus.accepted);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([accepted]),
      verifyResult: ApiSuccess(PackageVerifyResult(
        delivery: accepted,
        canRelease: true,
        rider: const RiderRef(
          id: 5,
          name: 'Jane Rider',
          phone: '0712345678',
        ),
      )),
      releaseResult: const ApiFailure(
        Failure(
          type: FailureType.validation,
          message: 'Package is no longer accepted.',
        ),
      ),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Release to rider'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Release'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Package is no longer accepted.'), findsOneWidget);
  });

  // ─── Filter chips ───────────────────────────────────────
  testWidgets('status filter narrows the list', (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeDeliveryRepo(
      listResult: ApiSuccess<List<Delivery>>([
        _delivery(
            id: 1,
            trackingId: 'ODS-ACCEPTED',
            status: DeliveryStatus.accepted),
        _delivery(id: 2, trackingId: 'ODS-PAID', status: DeliveryStatus.paid),
      ]),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Accepted'));
    await tester.pumpAndSettle();

    expect(find.text('ODS-ACCEPTED'), findsOneWidget);
    expect(find.text('ODS-PAID'), findsNothing);
  });
}