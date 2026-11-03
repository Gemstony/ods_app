import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/auth/auth_user.dart';
import 'package:ods_app/data/models/branch.dart';
import 'package:ods_app/data/models/delivery.dart';
import 'package:ods_app/data/models/delivery_input.dart';
import 'package:ods_app/data/repositories/branch_repository.dart';
import 'package:ods_app/data/repositories/delivery_repository.dart';
import 'package:ods_app/features/distributor/presentation/wizards/new_receive_delivery_wizard.dart';
import 'package:ods_app/shared/providers/auth_provider.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';

void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

// ─────────────────────────────────────────────────────────────────────
// Fixtures
// ─────────────────────────────────────────────────────────────────────

Branch _testBranch() => const Branch(
      id: 5,
      name: 'Kariakoo Branch',
      code: 'KRK-01',
      address: '123 Kariakoo',
      latitude: -6.79,
      longitude: 39.20,
      status: BranchStatus.active,
    );

/// Signed-in Distributor used to pre-fill the pickup phone in step 2.
AuthUser _testUser() => const AuthUser(
      id: 42,
      name: 'Test Distributor',
      email: 'dist@ods.test',
      phone: '0712345678',
      role: 'distributor',
      status: 'active',
      dispatcherEnabled: false,
      permissions: [],
    );

class _FakeBranchRepo extends BranchRepository {
  _FakeBranchRepo({this.branches = const []}) : super(dio: Dio());
  final List<Branch> branches;

  @override
  Future<ApiResult<List<Branch>>> listAvailableForPickup() async =>
      ApiSuccess(branches);
}

class _FakeDeliveryRepo extends DeliveryRepository {
  _FakeDeliveryRepo({
    this.preview,
    this.createResult,
  }) : super(dio: Dio());

  final PricePreviewResult? preview;
  final Delivery? createResult;

  PricePreviewInput? capturedPreviewInput;
  CreateDeliveryInput? capturedCreateInput;
  int createCallCount = 0;

  @override
  Future<ApiResult<PricePreviewResult>> pricePreview(
    PricePreviewInput input,
  ) async {
    capturedPreviewInput = input;
    return ApiSuccess(preview ?? _defaultPreview());
  }

  @override
  Future<ApiResult<Delivery>> create(CreateDeliveryInput input) async {
    createCallCount++;
    capturedCreateInput = input;
    return ApiSuccess(createResult ?? _defaultDelivery());
  }
}

PricePreviewResult _defaultPreview() => const PricePreviewResult(
      serviceType: ServiceType.receive,
      distanceKm: 3.2,
      ratePerKm: 500,
      minimumFee: 1000,
      roundingIncrement: 500,
      calculatedFee: 1600,
      odsDeliveryFee: 2000,
      discountAmount: 0,
      totalAmount: 2000,
      currency: 'TZS',
    );

Delivery _defaultDelivery() => Delivery(
      id: 1,
      trackingId: 'ODS-20261104-ABC123',
      distributorId: 42,
      pickupBranchId: 5,
      serviceType: ServiceType.receive,
      status: DeliveryStatus.pending_payment,
      rawStatus: 'pending_payment',
      discountAmount: 0,
      currency: 'TZS',
    );

// ─────────────────────────────────────────────────────────────────────
// Auto-push host
// ─────────────────────────────────────────────────────────────────────

/// Hosts the wizard by *pushing* it from a stub screen so that the
/// wizard's `Navigator.pop()` on submit actually has a route to return
/// to. Setting the wizard as `MaterialApp.home` makes it the root route,
/// which `Navigator.pop()` refuses to remove.
class _AutoPushHost extends StatefulWidget {
  const _AutoPushHost();

  @override
  State<_AutoPushHost> createState() => _AutoPushHostState();
}

class _AutoPushHostState extends State<_AutoPushHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const NewReceiveDeliveryWizard(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: SizedBox.shrink(),
      );
}

// ─────────────────────────────────────────────────────────────────────
// Harness
// ─────────────────────────────────────────────────────────────────────

