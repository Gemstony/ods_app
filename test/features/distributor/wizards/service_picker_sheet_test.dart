import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/features/distributor/presentation/wizards/widgets/service_picker_sheet.dart';

/// Host screen with a button that opens the picker and records the
/// result via [onResult].
class _SheetHost extends StatefulWidget {
  final void Function(DeliveryServiceChoice?) onResult;
  const _SheetHost({required this.onResult});

  @override
  State<_SheetHost> createState() => _SheetHostState();
}

class _SheetHostState extends State<_SheetHost> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final choice = await showServicePickerSheet(context);
            widget.onResult(choice);
          },
          child: const Text('Open picker'),
        ),
      ),
    );
  }
}

Widget _wrap({required void Function(DeliveryServiceChoice?) onResult}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: _SheetHost(onResult: onResult),
  );
}

/// Opens the picker and settles through the sheet's slide-up animation
/// using explicit pumps — no `pumpAndSettle` (defensive against any
/// hidden animation the sheet might schedule).
Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.text('Open picker'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  testWidgets('renders both service cards', (tester) async {
    DeliveryServiceChoice? result;
    await tester.pumpWidget(_wrap(onResult: (c) => result = c));

    await _openPicker(tester);

    expect(find.text('New delivery'), findsOneWidget);
    expect(find.text('Choose a service to continue.'), findsOneWidget);
    expect(find.text('Receive'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    expect(find.textContaining('pickup branch to your current location'),
        findsOneWidget);
    expect(find.textContaining('From your location to a recipient'),
        findsOneWidget);
    // Not chosen yet
    expect(result, isNull);
  });

  testWidgets('tapping Receive returns DeliveryServiceChoice.receive',
      (tester) async {
    DeliveryServiceChoice? result;
    await tester.pumpWidget(_wrap(onResult: (c) => result = c));

    await _openPicker(tester);
    await tester.tap(find.text('Receive'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(result, DeliveryServiceChoice.receive);
    // Sheet dismissed
    expect(find.text('Choose a service to continue.'), findsNothing);
  });

  testWidgets('tapping Send returns DeliveryServiceChoice.send',
      (tester) async {
    DeliveryServiceChoice? result;
    await tester.pumpWidget(_wrap(onResult: (c) => result = c));

    await _openPicker(tester);
    await tester.tap(find.text('Send'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(result, DeliveryServiceChoice.send);
    expect(find.text('Choose a service to continue.'), findsNothing);
  });

  testWidgets('dismissing the sheet returns null', (tester) async {
    var called = false;
    DeliveryServiceChoice? result;
    await tester.pumpWidget(_wrap(onResult: (c) {
      called = true;
      result = c;
    }));

    await _openPicker(tester);

    // Tap the scrim (top of the sheet) to dismiss.
    // The scrim is the outermost ModalBarrier covering the whole screen.
    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(called, isTrue);
    expect(result, isNull);
    expect(find.text('Choose a service to continue.'), findsNothing);
  });
}