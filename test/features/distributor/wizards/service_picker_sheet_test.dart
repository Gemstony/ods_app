import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ods_app/features/distributor/presentation/wizards/widgets/service_picker_sheet.dart';

void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Host app that captures whatever ServicePickerSheet pops back.
class _PickerHost extends StatefulWidget {
  const _PickerHost({required this.onResult});
  final void Function(DeliveryServiceChoice?) onResult;

  @override
  State<_PickerHost> createState() => _PickerHostState();
}

class _PickerHostState extends State<_PickerHost> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final result = await ServicePickerSheet.show(context);
            widget.onResult(result);
          },
          child: const Text('Open picker'),
        ),
      ),
    );
  }
}

Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.text('Open picker'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('renders Receive, Send, and Regional cards',
      (tester) async {
    _useLargeViewport(tester);
    DeliveryServiceChoice? captured;
    await tester.pumpWidget(MaterialApp(
      home: _PickerHost(onResult: (r) => captured = r),
    ));
    await _openPicker(tester);

    expect(find.text('New delivery'), findsOneWidget);
    expect(find.text('Receive'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Regional'), findsOneWidget);
    expect(captured, isNull); // no selection yet
  });

  testWidgets('tapping Receive returns DeliveryServiceChoice.receive',
      (tester) async {
    _useLargeViewport(tester);
    DeliveryServiceChoice? captured;
    await tester.pumpWidget(MaterialApp(
      home: _PickerHost(onResult: (r) => captured = r),
    ));
    await _openPicker(tester);

    await tester.tap(find.text('Receive'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(captured, DeliveryServiceChoice.receive);
  });

  testWidgets('tapping Send returns DeliveryServiceChoice.send',
      (tester) async {
    _useLargeViewport(tester);
    DeliveryServiceChoice? captured;
    await tester.pumpWidget(MaterialApp(
      home: _PickerHost(onResult: (r) => captured = r),
    ));
    await _openPicker(tester);

    await tester.tap(find.text('Send'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(captured, DeliveryServiceChoice.send);
  });

  testWidgets('tapping Regional returns DeliveryServiceChoice.regional',
      (tester) async {
    _useLargeViewport(tester);
    DeliveryServiceChoice? captured;
    await tester.pumpWidget(MaterialApp(
      home: _PickerHost(onResult: (r) => captured = r),
    ));
    await _openPicker(tester);

    await tester.tap(find.text('Regional'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(captured, DeliveryServiceChoice.regional);
  });

  testWidgets('dismissing the sheet returns null', (tester) async {
    _useLargeViewport(tester);
    DeliveryServiceChoice? captured;
    var called = false;
    await tester.pumpWidget(MaterialApp(
      home: _PickerHost(onResult: (r) {
        captured = r;
        called = true;
      }),
    ));
    await _openPicker(tester);

    // Barrier tap to dismiss.
    await tester.tapAt(const Offset(400, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(called, isTrue);
    expect(captured, isNull);
  });
}