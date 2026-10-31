import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/data/models/delivery.dart';
import 'package:ods_app/widgets/payment_summary.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
    );

Delivery _delivery({
  ServiceType serviceType = ServiceType.receive,
  double? odsDeliveryFee = 2000.00,
  double? busCargoFare,
  double discountAmount = 0.0,
  String? discountReason,
  double? totalAmount = 2000.00,
}) {
  return Delivery(
    id: 1,
    trackingId: 'ODS-20261024-ABC123',
    distributorId: 42,
    serviceType: serviceType,
    status: DeliveryStatus.pending_payment,
    rawStatus: 'pending_payment',
    discountAmount: discountAmount,
    discountReason: discountReason,
    currency: 'TZS',
    odsDeliveryFee: odsDeliveryFee,
    busCargoFare: busCargoFare,
    totalAmount: totalAmount,
  );
}

void main() {
  testWidgets('shows ODS fee for a local delivery', (tester) async {
    await tester.pumpWidget(_wrap(PaymentSummary(delivery: _delivery())));
    expect(find.text('Fee breakdown'), findsOneWidget);
    expect(find.text('ODS delivery fee'), findsOneWidget);
    expect(find.text('TZS 2000'), findsWidgets);
    expect(find.text('Total'), findsOneWidget);
  });

  testWidgets('shows bus/cargo fare for regional delivery', (tester) async {
    await tester.pumpWidget(_wrap(
      PaymentSummary(
        delivery: _delivery(
          serviceType: ServiceType.regional,
          odsDeliveryFee: 2000,
          busCargoFare: 3500,
          totalAmount: 5500,
        ),
      ),
    ));
    expect(find.text('Bus / cargo fare'), findsOneWidget);
    expect(find.text('TZS 3500'), findsOneWidget);
    expect(find.text('TZS 2000'), findsWidgets);
    expect(find.text('TZS 5500'), findsOneWidget);
  });

  testWidgets('does NOT show bus fare for local delivery', (tester) async {
    await tester.pumpWidget(_wrap(PaymentSummary(delivery: _delivery())));
    expect(find.text('Bus / cargo fare'), findsNothing);
  });

  testWidgets('shows discount line when discountAmount > 0', (tester) async {
    await tester.pumpWidget(_wrap(
      PaymentSummary(
        delivery: _delivery(
          discountAmount: 1000,
          discountReason: 'Tier 1 reward',
          totalAmount: 1000,
        ),
      ),
    ));
    expect(find.text('Tier 1 reward'), findsOneWidget);
    expect(find.text('-TZS 1000'), findsOneWidget);
  });

  testWidgets('shows "Discount" as default label when reason is null',
      (tester) async {
    await tester.pumpWidget(_wrap(
      PaymentSummary(
        delivery: _delivery(discountAmount: 500, totalAmount: 1500),
      ),
    ));
    expect(find.text('Discount'), findsOneWidget);
    expect(find.text('-TZS 500'), findsOneWidget);
  });

  testWidgets('does NOT show discount when discountAmount is 0',
      (tester) async {
    await tester.pumpWidget(_wrap(PaymentSummary(delivery: _delivery())));
    expect(find.text('Discount'), findsNothing);
    expect(find.textContaining('-TZS'), findsNothing);
  });

  testWidgets('shows "Calculating fee…" when odsDeliveryFee is null',
      (tester) async {
    await tester.pumpWidget(_wrap(
      PaymentSummary(delivery: _delivery(odsDeliveryFee: null, totalAmount: null)),
    ));
    expect(find.text('Calculating fee…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Fee breakdown'), findsNothing);
  });

  testWidgets('regional with discount shows all four rows', (tester) async {
    await tester.pumpWidget(_wrap(
      PaymentSummary(
        delivery: _delivery(
          serviceType: ServiceType.regional,
          odsDeliveryFee: 2000,
          busCargoFare: 3500,
          discountAmount: 1000,
          discountReason: '50% off ODS fee',
          totalAmount: 4500,
        ),
      ),
    ));
    expect(find.text('ODS delivery fee'), findsOneWidget);
    expect(find.text('Bus / cargo fare'), findsOneWidget);
    expect(find.text('50% off ODS fee'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('TZS 4500'), findsOneWidget);
  });
}