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
import 'package:ods_app/features/distributor/presentation/wizards/new_regional_delivery_wizard.dart';
import 'package:ods_app/shared/providers/auth_provider.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';

// ─────────────────────────────────────────────────────────────────────
// Test helpers
// ─────────────────────────────────────────────────────────────────────

void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Branch _testBranch() => const Branch(
      id: 5,
      name: 'Kariakoo Branch',
      code: 'KRK-01',
      address: '123 Kariakoo',
      latitude: -6.79,
      longitude: 39.20,
      status: BranchStatus.active,
    );

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
      serviceType: ServiceType.regional,
      distanceKm: 0,
      ratePerKm: 0,
      minimumFee: 0,
      roundingIncrement: 500,
      calculatedFee: 2000,
      odsDeliveryFee: 2000,
      busCargoFare: 3500,
      discountAmount: 0,
      totalAmount: 5500,
      currency: 'TZS',
    );

Delivery _defaultDelivery() => Delivery(
      id: 1,
      trackingId: 'ODS-20261104-REG01',
      distributorId: 42,
      pickupBranchId: 5,
      serviceType: ServiceType.regional,
      status: DeliveryStatus.pending_payment,
      rawStatus: 'pending_payment',
      discountAmount: 0,
      currency: 'TZS',
    );

/// Pushes the wizard from a stub host so `Navigator.pop()` on success
/// has a route to return to. (Same pattern as 7.3/7.4's fixups.)
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
          builder: (_) => const NewRegionalDeliveryWizard(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}

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
  await tester.pump();
  await tester.pumpAndSettle();
}

