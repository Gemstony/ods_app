import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/app.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/theme/app_colors.dart';

void main() {
  testWidgets('app boots and shows the ODS boot screen', (tester) async {
    AppConfig.initialize();
    await tester.pumpWidget(const OdsApp());

    // "ODS" renders twice on purpose: in the AppBar title and as the
    // large body heading. findsWidgets = "one or more", which is correct.
    expect(find.text('ODS'), findsWidgets);

    // These appear exactly once.
    expect(find.text('Zero Distance Services'), findsOneWidget);
    expect(find.text(AppConfig.environment.name), findsOneWidget);
    expect(find.text(AppConfig.apiBaseUrl), findsOneWidget);
  });

  testWidgets('ODS theme is applied to the widget tree', (tester) async {
    AppConfig.initialize();
    await tester.pumpWidget(const OdsApp());

    final scaffoldContext = tester.element(find.byType(Scaffold));
    final theme = Theme.of(scaffoldContext);

    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.colorScheme.secondary, AppColors.accent);
    expect(theme.scaffoldBackgroundColor, AppColors.surface);
    expect(theme.useMaterial3, isTrue);
  });

  testWidgets('"Test API connection" button is present and tappable',
      (tester) async {
    AppConfig.initialize();
    await tester.pumpWidget(const OdsApp());

    final button = find.widgetWithText(ElevatedButton, 'Test API connection');
    expect(button, findsOneWidget);

    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump(); // triggers setState(_checking = true)
    await tester.pump(const Duration(milliseconds: 100));
    // Don't await the network — just verify the button exists and reacted.
    // The result assertion is out of scope for a smoke test.
  });
}