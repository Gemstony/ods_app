import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/data/models/delivery.dart';
import 'package:ods_app/widgets/delivery_card.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
    );

Delivery _delivery({
  ServiceType serviceType = ServiceType.receive,
  DeliveryStatus status = DeliveryStatus.paid,
  String? destinationAddress = '456 Upanga Road',
  String? recipientName,
  String? destinationRegion,
  String? destinationDistrict,
  DateTime? createdAt,
  double? totalAmount = 2000.00,
}) {
  return Delivery(
    id: 1,
    trackingId: 'ODS-20261024-ABC123',
    distributorId: 42,
    serviceType: serviceType,
    status: status,
    rawStatus: status.name,
    discountAmount: 0,
    currency: 'TZS',
    destinationAddress: destinationAddress,
    recipientName: recipientName,
    destinationRegion: destinationRegion,
    destinationDistrict: destinationDistrict,
    totalAmount: totalAmount,
    createdAt: createdAt ?? DateTime.now().subtract(const Duration(days: 5)),
  );
}

void main() {
  testWidgets('shows tracking ID and status chip', (tester) async {
    await tester.pumpWidget(_wrap(DeliveryCard(delivery: _delivery())));
    expect(find.text('ODS-20261024-ABC123'), findsOneWidget);
    expect(find.text('Ready for pickup'), findsOneWidget);
  });

  testWidgets('Receive card shows destination address', (tester) async {
    await tester.pumpWidget(_wrap(
      DeliveryCard(
        delivery: _delivery(
          serviceType: ServiceType.receive,
          destinationAddress: '456 Upanga Road',
        ),
      ),
    ));
    expect(find.text('456 Upanga Road'), findsOneWidget);
    expect(find.text('Receive'), findsOneWidget);
  });

  testWidgets('Send card shows recipient name', (tester) async {
    await tester.pumpWidget(_wrap(
      DeliveryCard(
        delivery: _delivery(
          serviceType: ServiceType.send,
          recipientName: 'Jane Customer',
        ),
      ),
    ));
    expect(find.text('To Jane Customer'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
  });

  testWidgets('Send with showRecipient=false shows destination address',
      (tester) async {
    await tester.pumpWidget(_wrap(
      DeliveryCard(
        delivery: _delivery(
          serviceType: ServiceType.send,
          recipientName: 'Jane Customer',
          destinationAddress: '789 Kariakoo',
        ),
        showRecipient: false,
      ),
    ));
    expect(find.text('789 Kariakoo'), findsOneWidget);
    expect(find.text('To Jane Customer'), findsNothing);
  });

  testWidgets('Regional card shows region and district', (tester) async {
    await tester.pumpWidget(_wrap(
      DeliveryCard(
        delivery: _delivery(
          serviceType: ServiceType.regional,
          destinationRegion: 'Arusha',
          destinationDistrict: 'Arusha City',
        ),
      ),
    ));
    expect(find.text('Arusha · Arusha City'), findsOneWidget);
    expect(find.text('Regional'), findsOneWidget);
  });

  testWidgets('shows the fee amount', (tester) async {
    await tester.pumpWidget(_wrap(
      DeliveryCard(delivery: _delivery(totalAmount: 2000)),
    ));
    expect(find.text('TZS 2000'), findsOneWidget);
  });

  testWidgets('shows "—" when totalAmount is null', (tester) async {
    await tester.pumpWidget(_wrap(
      DeliveryCard(delivery: _delivery(totalAmount: null)),
    ));
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('onTap fires when card is tapped', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(
      DeliveryCard(
        delivery: _delivery(),
        onTap: () => taps++,
      ),
    ));
    await tester.tap(find.byType(DeliveryCard));
    expect(taps, 1);
  });

  testWidgets('trailing replaces the timestamp', (tester) async {
    await tester.pumpWidget(_wrap(
      DeliveryCard(
        delivery: _delivery(),
        trailing: const Icon(Icons.arrow_forward),
      ),
    ));
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    // Timestamp text should NOT be present
    expect(find.textContaining('ago'), findsNothing);
  });

  testWidgets('shows relative time when no trailing widget', (tester) async {
    await tester.pumpWidget(_wrap(
      DeliveryCard(
        delivery: _delivery(
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
      ),
    ));
    expect(find.text('5d ago'), findsOneWidget);
  });

  testWidgets('renders correctly for all service types', (tester) async {
    for (final service in ServiceType.values) {
      await tester.pumpWidget(_wrap(
        DeliveryCard(
          delivery: _delivery(
            serviceType: service,
            recipientName: 'X',
            destinationRegion: 'Y',
            destinationDistrict: 'Z',
          ),
        ),
      ));
      expect(find.byType(DeliveryCard), findsOneWidget);
    }
  });
}