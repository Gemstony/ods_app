import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/auth/auth_user.dart';
import 'package:ods_app/data/models/delivery.dart';
import 'package:ods_app/data/models/delivery_input.dart';
import 'package:ods_app/data/repositories/delivery_repository.dart';
import 'package:ods_app/features/distributor/presentation/wizards/new_send_delivery_wizard.dart';
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

class _FakeDeliveryRepo extends DeliveryRepository {
  _FakeDeliveryRepo({this.preview, this.createResult}) : super(dio: Dio());

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
      serviceType: ServiceType.send,
      distanceKm: 4.5,
      ratePerKm: 500,
      minimumFee: 1000,
      roundingIncrement: 500,
      calculatedFee: 2250,
      odsDeliveryFee: 2500,
      discountAmount: 0,
      totalAmount: 2500,
      currency: 'TZS',
    );

Delivery _defaultDelivery() => Delivery(
      id: 1,
      trackingId: 'ODS-20261104-SEND01',
      distributorId: 42,
      serviceType: ServiceType.send,
      status: DeliveryStatus.pending_payment,
      rawStatus: 'pending_payment',
      discountAmount: 0,
      currency: 'TZS',
    );

/// Pushes the wizard from a stub host so `Navigator.pop()` on success
/// has a route to return to. (Same pattern as 7.3's Receive fixup.)
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
          builder: (_) => const NewSendDeliveryWizard(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}

Widget _wrap({
  DeliveryRepository? deliveryRepo,
  AuthUser? user,
}) {
  return ProviderScope(
    overrides: [
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
  DeliveryRepository? deliveryRepo,
  AuthUser? user,
}) async {
  await tester.pumpWidget(_wrap(deliveryRepo: deliveryRepo, user: user));
  await tester.pump();
  await tester.pumpAndSettle();
}

// ─────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  // ─── Test 1: Step 1 renders without contact phone ────────────
  testWidgets('renders step 1 (Order) with no contact phone field',
      (tester) async {
    _useLargeViewport(tester);
    await _openWizard(tester);

    expect(find.byType(NewSendDeliveryWizard), findsOneWidget);
    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(find.text('How did you place this order?'), findsOneWidget);

    // The pickup contact phone field is Receive-only; Send hides it.
    expect(find.text('Pickup contact phone'), findsNothing);
  });

  // ─── Test 2: EXGO ID advances to step 2 (Pickup) ─────────────
  testWidgets('order with EXGO ID advances to step 2 (Pickup)',
      (tester) async {
    _useLargeViewport(tester);
    await _openWizard(tester);

    // Fill EXGO ID
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Order ID 1'),
      'EXGO-98765',
    );
    await tester.pump();

    // Advance
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Step 2 of 4'), findsOneWidget);
    expect(find.text('Where are you dispatching from?'), findsOneWidget);
  });

  // ─── Test 3: Pickup location advances to step 3 (Recipient) ──
  testWidgets('pickup location advances to step 3 (Recipient)',
      (tester) async {
    _useLargeViewport(tester);
    await _openWizard(tester);

    // Step 1 → 2
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Order ID 1'),
      'EXGO-98765',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Step 2: fill pickup location
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Address'),
      '123 My Street',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Latitude'),
      '-6.7924',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Longitude'),
      '39.2083',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Step 3 of 4'), findsOneWidget);
    expect(find.text('Who is receiving the products?'), findsOneWidget);
  });

  // ─── Test 4: Recipient step validates all 5 fields ───────────
  testWidgets('recipient step validates all five fields', (tester) async {
    _useLargeViewport(tester);
    await _openWizard(tester);

    // Navigate to step 3
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Order ID 1'),
      'EXGO-98765',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Address'),
      '123 My Street',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Latitude'),
      '-6.7924',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Longitude'),
      '39.2083',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Confirm we're on step 3 before testing validation
    expect(find.text('Step 3 of 4'), findsOneWidget);

    // Submit empty
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pumpAndSettle();

    expect(find.text('Recipient name is required.'), findsOneWidget);
    expect(find.text('Phone number is required.'), findsOneWidget);
    expect(find.text('Address is required.'), findsOneWidget);
    expect(find.text('Required.'), findsNWidgets(2)); // lat + lng
  });

  // ─── Test 5: Full flow ───────────────────────────────────────
  testWidgets('full flow: complete all steps → delivery created',
      (tester) async {
    _useLargeViewport(tester);
    final repo = _FakeDeliveryRepo();
    await _openWizard(tester, deliveryRepo: repo);

    // Step 1: EXGO ID
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Order ID 1'),
      'EXGO-98765',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Step 2: pickup location
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Address'),
      '123 My Street',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Latitude'),
      '-6.7924',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Longitude'),
      '39.2083',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Step 3: recipient details
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Recipient name'),
      'Jane Customer',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Recipient phone'),
      '0755123456',
    );
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

    // Step 4: preview loads, then submit
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Step 4 of 4'), findsOneWidget);
    expect(find.text('TZS 2500'), findsWidgets);

    // Verify preview was requested with Send-specific input
    expect(repo.capturedPreviewInput, isNotNull);
    expect(repo.capturedPreviewInput!.serviceType, ServiceType.send);
    expect(repo.capturedPreviewInput!.pickupLatitude, -6.7924);
    expect(repo.capturedPreviewInput!.pickupLongitude, 39.2083);
    expect(repo.capturedPreviewInput!.destinationLatitude, -6.7890);
    expect(repo.capturedPreviewInput!.destinationLongitude, 39.2200);

    // Submit
    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit & pay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify create was called once with all collected data
    expect(repo.createCallCount, 1);
    final captured = repo.capturedCreateInput!;
    expect(captured.serviceType, ServiceType.send);
    expect(captured.items.length, 1);
    expect(captured.items[0].exgoOrderId, 'EXGO-98765');
    expect(captured.pickupAddress, '123 My Street');
    expect(captured.pickupLatitude, -6.7924);
    expect(captured.pickupLongitude, 39.2083);
    expect(captured.recipientName, 'Jane Customer');
    expect(captured.recipientPhone, '0755123456');
    expect(captured.destinationAddress, '456 Upanga Road');
    expect(captured.destinationLatitude, -6.7890);
    expect(captured.destinationLongitude, 39.2200);

    // Wizard popped (route transition needs explicit pumps —
    // RefreshIndicator on detail screens hangs pumpAndSettle)
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(NewSendDeliveryWizard), findsNothing);
  });
}