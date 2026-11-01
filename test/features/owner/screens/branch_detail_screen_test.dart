import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/branch.dart';
import 'package:ods_app/data/models/branch_manager_assignment.dart';
import 'package:ods_app/data/repositories/branch_repository.dart';
import 'package:ods_app/features/owner/presentation/screens/branch_detail_screen.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';

Branch _branch() => const Branch(
      id: 1,
      name: 'Test Branch',
      code: 'TST-1',
      address: '1 Street',
      latitude: -6.79,
      longitude: 39.20,
      status: BranchStatus.active,
    );

class _FakeRepo extends BranchRepository {
  _FakeRepo({this.branch, this.history = const []}) : super(dio: Dio());
  final Branch? branch;
  final List<BranchManagerAssignment> history;

  @override
  Future<ApiResult<Branch>> get(int id) async =>
      branch != null ? ApiSuccess(branch!) : ApiFailure(const Failure(type: FailureType.notFound, message: 'Not found'));

  @override
  Future<ApiResult<List<BranchManagerAssignment>>> getManagerHistory(
          int branchId) async =>
      ApiSuccess(history);
}

Widget _wrap(BranchRepository repo) => ProviderScope(
      overrides: [branchRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const BranchDetailScreen(branchId: 1),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  testWidgets('renders branch info', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(branch: _branch())));
    await tester.pumpAndSettle();

    expect(find.text('Test Branch'), findsWidgets);
    expect(find.text('TST-1'), findsOneWidget);
    expect(find.text('1 Street'), findsOneWidget);
  });

  testWidgets('shows "No manager assigned" when history empty',
      (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(branch: _branch())));
    await tester.pumpAndSettle();

    expect(find.text('No manager assigned'), findsOneWidget);
  });

  testWidgets('shows current manager when active assignment exists',
      (tester) async {
    final history = [
      const BranchManagerAssignment(
        id: 1,
        userId: 5,
        userName: 'Jane Manager',
        userEmail: 'jane@ods.test',
        isActive: true,
      ),
    ];
    await tester.pumpWidget(_wrap(_FakeRepo(branch: _branch(), history: history)));
    await tester.pumpAndSettle();

    expect(find.text('Jane Manager'), findsOneWidget);
    expect(find.text('jane@ods.test'), findsOneWidget);
  });

  testWidgets('shows history rows when more than one assignment',
      (tester) async {
    final history = [
      const BranchManagerAssignment(
        id: 2,
        userId: 6,
        userName: 'Current Mgr',
        userEmail: 'c@ods.test',
        isActive: true,
      ),
      const BranchManagerAssignment(
        id: 1,
        userId: 5,
        userName: 'Past Mgr',
        userEmail: 'p@ods.test',
        isActive: false,
      ),
    ];
    await tester.pumpWidget(
        _wrap(_FakeRepo(branch: _branch(), history: history)));
    await tester.pumpAndSettle();

    expect(find.text('Assignment history'), findsOneWidget);
    expect(find.text('Current Mgr'), findsWidgets);
    expect(find.text('Past Mgr'), findsOneWidget);
  });
}