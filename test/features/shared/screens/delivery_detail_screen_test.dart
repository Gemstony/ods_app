import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/delivery.dart';
import 'package:ods_app/data/models/delivery_item.dart';
import 'package:ods_app/features/shared/presentation/screens/delivery_detail_screen.dart';

void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Delivery _delivery({
  ServiceType serviceType = ServiceType.receive,
  DeliveryStatus status = DeliveryStatus.paid,
  String? recipientName,
  String? recipientPhone,
  String? destinationRegion,
  List<DeliveryItem>? items,
  String? notes,
}) =>
    Delivery(
      id: 1,
      trackingId: 'ODS-20261104-ABC123',
      distributorId: 42,
      serviceType: serviceType,
      status: status,
      rawStatus: status.name,
      discountAmount: 0,
      currency: 'TZS',
      totalAmount: 2000,
      odsDeliveryFee: 2000,
      pickupAddress: '123 Kariakoo',
      destinationAddress: '456 Upanga',
      destinationRegion: destinationRegion,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
      items: items,
      notes: notes,
      createdAt: DateTime(2026, 11, 4, 10, 0),
    );

Widget _wrap(Widget screen) =>
    MaterialApp(theme: AppTheme.light, home: screen);

void main() {
  testWidgets('renders header with tracking ID and status', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(
      DeliveryDetailScreen(delivery: _delivery()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ODS-20261104-ABC123'), findsWidgets);
    expect(find.text('Ready for pickup'), findsWidgets);
    expect(find.text('Receive'), findsOneWidget);
  });

  testWidgets('renders route section', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(
      DeliveryDetailScreen(delivery: _delivery()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Route'), findsOneWidget);
    expect(find.text('123 Kariakoo'), findsOneWidget);
    expect(find.text('456 Upanga'), findsOneWidget);
  });

  testWidgets('recipient section only shown for Send/Regional',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(
      DeliveryDetailScreen(
        delivery: _delivery(
          serviceType: ServiceType.send,
          recipientName: 'Jane Doe',
          recipientPhone: '0755123456',
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Recipient'), findsOneWidget);
    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('0755123456'), findsOneWidget);
  });

  testWidgets('items section renders when items present', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(
      DeliveryDetailScreen(
        delivery: _delivery(items: const [
          DeliveryItem(
            id: 1,
            deliveryId: 1,
            sortOrder: 0,
            productName: 'Salmon Oil',
            productCode: 'SLM-001',
            quantity: 2,
          ),
        ]),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Items'), findsOneWidget);
    expect(find.text('2 × Salmon Oil'), findsOneWidget);
    expect(find.text('SLM-001'), findsOneWidget);
  });

  testWidgets('regional delivery shows bus stop', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(
      DeliveryDetailScreen(
        delivery: Delivery(
          id: 1,
          trackingId: 'ODS-REG',
          distributorId: 42,
          serviceType: ServiceType.regional,
          status: DeliveryStatus.paid,
          rawStatus: 'paid',
          discountAmount: 0,
          currency: 'TZS',
          destinationRegion: 'Arusha',
          destinationDistrict: 'Arusha City',
          destinationBusStop: 'Nairobi Road',
          odsDeliveryFee: 2000,
          busCargoFare: 3500,
          totalAmount: 5500,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Nairobi Road'), findsOneWidget);
    expect(find.text('Arusha · Arusha City'), findsOneWidget);
  });

  testWidgets('extra sections rendered when provided', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(
      DeliveryDetailScreen(
        delivery: _delivery(),
        extraSections: const [
          Card(child: Padding(padding: EdgeInsets.all(8), child: Text('Extra A'))),
          Card(child: Padding(padding: EdgeInsets.all(8), child: Text('Extra B'))),
        ],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Extra A'), findsOneWidget);
    expect(find.text('Extra B'), findsOneWidget);
  });

  testWidgets('notes section rendered when provided', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(
      DeliveryDetailScreen(delivery: _delivery(notes: 'Handle with care')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Handle with care'), findsOneWidget);
  });
}