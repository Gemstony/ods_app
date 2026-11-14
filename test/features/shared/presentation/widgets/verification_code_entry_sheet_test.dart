import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/delivery.dart';
import 'package:ods_app/features/shared/presentation/widgets/verification_code_entry_sheet.dart';

Delivery _delivery() => Delivery(
      id: 100,
      trackingId: 'ODS-TEST-1',
      distributorId: 42,
      serviceType: ServiceType.receive,
      status: DeliveryStatus.accepted,
      rawStatus: 'accepted',
      discountAmount: 0,
      currency: 'TZS',
      totalAmount: 5000,
    );

Widget _host({
  required Future<ApiResult<Delivery>> Function(String code) onSubmit,
  required void Function(Delivery?) onResult,
}) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await VerificationCodeEntrySheet.show(
                  context,
                  delivery: _delivery(),
                  codeType: 'distributor',
                  actionLabel: 'pickup',
                  onSubmit: onSubmit,
                );
                onResult(result);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  testWidgets('renders the code entry UI', (tester) async {
    await tester.pumpWidget(_host(
      onSubmit: (_) async => ApiSuccess(_delivery()),
      onResult: (_) {},
    ));
    await _open(tester);

    expect(find.text('Verification code required'), findsOneWidget);
    expect(find.text('ODS-TEST-1'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('successful submit pops with delivery', (tester) async {
    Delivery? captured;
    await tester.pumpWidget(_host(
      onSubmit: (_) async => ApiSuccess(_delivery()),
      onResult: (d) => captured = d,
    ));
    await _open(tester);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(captured, isNotNull);
    expect(captured!.id, 100);
  });

  testWidgets('wrong code shows inline error and keeps sheet open',
      (tester) async {
    await tester.pumpWidget(_host(
      onSubmit: (_) async => const ApiFailure(
        Failure(type: FailureType.validation, message: 'Incorrect code.'),
      ),
      onResult: (_) {},
    ));
    await _open(tester);

    await tester.enterText(find.byType(TextField), '999999');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Incorrect code.'), findsOneWidget);
    expect(find.text('Verification code required'), findsOneWidget);
  });

  testWidgets('lockout message disables retry button', (tester) async {
    await tester.pumpWidget(_host(
      onSubmit: (_) async => const ApiFailure(
        Failure(
          type: FailureType.validation,
          message: 'Too many incorrect attempts. Request a new code.',
        ),
      ),
      onResult: (_) {},
    ));
    await _open(tester);

    await tester.enterText(find.byType(TextField), '999999');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Too many'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('cancel pops null', (tester) async {
    Delivery? captured;
    bool called = false;
    await tester.pumpWidget(_host(
      onSubmit: (_) async => ApiSuccess(_delivery()),
      onResult: (d) {
        captured = d;
        called = true;
      },
    ));
    await _open(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(called, isTrue);
    expect(captured, isNull);
  });
}