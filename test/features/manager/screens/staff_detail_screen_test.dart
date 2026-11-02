import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/auth/auth_user.dart';
import 'package:ods_app/data/repositories/staff_repository.dart';
import 'package:ods_app/features/manager/presentation/screens/staff_detail_screen.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';

void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

AuthUser _user({
  String role = 'receiver',
  String status = 'active',
  String? nida,
}) =>
    AuthUser(
      id: 42,
      name: 'Test Staff',
      email: 'staff@ods.test',
      phone: '0712345678',
      role: role,
      status: status,
      dispatcherEnabled: role == 'receiver',
      nida: nida,
      permissions: const [],
    );

class _FakeRepo extends StaffRepository {
  _FakeRepo({this.user}) : super(dio: Dio());
  final AuthUser? user;

  @override
  Future<ApiResult<AuthUser>> get(int id) async {
    if (user == null) {
      return ApiFailure(const Failure(
        type: FailureType.notFound,
        message: 'Not found',
      ));
    }
    return ApiSuccess(user!);
  }
}

Widget _wrap(StaffRepository repo) => ProviderScope(
      overrides: [staffRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const StaffDetailScreen(staffId: 42),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  testWidgets('renders staff info', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(_FakeRepo(user: _user())));
    await tester.pumpAndSettle();

    expect(find.text('Test Staff'), findsWidgets);
    expect(find.text('staff@ods.test'), findsOneWidget);
    expect(find.text('receiver'), findsOneWidget);
  });

  testWidgets('active user shows Suspend button', (tester) async {
    _useLargeViewport(tester);
    await tester
        .pumpWidget(_wrap(_FakeRepo(user: _user(status: 'active'))));
    await tester.pumpAndSettle();

    expect(find.text('Suspend account'), findsOneWidget);
    expect(find.text('Reactivate account'), findsNothing);
  });

  testWidgets('suspended user shows Reactivate button', (tester) async {
    _useLargeViewport(tester);
    await tester
        .pumpWidget(_wrap(_FakeRepo(user: _user(status: 'suspended'))));
    await tester.pumpAndSettle();

    expect(find.text('Reactivate account'), findsOneWidget);
    expect(find.text('Suspend account'), findsNothing);
  });

  testWidgets('rider shows rider details', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(_FakeRepo(
      user: _user(role: 'rider', nida: '19900101123456789012'),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Rider details'), findsOneWidget);
    expect(find.text('19900101123456789012'), findsOneWidget);
  });

  testWidgets('reset password dialog opens', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(_FakeRepo(user: _user())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reset password'));
    await tester.pumpAndSettle();

    expect(find.text('New password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Reset'), findsOneWidget);
  });
}