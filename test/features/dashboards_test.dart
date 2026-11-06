import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/auth/auth_user.dart';
import 'package:ods_app/data/models/package_verify_result.dart';
import 'package:ods_app/data/models/reward.dart';
import 'package:ods_app/features/distributor/presentation/screens/distributor_dashboard_screen.dart';
import 'package:ods_app/features/manager/presentation/screens/manager_dashboard_screen.dart';
import 'package:ods_app/features/owner/presentation/screens/owner_dashboard_screen.dart';
import 'package:ods_app/features/receiver/presentation/screens/receiver_dashboard_screen.dart';
import 'package:ods_app/features/rider/presentation/screens/rider_dashboard_screen.dart';
import 'package:dio/dio.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/models/dashboard_kpis.dart';
import 'package:ods_app/data/models/manager_dashboard_kpis.dart';
import 'package:ods_app/data/models/rider_dashboard_kpis.dart';
import 'package:ods_app/data/repositories/dashboard_repository.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';
import 'package:ods_app/data/repositories/staff_repository.dart';
import 'package:ods_app/data/models/delivery.dart';
import 'package:ods_app/data/repositories/delivery_repository.dart';
import 'package:ods_app/data/models/branch.dart';
import 'package:ods_app/data/repositories/branch_repository.dart';
import 'package:ods_app/data/models/distributor_dashboard_kpis.dart';
import 'package:ods_app/data/repositories/reward_repository.dart';

class _FakeDashboardRepo extends DashboardRepository {
  _FakeDashboardRepo() : super(dio: Dio());

  @override
  Future<ApiResult<DashboardKpis>> getKpis() async =>
      ApiSuccess(DashboardKpis.empty());

  @override
  Future<ApiResult<ManagerDashboardKpis>> getManagerKpis() async =>
      ApiSuccess(ManagerDashboardKpis.empty());

  @override
  Future<ApiResult<DistributorDashboardKpis>> getDistributorKpis() async =>
      ApiSuccess(DistributorDashboardKpis.empty());

  @override
  Future<ApiResult<RiderDashboardKpis>> getRiderKpis() async =>
      ApiSuccess(RiderDashboardKpis.empty());
}

class _FakeRewardRepo extends RewardRepository {
  _FakeRewardRepo() : super(dio: Dio());

  @override
  Future<ApiResult<Reward>> getMyProgress() async => ApiSuccess(_emptyReward());

  @override
  Future<ApiResult<DistributorRewardKpis>> getMyOverview() async =>
      ApiSuccess(DistributorRewardKpis.empty());

  Reward _emptyReward() => const Reward(
        id: 0,
        distributorId: 0,
        currentMonth: '',
        monthlyCount: 0,
        tier1Available: false,
        rollingCount: 0,
        tier2Available: false,
      );
}

class _FakeStaffRepo extends StaffRepository {
  _FakeStaffRepo() : super(dio: Dio());

  @override
  Future<ApiResult<List<AuthUser>>> list({
    String? role,
    String? status,
    String? search,
    int? perPage,
    int page = 1,
  }) async =>
      const ApiSuccess<List<AuthUser>>([]);
}

class _FakeDeliveryRepo extends DeliveryRepository {
  _FakeDeliveryRepo() : super(dio: Dio());

  @override
  Future<ApiResult<List<Delivery>>> listForBranch({
    List<DeliveryStatus>? statuses,
    ServiceType? serviceType,
    int? perPage,
    int page = 1,
  }) async =>
      const ApiSuccess<List<Delivery>>([]);

  @override
  Future<ApiResult<List<Delivery>>> listAtBranch() async =>
      const ApiSuccess<List<Delivery>>([]);

  @override
  Future<ApiResult<List<Delivery>>> listMine({
    DeliveryStatus? status,
    ServiceType? serviceType,
    int? limit,
    int? offset,
  }) async =>
      const ApiSuccess<List<Delivery>>([]);

  @override
  Future<ApiResult<List<Delivery>>> listForRider({
    List<DeliveryStatus>? statuses,
    ServiceType? serviceType,
    int? perPage,
  }) async =>
      const ApiSuccess<List<Delivery>>([]);

  @override
  Future<ApiResult<List<Delivery>>> listReceiverPackages({
    List<DeliveryStatus>? statuses,
    int? perPage,
  }) async =>
      const ApiSuccess<List<Delivery>>([]);

  @override
  Future<ApiResult<PackageVerifyResult>> verifyReceiverPackage(int id) async =>
      throw StateError('Not stubbed in dashboard tests');

  @override
  Future<ApiResult<Delivery>> releaseReceiverPackage(int id) async =>
      throw StateError('Not stubbed in dashboard tests');