/// Walks from step 0 (Branch) up to [targetStep], filling valid data for
/// every step before it and leaving the wizard AT [targetStep].
///
/// - targetStep 0 → no navigation (default state after `_openWizard`)
/// - targetStep 1 → at Order
/// - targetStep 2 → at Recipient
/// - targetStep 3 → at Fare
/// - targetStep 4 → at Review (preview loaded)
Future<void> _goToStep(WidgetTester tester, int targetStep) async {
  if (targetStep <= 0) return;

  // ─── Step 0 → 1 (Branch → Order) ────────────────────────────
  await tester.tap(find.text('Kariakoo Branch'));
  await tester.pump();
  await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  if (targetStep == 1) return;

  // ─── Step 1 → 2 (Order → Recipient) ─────────────────────────
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Order ID 1'),
    'EXGO-REG-1',
  );
  await tester.pump();
  await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  if (targetStep == 2) return;

  // ─── Step 2 → 3 (Recipient → Fare) ──────────────────────────
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Recipient name'),
    'John Arusha',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Recipient phone'),
    '0762345678',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Region'),
    'Arusha',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'District'),
    'Arusha City',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Bus stop / collection point'),
    'Nairobi Road Station',
  );
  await tester.pump();
  await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  if (targetStep == 3) return;

  // ─── Step 3 → 4 (Fare → Review) ─────────────────────────────
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Transport fare (TZS)'),
    '3500',
  );
  await tester.pump();
  await tester.tap(find.widgetWithText(ElevatedButton, 'Review'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  // Let the preview load on the review step (fake repo completes on
  // the next microtask; extra pump settles the loading indicator).
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

// ─────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  // ─── Test 1: Step 1 (Branch) renders ────────────────────────
  testWidgets('renders step 1 (Branch) initially', (tester) async {
    _useLargeViewport(tester);
    await _openWizard(tester);

    expect(find.byType(NewRegionalDeliveryWizard), findsOneWidget);
    expect(find.text('Step 1 of 5'), findsOneWidget);
    expect(find.text('Kariakoo Branch'), findsOneWidget);
  });

  // ─── Test 2: Recipient step validates all 5 fields ─────────
  testWidgets('recipient step validates all five fields', (tester) async {
    _useLargeViewport(tester);
    await _openWizard(tester);
    await _goToStep(tester, 2);

    // Confirm we're at the recipient step before testing validation
    expect(find.text('Step 3 of 5'), findsOneWidget);
    expect(find.text('Who is receiving the products?'), findsOneWidget);

    // Submit empty
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pumpAndSettle();

    expect(find.text('Recipient name is required.'), findsOneWidget);
    expect(find.text('Phone number is required.'), findsOneWidget);
    expect(find.text('Region is required.'), findsOneWidget);
    expect(find.text('District is required.'), findsOneWidget);
    expect(
      find.text('Bus stop / collection point is required.'),
      findsOneWidget,
    );
  });

  // ─── Test 3: Fare step shows two-charge banner + validates ──
  testWidgets('fare step shows two-charge banner and validates fare',
      (tester) async {
    _useLargeViewport(tester);
    await _openWizard(tester);
    await _goToStep(tester, 3);

    expect(find.text('Step 4 of 5'), findsOneWidget);
    // The banner educates the distributor before they enter a fare.
    expect(find.text('Two separate charges'), findsOneWidget);
    expect(find.textContaining('ODS delivery fee'), findsWidgets);
    expect(find.textContaining('Bus/cargo fare'), findsWidgets);

    // Submit empty → the fare-specific error appears
    await tester.tap(find.widgetWithText(ElevatedButton, 'Review'));
    await tester.pumpAndSettle();

    expect(
      find.text('Transport fare is required (enter 0 if none).'),
      findsOneWidget,
    );
    // Still on step 4 — didn't advance
    expect(find.text('Step 4 of 5'), findsOneWidget);
  });

  // ─── Test 4: Review shows the two charges separately ────────
  testWidgets('review shows ODS fee + bus fare separately + total',
      (tester) async {
    _useLargeViewport(tester);
    await _openWizard(tester);
    await _goToStep(tester, 4);

    expect(find.text('Step 5 of 5'), findsOneWidget);

    // Charges section header
    expect(find.text('Charges'), findsOneWidget);

    // The two charges are shown as distinct rows
    expect(find.text('ODS delivery fee'), findsOneWidget);
    expect(find.text('Bus / cargo transport fare'), findsOneWidget);
    expect(find.text('Total payable'), findsOneWidget);

    // And their values:
    expect(find.text('TZS 2000'), findsWidgets); // ODS fee
    expect(find.text('TZS 3500'), findsWidgets); // bus fare
    expect(find.text('TZS 5500'), findsWidgets); // total
  });

  // ─── Test 5: Full flow ──────────────────────────────────────
  testWidgets('full flow: complete all steps → regional delivery created',
      (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeDeliveryRepo();
    await _openWizard(tester, deliveryRepo: repo);
    await _goToStep(tester, 4);

    // ─── Preview was called with the right input ────────────
    expect(repo.capturedPreviewInput, isNotNull);
    final previewInput = repo.capturedPreviewInput!;
    expect(previewInput.serviceType, ServiceType.regional);
    expect(previewInput.pickupBranchId, 5);
    expect(previewInput.destinationRegion, 'Arusha');
    expect(previewInput.destinationDistrict, 'Arusha City');
    expect(previewInput.busCargoFare, 3500);

    // ─── Submit ─────────────────────────────────────────────
    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit & pay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // ─── Create was called once with all collected data ─────
    expect(repo.createCallCount, 1);
    final captured = repo.capturedCreateInput!;
    expect(captured.serviceType, ServiceType.regional);
    expect(captured.items.length, 1);
    expect(captured.items[0].exgoOrderId, 'EXGO-REG-1');
    expect(captured.pickupBranchId, 5);
    expect(captured.recipientName, 'John Arusha');
    expect(captured.recipientPhone, '0762345678');
    expect(captured.destinationRegion, 'Arusha');
    expect(captured.destinationDistrict, 'Arusha City');
    expect(captured.destinationBusStop, 'Nairobi Road Station');
    expect(captured.busCargoFare, 3500);

    // ─── Wizard popped ──────────────────────────────────────
    // Explicit pumps — same pattern as 7.3/7.4 fixups to avoid hangs.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(NewRegionalDeliveryWizard), findsNothing);
  });
}