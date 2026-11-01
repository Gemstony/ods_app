import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/auth/auth_user.dart';
import 'package:ods_app/data/repositories/user_repository.dart';
import 'package:ods_app/features/owner/presentation/screens/user_detail_screen.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';

AuthUser _user({
  String role = 'manager',
  String status = 'active',
  String? nida,
}) =>
    AuthUser(
      id: 42,
      name: 'Test User',
      email: 't@ods.test',
      phone: '0712345678',
      role: role,
      status: status,
      dispatcherEnabled: false,
      branch: const UserBranchRef(id: 1, name: 'KRK', code: 'KRK-01'),
      nida: nida,
      permissions: const [],
    );

class _FakeRepo extends UserRepository {
  _FakeRepo({this.user, this.approveResult}) : super(dio: Dio());
  final AuthUser? user;
  final ApiResult<AuthUser>? approveResult;

  @override
  Future<ApiResult<AuthUser>> get(int id) async {
    if (user == null) {
      return ApiFailure(const Failure(type: FailureType.notFound, message: 'Not found'));
    }
    return ApiSuccess(user!);
  }

  @override
  Future<ApiResult<AuthUser>> approve(int id) async =>
      approveResult ?? ApiSuccess(user!);
}

Widget _wrap(UserRepository repo) => ProviderScope(
      overrides: [userRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const UserDetailScreen(userId: 42),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  testWidgets('renders user info', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(user: _user())));
    await tester.pumpAndSettle();

    expect(find.text('Test User'), findsWidgets);
    expect(find.text('t@ods.test'), findsOneWidget);
    expect(find.text('manager'), findsOneWidget);
  });

  testWidgets('active user shows Suspend and Reset password',
      (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(user: _user(status: 'active'))));
    await tester.pumpAndSettle();

    expect(find.text('Suspend account'), findsOneWidget);
    expect(find.text('Reset password'), findsOneWidget);
    expect(find.text('Approve account'), findsNothing);
  });

  testWidgets('pending user shows Approve', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(user: _user(status: 'pending'))));
    await tester.pumpAndSettle();

    expect(find.text('Approve account'), findsOneWidget);
    expect(find.text('Suspend account'), findsNothing);
  });

  testWidgets('rider user shows rider details', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(
      user: _user(role: 'rider', nida: '19900101123456789012'),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Rider details'), findsOneWidget);
    expect(find.text('19900101123456789012'), findsOneWidget);
  });
}