Widget _wrap({
  BranchRepository? branchRepo,
  DeliveryRepository? deliveryRepo,
  AuthUser? user,
}) {
  return ProviderScope(
    overrides: [
      branchRepositoryProvider.overrideWithValue(
        branchRepo ?? _FakeBranchRepo(branches: [_testBranch()]),
      ),
      deliveryRepositoryProvider.overrideWithValue(
        deliveryRepo ?? _FakeDeliveryRepo(),
      ),
      currentUserProvider.overrideWithValue(user ?? _testUser()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const _AutoPushHost(),
    ),
  );
}

/// Mounts the app and pumps until the wizard has finished pushing in.
Future<void> _openWizard(
  WidgetTester tester, {
  BranchRepository? branchRepo,
  DeliveryRepository? deliveryRepo,
  AuthUser? user,
}) async {
  await tester.pumpWidget(_wrap(
    branchRepo: branchRepo,
    deliveryRepo: deliveryRepo,
    user: user,
  ));
  // Let the post-frame callback run, then settle through the push
  // transition so the wizard is fully on screen.
  await tester.pump();
  await tester.pumpAndSettle();
}

// ─────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  testWidgets('renders step 1 (branch) initially', (tester) async {
    _useLargeViewport(tester);
    await _openWizard(tester);

    expect(find.byType(NewReceiveDeliveryWizard), findsOneWidget);
    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(find.text('Kariakoo Branch'), findsOneWidget);
    final nextButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Next'),
    );
    expect(nextButton.onPressed, isNull);
  });

  testWidgets('selecting branch enables Next and advances to step 2',
      (tester) async {
    _useLargeViewport(tester);
    await _openWizard(tester);

    await tester.tap(find.text('Kariakoo Branch'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final nextButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Next'),
    );
    expect(nextButton.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Step 2 of 4'), findsOneWidget);
    expect(find.text('How did you place this order?'), findsOneWidget);
  });

  testWidgets('order details: EXGO mode requires at least one ID',
      (tester) async {
    _useLargeViewport(tester);
    await _openWizard(tester);

    await tester.tap(find.text('Kariakoo Branch'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pumpAndSettle();

    expect(find.text('Enter an order ID.'), findsOneWidget);
    expect(find.text('Step 2 of 4'), findsOneWidget);
  });

  testWidgets('order details: entering EXGO ID advances to step 3',
      (tester) async {
    _useLargeViewport(tester);
    await _openWizard(tester);

    await tester.tap(find.text('Kariakoo Branch'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Order ID 1'),
      'EXGO-12345',
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Step 3 of 4'), findsOneWidget);
    expect(find.text('Where should we deliver?'), findsOneWidget);
  });

  testWidgets('location step validates address + coordinates',
      (tester) async {
    _useLargeViewport(tester);
    await _openWizard(tester);

    // Navigate to step 3
    await tester.tap(find.text('Kariakoo Branch'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Order ID 1'),
      'EXGO-12345',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Step 3 of 4'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pumpAndSettle();

    expect(find.text('Address is required.'), findsOneWidget);
    expect(find.text('Required.'), findsNWidgets(2));
  });

  testWidgets('full flow: complete all steps → delivery created',
      (tester) async {
    _useLargeViewport(tester);
    final deliveryRepo = _FakeDeliveryRepo();
    await _openWizard(tester, deliveryRepo: deliveryRepo);

    // Step 1: select branch → Next
    await tester.tap(find.text('Kariakoo Branch'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Step 2: enter EXGO ID → Next
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Order ID 1'),
      'EXGO-12345',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Step 3: enter address + coords → Next
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Address'),
      '456 Upanga Road',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Latitude'),
      '-6.7890',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Longitude'),
      '39.2200',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Step 4: preview loads
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Step 4 of 4'), findsOneWidget);
    expect(find.text('TZS 2000'), findsWidgets);

    expect(deliveryRepo.capturedPreviewInput, isNotNull);
    expect(deliveryRepo.capturedPreviewInput!.serviceType, ServiceType.receive);
    expect(deliveryRepo.capturedPreviewInput!.pickupBranchId, 5);
    expect(deliveryRepo.capturedPreviewInput!.destinationLatitude, -6.7890);
    expect(deliveryRepo.capturedPreviewInput!.destinationLongitude, 39.2200);

    // Submit
    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit & pay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify create was called once with all collected data
    expect(deliveryRepo.createCallCount, 1);
    final captured = deliveryRepo.capturedCreateInput!;
    expect(captured.serviceType, ServiceType.receive);
    expect(captured.pickupBranchId, 5);
    expect(captured.items.length, 1);
    expect(captured.items[0].exgoOrderId, 'EXGO-12345');
    expect(captured.pickupContactPhone, '0712345678');
    expect(captured.destinationAddress, '456 Upanga Road');
    expect(captured.destinationLatitude, -6.7890);
    expect(captured.destinationLongitude, 39.2200);

    // Wizard pops through the auto-push host. Two pumps: one to trigger
    // the pop's initial frame, one to complete the ~300ms transition.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(NewReceiveDeliveryWizard), findsNothing);
  });
}