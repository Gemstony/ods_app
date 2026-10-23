import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/widgets/app_text_field.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
    );

void main() {
  group('AppTextField — basics', () {
    testWidgets('renders label and hint', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppTextField(label: 'Email', hint: 'you@example.com'),
      ));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('you@example.com'), findsOneWidget);
    });

    testWidgets('typing updates controller', (tester) async {
      final c = TextEditingController();
      await tester.pumpWidget(_wrap(
        AppTextField(controller: c, label: 'Name'),
      ));
      await tester.enterText(find.byType(TextFormField), 'Ahmed');
      expect(c.text, 'Ahmed');
    });
  });

  group('AppTextField — password visibility', () {
    testWidgets('shows toggle when obscureText and can reveal',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const AppTextField(label: 'Password', obscureText: true),
      ));

      // Initially obscured, eye closed icon visible.
      var field = tester.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isTrue);
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);

      // Tap toggle → reveals.
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();
      field = tester.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isFalse);
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('no toggle when showPasswordToggle=false', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppTextField(
          label: 'PIN',
          obscureText: true,
          showPasswordToggle: false,
        ),
      ));
      expect(find.byIcon(Icons.visibility_off), findsNothing);
      expect(find.byIcon(Icons.visibility), findsNothing);
    });
  });

  group('AppTextField — validation', () {
    testWidgets('validator surfaces error inside Form', (tester) async {
      final key = GlobalKey<FormState>();
      await tester.pumpWidget(_wrap(Form(
        key: key,
        child: AppTextField(
          label: 'Email',
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Email is required.' : null,
        ),
      )));

      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Email is required.'), findsOneWidget);
    });
  });

  group('AppTextField — disabled', () {
    testWidgets('enabled=false disables the field', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppTextField(label: 'Locked', enabled: false),
      ));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
    });
  });
}