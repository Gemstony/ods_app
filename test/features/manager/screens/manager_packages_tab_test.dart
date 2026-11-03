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
import 'package:ods_app/features/manager/presentation/screens/manager_packages_tab.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';
import 'package:ods_app/widgets/widgets.dart';

void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Delivery _pkg({
  int id = 1,
  String trackingId = 'ODS-1',
  int? hours = 2,
}) =>
    Delivery(
      id: id,
      trackingId: trackingId,
      distributorId: 42,
      serviceType: ServiceType.receive,
      status: DeliveryStatus.paid,
      rawStatus: 'paid',
      discountAmount: 0,
      currency: 'TZS',
      totalAmount: 2000,
      destinationAddress: 'Upanga',
      createdAt: DateTime(2026, 11, 4, 10, 0),
      hoursAtBranch: hours,
    );

class _FakeRepo extends DeliveryRepository {
  _FakeRepo(this._result) : super(dio: Dio());
  final ApiResult<List<Delivery>> _result;

  @override
  Future<ApiResult<List<Delivery>>> listAtBranch() async => _result;

  @override
  Future<ApiResult<List<Delivery>>> listForBranch({
    List<DeliveryStatus>? statuses,
    ServiceType? serviceType,
    int? perPage,
    int page = 1,
  }) async =>
      _result;

  @override
  Future<ApiResult<Delivery>> getForBranch(int id) async =>
      ApiSuccess(_pkg(id: id));
}

class _PendingRepo extends DeliveryRepository {
  _PendingRepo() : super(dio: Dio());
  final _completer = Completer<ApiResult<List<Delivery>>>();

  @override
  Future<ApiResult<List<Delivery>>> listAtBranch() => _completer.future;
}

Widget _wrap(DeliveryRepository repo) => ProviderScope(
      overrides: [deliveryRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: ManagerPackagesTab()),
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

  testWidgets('shows empty state when no packages', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(_FakeRepo(ApiSuccess(const []))));
    await tester.pumpAndSettle();

    expect(find.text('No packages at branch'), findsOneWidget);
  });

  testWidgets('renders summary banner with counts', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(_FakeRepo(ApiSuccess([
      _pkg(id: 1, trackingId: 'ODS-F1', hours: 1),
      _pkg(id: 2, trackingId: 'ODS-A1', hours: 12),
      _pkg(id: 3, trackingId: 'ODS-S1', hours: 30),
    ]))));
    await tester.pumpAndSettle();

    expect(find.text('3 packages at branch'), findsOneWidget);
    expect(find.textContaining('1 Fresh'), findsOneWidget);
    expect(find.textContaining('1 Aging'), findsOneWidget);
    expect(find.textContaining('1 Stale'), findsOneWidget);
  });

  testWidgets('renders package cards with aging chips', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(_FakeRepo(ApiSuccess([
      _pkg(id: 1, trackingId: 'ODS-F', hours: 2),
      _pkg(id: 2, trackingId: 'ODS-S', hours: 30),
    ]))));
    await tester.pumpAndSettle();

    expect(find.text('ODS-F'), findsOneWidget);
    expect(find.text('ODS-S'), findsOneWidget);
    expect(find.text('2h at branch'), findsOneWidget);
    expect(find.text('1d at branch'), findsOneWidget);
  });

  testWidgets('stale chip shows warning icon', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(_FakeRepo(ApiSuccess([
      _pkg(id: 1, trackingId: 'ODS-STALE', hours: 30),
    ]))));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('shows error state with retry', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(ApiFailure(
      const Failure(type: FailureType.network, message: 'Offline'),
    ))));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('fresh filter chip filters list', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(_FakeRepo(ApiSuccess([
      _pkg(id: 1, trackingId: 'ODS-FRESH', hours: 2),
      _pkg(id: 2, trackingId: 'ODS-STALE', hours: 30),
    ]))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fresh'));
    await tester.pumpAndSettle();

    expect(find.text('ODS-FRESH'), findsOneWidget);
    expect(find.text('ODS-STALE'), findsNothing);
  });

  testWidgets('stale filter chip filters list', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(_FakeRepo(ApiSuccess([
      _pkg(id: 1, trackingId: 'ODS-FRESH', hours: 2),
      _pkg(id: 2, trackingId: 'ODS-STALE', hours: 30),
    ]))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stale'));
    await tester.pumpAndSettle();

    expect(find.text('ODS-FRESH'), findsNothing);
    expect(find.text('ODS-STALE'), findsOneWidget);
  });

  testWidgets('tapping a package card opens delivery detail', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(_FakeRepo(ApiSuccess([
      _pkg(id: 1, trackingId: 'ODS-PKG-1', hours: 2),
    ]))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ODS-PKG-1'));

    // Explicit pumps — same pattern as 6.4 fixup: RefreshIndicator on
    // the pushed screen can keep pumpAndSettle spinning.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('ODS-PKG-1'), findsWidgets);
  });
}