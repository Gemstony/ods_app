import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/branch.dart';
import 'package:ods_app/data/repositories/branch_repository.dart';
import 'package:ods_app/features/owner/presentation/screens/owner_branches_tab.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';
import 'package:ods_app/widgets/widgets.dart';

Branch _branch(int id) => Branch(
      id: id,
      name: 'Branch $id',
      code: 'BR-$id',
      address: 'Address of branch $id',
      latitude: -6.79,
      longitude: 39.20,
      status: BranchStatus.active,
    );

class _FakeRepo extends BranchRepository {
  _FakeRepo(this._result) : super(dio: Dio());
  final ApiResult<List<Branch>> _result;

  @override
  Future<ApiResult<List<Branch>>> list({BranchStatus? status}) async =>
      _result;
}

/// Repository that never completes — keeps the provider in loading state
/// without leaving a pending Timer (a `Future.delayed` would leave one,
/// tripping the framework's teardown assertion).
class _PendingRepo extends BranchRepository {
  _PendingRepo() : super(dio: Dio());
  final _completer = Completer<ApiResult<List<Branch>>>();

  @override
  Future<ApiResult<List<Branch>>> list({BranchStatus? status}) =>
      _completer.future;
}

Widget _wrap(BranchRepository repo) => ProviderScope(
      overrides: [branchRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: OwnerBranchesTab()),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  testWidgets('shows empty state when no branches', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(ApiSuccess(const []))));
    await tester.pumpAndSettle();

    expect(find.text('No branches yet'), findsOneWidget);
    expect(
      find.widgetWithText(ElevatedButton, 'Add first branch'),
      findsOneWidget,
    );
  });

  testWidgets('shows loading state before data arrives', (tester) async {
    await tester.pumpWidget(_wrap(_PendingRepo()));
    await tester.pump();

    expect(find.byType(LoadingView), findsOneWidget);
    // No pumpAndSettle — the completer never resolves. Clean teardown
    // because no Timer was ever created.
  });

  testWidgets('renders branch cards when data present', (tester) async {
    await tester.pumpWidget(
      _wrap(_FakeRepo(ApiSuccess([_branch(1), _branch(2)]))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Branch 1'), findsOneWidget);
    expect(find.text('Branch 2'), findsOneWidget);
    expect(find.text('BR-1'), findsOneWidget);
    expect(find.text('BR-2'), findsOneWidget);
  });

  testWidgets('error state shows retry button', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _FakeRepo(
          ApiFailure(
            const Failure(
              type: FailureType.network,
              message: 'Offline',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}