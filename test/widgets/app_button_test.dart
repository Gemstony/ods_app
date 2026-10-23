import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/widgets/app_button.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('AppButton — variants', () {
    testWidgets('primary renders ElevatedButton and fires onPressed',
        (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_wrap(
        AppButton(label: 'Go', onPressed: () => tapped++),
      ));

      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('Go'), findsOneWidget);

      await tester.tap(find.byType(ElevatedButton));
      expect(tapped, 1);
    });

    testWidgets('secondary renders OutlinedButton', (tester) async {
      await tester.pumpWidget(_wrap(
        AppButton(
          label: 'Cancel',
          onPressed: () {},
          variant: AppButtonVariant.secondary,
        ),
      ));
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('text renders TextButton', (tester) async {
      await tester.pumpWidget(_wrap(
        AppButton(
          label: 'Skip',
          onPressed: () {},
          variant: AppButtonVariant.text,
        ),
      ));
      expect(find.byType(TextButton), findsOneWidget);
    });
  });

  group('AppButton — loading state', () {
    testWidgets('shows spinner and disables taps while loading',
        (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_wrap(
        AppButton(
          label: 'Save',
          onPressed: () => tapped++,
          isLoading: true,
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save'), findsNothing);

      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      await tester.pump();
      expect(tapped, 0);
    });
  });

  group('AppButton — disabled state', () {
    testWidgets('null onPressed disables the button', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppButton(label: 'Locked', onPressed: null),
      ));
      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.onPressed, isNull);
    });
  });

  group('AppButton — icon', () {
    testWidgets('renders icon when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        AppButton(
          label: 'Upload',
          icon: Icons.upload_rounded,
          onPressed: () {},
        ),
      ));
      expect(find.byIcon(Icons.upload_rounded), findsOneWidget);
    });
  });

  group('AppButton — full width', () {
    testWidgets('default is full width; isFullWidth false shrinks',
        (tester) async {
      await tester.pumpWidget(_wrap(
        AppButton(label: 'Wide', onPressed: () {}),
      ));
      final wideSize = tester.getSize(find.byType(AppButton));
      expect(wideSize.width, greaterThan(200));

      await tester.pumpWidget(_wrap(
        AppButton(
          label: 'Narrow',
          onPressed: () {},
          isFullWidth: false,
        ),
      ));
      final narrowSize = tester.getSize(find.byType(AppButton));
      expect(narrowSize.width, lessThan(200));
    });
  });
}