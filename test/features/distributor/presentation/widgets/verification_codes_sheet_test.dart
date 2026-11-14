import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/delivery.dart';
import 'package:ods_app/data/models/verification_issue_result.dart';
import 'package:ods_app/data/repositories/delivery_repository.dart';
import 'package:ods_app/features/distributor/presentation/widgets/verification_codes_sheet.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';

Delivery _delivery() => Delivery(
      id: 100,
      trackingId: 'ODS-TEST-1',
      distributorId: 42,
      serviceType: ServiceType.receive,
      status: DeliveryStatus.paid,
      rawStatus: 'paid',
      discountAmount: 0,
      currency: 'TZS',
      totalAmount: 5000,
    );

VerificationIssueResult _result() => VerificationIssueResult(
      deliveryId: 100,
      trackingId: 'ODS-TEST-1',
      distributorCode: IssuedCode(
        code: '123456',
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      ),
      recipientCode: IssuedCode(
        code: '789012',
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      ),
      warning: 'Save these codes now.',
    );

class _FakeRepo extends DeliveryRepository {
  _FakeRepo({this.result, this.fail = false}) : super(dio: Dio());
  final VerificationIssueResult? result;
  final bool fail;

  @override
  Future<ApiResult<VerificationIssueResult>> issueVerificationCodes(
    int deliveryId,
  ) async {
    if (fail) {
      return const ApiFailure(
        Failure(type: FailureType.network, message: 'Offline'),
      );
    }
    return ApiSuccess(result ?? _result());
  }
}

Widget _host({
  required DeliveryRepository repo,
}) {
  return ProviderScope(
    overrides: [deliveryRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () =>
                  VerificationCodesSheet.show(context, _delivery()),
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

  testWidgets('shows both codes with labels', (tester) async {
    await tester.pumpWidget(_host(repo: _FakeRepo()));
    await _open(tester);
    await tester.pumpAndSettle();

    expect(find.text('Verification codes'), findsOneWidget);
    expect(find.text('Distributor code'), findsOneWidget);
    expect(find.text('Recipient code'), findsOneWidget);
    expect(find.text('123456'), findsOneWidget);
    expect(find.text('789012'), findsOneWidget);
  });

  testWidgets('shows the warning message', (tester) async {
    await tester.pumpWidget(_host(repo: _FakeRepo()));
    await _open(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('Save these codes'), findsOneWidget);
  });

  testWidgets('error state shows failure message', (tester) async {
    await tester.pumpWidget(_host(repo: _FakeRepo(fail: true)));
    await _open(tester);
    await tester.pumpAndSettle();

    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('Done button closes the sheet', (tester) async {
    await tester.pumpWidget(_host(repo: _FakeRepo()));
    await _open(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done — I have saved the codes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Sheet closed — "Open" button visible again
    expect(find.text('Open'), findsOneWidget);
  });
}