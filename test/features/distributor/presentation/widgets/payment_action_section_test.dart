import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/delivery.dart';
import 'package:ods_app/features/distributor/presentation/widgets/payment_action_section.dart';

Delivery _delivery({
  DeliveryStatus status = DeliveryStatus.pending_payment,
  double? totalAmount = 5000,
}) {
  return Delivery(
    id: 1,
    trackingId: 'ODS-TEST-1',
    distributorId: 42,
    serviceType: ServiceType.receive,
    status: status,
    rawStatus: status.name,
    discountAmount: 0,
    currency: 'TZS',
    totalAmount: totalAmount,
  );
}

Widget _wrap({
  required Delivery delivery,
  required VoidCallback onRefresh,
}) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: PaymentActionSection(
          delivery: delivery,
          onRefresh: onRefresh,
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(AppConfig.initialize);

  testWidgets('renders CTA when delivery is pending_payment', (tester) async {
    await tester.pumpWidget(_wrap(
      delivery: _delivery(),
      onRefresh: () {},
    ));
    await tester.pumpAndSettle();

    expect(find.text('Payment required'), findsOneWidget);
    expect(find.textContaining('Pay '), findsOneWidget);
  });

  testWidgets('shows amount in CTA label', (tester) async {
    await tester.pumpWidget(_wrap(
      delivery: _delivery(totalAmount: 7500),
      onRefresh: () {},
    ));
    await tester.pumpAndSettle();

    expect(find.text('Pay TZS 7500'), findsOneWidget);
  });

  testWidgets('renders nothing when delivery is paid', (tester) async {
    await tester.pumpWidget(_wrap(
      delivery: _delivery(status: DeliveryStatus.paid),
      onRefresh: () {},
    ));
    await tester.pumpAndSettle();

    expect(find.text('Payment required'), findsNothing);
  });

  testWidgets('renders nothing when delivery is delivered', (tester) async {
    await tester.pumpWidget(_wrap(
      delivery: _delivery(status: DeliveryStatus.delivered),
      onRefresh: () {},
    ));
    await tester.pumpAndSettle();

    expect(find.text('Payment required'), findsNothing);
  });

  testWidgets('renders nothing when delivery is cancelled', (tester) async {
    await tester.pumpWidget(_wrap(
      delivery: _delivery(status: DeliveryStatus.cancelled),
      onRefresh: () {},
    ));
    await tester.pumpAndSettle();

    expect(find.text('Payment required'), findsNothing);
  });
}