  @override
  Future<ApiResult<List<Delivery>>> listReceiverRegional({
    List<DeliveryStatus>? statuses,
    int? perPage,
  }) async =>
      const ApiSuccess<List<Delivery>>([]);

  @override
  Future<ApiResult<Delivery>> assignRegionalDispatcher(int id) async =>
      throw StateError('Not stubbed in dashboard tests');

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
  }) async =>
      throw StateError('Not stubbed in dashboard tests');

  @override
  Future<ApiResult<Delivery>> getForBranch(int id) async =>
      throw StateError('Not stubbed in dashboard tests');

  @override
  Future<ApiResult<Delivery>> getMine(int id) async =>
      throw StateError('Not stubbed in dashboard tests');
}

class _FakeBranchRepo extends BranchRepository {
  _FakeBranchRepo() : super(dio: Dio());

  @override
  Future<ApiResult<Branch>> getMyBranch() async => const ApiSuccess(Branch(
        id: 1,
        name: 'Test Branch',
        code: 'TST-01',
        address: 'Address',
        latitude: 0,
        longitude: 0,
        status: BranchStatus.active,
      ));

  @override
  Future<ApiResult<Branch>> updateMyBranch({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    Map<String, dynamic>? operatingHours,
  }) async =>
      const ApiSuccess(Branch(
        id: 1,
        name: 'Test Branch',
        code: 'TST-01',
        address: 'Address',
        latitude: 0,
        longitude: 0,
        status: BranchStatus.active,
      ));
}

Widget _wrapDashboard(Widget dashboard) {
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(path: '/dashboard', builder: (_, __) => dashboard),
      GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(body: Text('Login stub')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      dashboardRepositoryProvider.overrideWithValue(_FakeDashboardRepo()),
      staffRepositoryProvider.overrideWithValue(_FakeStaffRepo()),
      deliveryRepositoryProvider.overrideWithValue(_FakeDeliveryRepo()),
      branchRepositoryProvider.overrideWithValue(_FakeBranchRepo()),
      rewardRepositoryProvider.overrideWithValue(_FakeRewardRepo()),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router,
    ),
  );
}

Future<void> _pumpDashboard(WidgetTester tester, Widget dashboard) async {
  await tester.pumpWidget(_wrapDashboard(dashboard));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(AppConfig.initialize);

  testWidgets('Owner dashboard renders with 5 tabs', (tester) async {
    await _pumpDashboard(tester, const OwnerDashboardScreen());

    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.destinations.length, 5);
    expect(navBar.selectedIndex, 0);

    for (final label in ['Home', 'Branches', 'Users', 'Finance', 'Settings']) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('Manager dashboard renders with 5 tabs', (tester) async {
    await _pumpDashboard(tester, const ManagerDashboardScreen());
    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.destinations.length, 5);
    for (final label in [
      'Home',
      'Staff',
      'Deliveries',
      'Packages',
      'Profile'
    ]) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('Distributor dashboard renders with 4 tabs + FAB',
      (tester) async {
    await _pumpDashboard(tester, const DistributorDashboardScreen());
    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.destinations.length, 4);

    for (final label in ['Home', 'History', 'Rewards', 'Profile']) {
      expect(find.text(label), findsWidgets);
    }

    expect(find.text('New'), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('New delivery'), findsOneWidget);
  });

  testWidgets('Rider dashboard renders with 5 tabs', (tester) async {
    await _pumpDashboard(tester, const RiderDashboardScreen());
    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.destinations.length, 5);
    for (final label in ['Home', 'Tasks', 'Active', 'Earnings', 'Profile']) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('Receiver dashboard renders with 4 tabs', (tester) async {
    await _pumpDashboard(tester, const ReceiverDashboardScreen());
    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.destinations.length, 4);
    for (final label in ['Packages', 'Regional', 'History', 'Profile']) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('Distributor FAB opens service picker with all 3 services',
      (tester) async {
    await _pumpDashboard(tester, const DistributorDashboardScreen());

    await tester.tap(
      find.widgetWithText(FloatingActionButton, 'New delivery'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Choose the service you need.'), findsOneWidget);
    expect(find.text('Receive'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Regional'), findsOneWidget);
  });

  testWidgets('tapping a tab updates the selected index', (tester) async {
    await _pumpDashboard(tester, const OwnerDashboardScreen());

    var navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 0);

    await tester.tap(find.text('Branches').last);
    await tester.pumpAndSettle();
    navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 1);

    await tester.tap(find.text('Finance').last);
    await tester.pumpAndSettle();
    navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 3);
  });
}