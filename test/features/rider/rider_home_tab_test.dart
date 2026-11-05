import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/theme/app_colors.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/delivery.dart';
import 'package:ods_app/data/models/rider_dashboard_kpis.dart';
import 'package:ods_app/features/rider/presentation/providers/rider_dashboard_providers.dart';
import 'package:ods_app/features/rider/presentation/screens/rider_home_tab.dart';
import 'package:ods_app/widgets/widgets.dart';

void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Delivery _delivery({
  int id = 1,
  String trackingId = 'ODS-20261104-TEST01',
  DeliveryStatus status = DeliveryStatus.assigned,
  String? recipientName,
  String? destinationAddress,
  ServiceType serviceType = ServiceType.receive,
  String? destinationRegion,
  String? destinationDistrict,
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
    destinationRegion: destinationRegion,
    destinationDistrict: destinationDistrict,
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
  );
}

RiderHomeData _sample({
  int available = 2,
  int active = 1,
  int deliveredToday = 3,
  int totalDelivered = 20,
  double thisMonthTsh = 15000,
  double pendingTsh = 5000,
  List<Delivery>? deliveries,
}) {
  return RiderHomeData(
    kpis: RiderDashboardKpis(
      tasks: RiderTaskKpis(
        available: available,
        active: active,
        deliveredToday: deliveredToday,
        deliveredThisMonth: 10,
        totalDelivered: totalDelivered,
      ),
      earnings: RiderEarningKpis(
        thisMonthTsh: thisMonthTsh,
        pendingTsh: pendingTsh,
      ),
      generatedAt: DateTime.now(),
    ),
    deliveries: deliveries ?? const [],
  );
}

Widget _wrap({RiderHomeData? data, Failure? error}) {
  return ProviderScope(
    overrides: [
      riderHomeProvider.overrideWith((ref) async {
        if (error != null) throw error;
        return data ?? _sample();
      }),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: RiderHomeTab()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  testWidgets('shows loading state', (tester) async {
    final completer = Completer<RiderHomeData>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          riderHomeProvider.overrideWith((ref) => completer.future),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: RiderHomeTab()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LoadingView), findsOneWidget);
  });

  testWidgets('shows error state with retry', (tester) async {
    await tester.pumpWidget(_wrap(error: const Failure(
      type: FailureType.network,
      message: 'Offline',
    )));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('renders all four KPI labels', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sample()));
    await tester.pumpAndSettle();

    expect(find.text('Available'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Delivered today'), findsOneWidget);
    expect(find.text('Total delivered'), findsOneWidget);
  });

  testWidgets('Available tile highlights when > 0', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sample(available: 3)));
    await tester.pumpAndSettle();

    final tile = find
        .ancestor(
          of: find.text('Available'),
          matching: find.byType(Container),
        )
        .first;
    final valueWidget = tester.widget<Text>(
      find.descendant(of: tile, matching: find.text('3')),
    );
    expect(valueWidget.style?.color, AppColors.warning);
  });

  testWidgets('renders earnings section', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(
      _wrap(data: _sample(thisMonthTsh: 15000, pendingTsh: 5000)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Earnings'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    // 15000 → "TZS 15.0k" (>= 10000 branch)
    expect(find.text('TZS 15.0k'), findsOneWidget);
    // 5000  → "TZS 5000"  (< 10000 branch)
    expect(find.text('TZS 5000'), findsOneWidget);
  });

  testWidgets('hides active task section when no active delivery',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sample(deliveries: const [])));
    await tester.pumpAndSettle();

    expect(find.text('Active task'), findsNothing);
  });

  testWidgets('shows active task hero when there is an accepted delivery',
      (tester) async {
    _useLargeViewport(tester);
    final active = _delivery(
      id: 7,
      trackingId: 'ODS-ACTIVE-7',
      status: DeliveryStatus.accepted,
      recipientName: 'Jane Customer',
      destinationAddress: '456 Upanga',
    );
    await tester.pumpWidget(_wrap(data: _sample(
      deliveries: [active],
    )));
    await tester.pumpAndSettle();

    expect(find.text('Active task'), findsOneWidget);
    // Active task appears exactly once — must NOT be duplicated
    // in the recent activity list.
    expect(find.text('ODS-ACTIVE-7'), findsOneWidget);
    expect(find.text('Jane Customer'), findsOneWidget);
  });

  testWidgets('shows active task hero for picked_up deliveries',
      (tester) async {
    _useLargeViewport(tester);
    final pickedUp = _delivery(
      id: 9,
      trackingId: 'ODS-PICKED-9',
      status: DeliveryStatus.picked_up,
    );
    await tester.pumpWidget(_wrap(data: _sample(
      deliveries: [pickedUp],
    )));
    await tester.pumpAndSettle();

    expect(find.text('Active task'), findsOneWidget);
    expect(find.text('ODS-PICKED-9'), findsOneWidget);
  });

  testWidgets('active task is excluded from recent activity list',
      (tester) async {
    _useLargeViewport(tester);
    final active = _delivery(
      id: 7,
      trackingId: 'ODS-ACTIVE-7',
      status: DeliveryStatus.accepted,
    );
    final recent1 = _delivery(
      id: 1,
      trackingId: 'ODS-RECENT-1',
      status: DeliveryStatus.delivered,
    );
    final recent2 = _delivery(
      id: 2,
      trackingId: 'ODS-RECENT-2',
      status: DeliveryStatus.delivered,
    );
    await tester.pumpWidget(_wrap(data: _sample(
      deliveries: [active, recent1, recent2],
    )));
    await tester.pumpAndSettle();

    expect(find.text('Active task'), findsOneWidget);
    expect(find.text('ODS-ACTIVE-7'), findsOneWidget);
    expect(find.text('Recent activity'), findsOneWidget);
    expect(find.text('ODS-RECENT-1'), findsOneWidget);
    expect(find.text('ODS-RECENT-2'), findsOneWidget);
  });

  testWidgets('renders recent activity for non-active deliveries',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sample(deliveries: [
      _delivery(id: 1, trackingId: 'ODS-RECENT-1', status: DeliveryStatus.delivered),
      _delivery(id: 2, trackingId: 'ODS-RECENT-2', status: DeliveryStatus.delivered),
    ])));
    await tester.pumpAndSettle();

    expect(find.text('Recent activity'), findsOneWidget);
    expect(find.text('ODS-RECENT-1'), findsOneWidget);
    expect(find.text('ODS-RECENT-2'), findsOneWidget);
  });

  testWidgets('shows empty state when no deliveries exist', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(data: _sample(deliveries: const [])));
    await tester.pumpAndSettle();

    expect(find.text('No tasks yet'), findsOneWidget);
    expect(find.textContaining('New tasks will appear here'), findsOneWidget);
  });
}