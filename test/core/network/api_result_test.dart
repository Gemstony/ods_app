import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/errors/app_exception.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';

void main() {
  const failure = Failure(type: FailureType.server, message: 'Server error');

  group('ApiSuccess', () {
    const ApiResult<int> result = ApiSuccess<int>(42);

    test('reports success', () {
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
    });

    test('exposes data, not failure', () {
      expect(result.dataOrNull, 42);
      expect(result.failureOrNull, isNull);
    });

    test('fold invokes onSuccess', () {
      final out = result.fold(
        onSuccess: (v) => 'ok:$v',
        onFailure: (_) => 'fail',
      );
      expect(out, 'ok:42');
    });
  });

  group('ApiFailure', () {
    const ApiResult<int> result = ApiFailure<int>(failure);

    test('reports failure', () {
      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
    });

    test('exposes failure, not data', () {
      expect(result.dataOrNull, isNull);
      expect(result.failureOrNull, failure);
    });

    test('fold invokes onFailure', () {
      final out = result.fold(
        onSuccess: (_) => 'ok',
        onFailure: (f) => 'fail:${f.type.name}',
      );
      expect(out, 'fail:server');
    });
  });

  group('ApiResult.guard', () {
    test('success path wraps into ApiSuccess', () async {
      final result = await ApiResult.guard<int>(() async => 7);
      expect(result, isA<ApiSuccess<int>>());
      expect(result.dataOrNull, 7);
    });

    test('AppException maps to matching Failure', () async {
      final result = await ApiResult.guard<int>(() async {
        throw AppException.validation(
          message: 'The email field is required',
          fieldErrors: {
            'email': ['required'],
          },
        );
      });

      expect(result, isA<ApiFailure<int>>());
      final f = result.failureOrNull!;
      expect(f.type, FailureType.validation);
      expect(f.fieldErrors['email'], contains('required'));
    });

    test('non-AppException wraps into unknown failure', () async {
      final result = await ApiResult.guard<int>(() async {
        throw StateError('boom');
      });
      expect(result, isA<ApiFailure<int>>());
      expect(result.failureOrNull!.type, FailureType.unknown);
    });

    test('sync throw inside async block is captured', () async {
      final result = await ApiResult.guard<int>(() async {
        throw ArgumentError('bad');
      });
      expect(result, isA<ApiFailure<int>>());
    });
  });
}