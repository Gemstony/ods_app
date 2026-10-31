import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/data/models/delivery.dart';
import 'package:ods_app/widgets/delivery_status_chip.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('renders a chip for every DeliveryStatus without throwing',
      (tester) async {
    for (final status in DeliveryStatus.values) {
      await tester.pumpWidget(_wrap(DeliveryStatusChip(status: status)));
      expect(find.byType(DeliveryStatusChip), findsOneWidget,
          reason: 'Failed for status ${status.name}');
    }
  });

  testWidgets('shows the status displayLabel', (tester) async {
    await tester.pumpWidget(
      _wrap(const DeliveryStatusChip(status: DeliveryStatus.pending_payment)),
    );
    expect(find.text('Awaiting payment'), findsOneWidget);
  });

  testWidgets('delivered status shows Delivered label', (tester) async {
    await tester.pumpWidget(
      _wrap(const DeliveryStatusChip(status: DeliveryStatus.delivered)),
    );
    expect(find.text('Delivered'), findsOneWidget);
  });

  testWidgets('unknown status shows Unknown label without crashing',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const DeliveryStatusChip(status: DeliveryStatus.unknown)),
    );
    expect(find.text('Unknown'), findsOneWidget);
  });

  testWidgets('compact mode works', (tester) async {
    await tester.pumpWidget(
      _wrap(const DeliveryStatusChip(
        status: DeliveryStatus.assigned,
        isCompact: true,
      )),
    );
    expect(find.text('Rider assigned'), findsOneWidget);
  });

  testWidgets('custom icon renders alongside the label', (tester) async {
    await tester.pumpWidget(
      _wrap(const DeliveryStatusChip(
        status: DeliveryStatus.delivered,
        icon: Icons.check_circle,
      )),
    );
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
  });
}