import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/errors/app_exception.dart';
import 'package:ods_app/core/errors/failure.dart';

void main() {
  group('Failure.fromException — type mapping', () {
    test('network → network failure with retryable message', () {
      final f = Failure.fromException(AppException.network(code: 'TIMEOUT'));
      expect(f.type, FailureType.network);
      expect(f.code, 'TIMEOUT');
      expect(f.message.toLowerCase(), contains('internet'));
      expect(f.isRetryable, isTrue);
    });

    test('server does not leak internal message', () {
      final f = Failure.fromException(
        AppException.server(message: 'SQL error in users table'),
      );
      expect(f.type, FailureType.server);
      expect(f.message, isNot(contains('SQL')));
      expect(f.message, isNot(contains('users')));
      expect(f.isRetryable, isTrue);
    });

    test('client passes message through', () {
      final f = Failure.fromException(
        AppException.client(message: 'Invalid request payload'),
      );
      expect(f.type, FailureType.client);
      expect(f.message, 'Invalid request payload');
      expect(f.isRetryable, isFalse);
    });

    test('auth → auth failure, not retryable', () {
      final f = Failure.fromException(AppException.auth());
      expect(f.type, FailureType.auth);
      expect(f.isAuthError, isTrue);
      expect(f.isRetryable, isFalse);
    });

    test('validation → preserves fieldErrors and message', () {
      final f = Failure.fromException(
        AppException.validation(
          message: 'The email field is required',
          fieldErrors: {
            'email': ['The email field is required.'],
          },
        ),
      );
      expect(f.type, FailureType.validation);
      expect(f.isValidation, isTrue);
      expect(f.message, 'The email field is required');
      expect(f.fieldErrors['email'], contains('The email field is required.'));
    });

    test('notFound → passes message through', () {
      final f = Failure.fromException(
        AppException.notFound(message: 'Delivery not found'),
      );
      expect(f.type, FailureType.notFound);
      expect(f.message, 'Delivery not found');
    });

    test('parsing → treated as server (never leaks) ', () {
      final f = Failure.fromException(
        AppException.parsing(message: 'Unexpected token at line 4'),
      );
      expect(f.type, FailureType.server);
      expect(f.message, isNot(contains('token')));
    });

    test('storage → unknown with safe message', () {
      final f = Failure.fromException(AppException.storage());
      expect(f.type, FailureType.unknown);
      expect(f.isRetryable, isFalse);
    });

    test('cancelled → cancelled, not retryable', () {
      final f = Failure.fromException(AppException.cancelled());
      expect(f.type, FailureType.cancelled);
      expect(f.isRetryable, isFalse);
    });

    test('unknown does not leak internal message', () {
      final f = Failure.fromException(
        AppException.unknown(message: 'stacktrace gibberish'),
      );
      expect(f.type, FailureType.unknown);
      expect(f.message, isNot(contains('gibberish')));
    });
  });

  group('Failure helpers', () {
    test('isRetryable true for network and server only', () {
      expect(Failure.network().isRetryable, isTrue);
      expect(Failure.server().isRetryable, isTrue);
      expect(Failure.auth().isRetryable, isFalse);
      expect(Failure.validation().isRetryable, isFalse);
      expect(Failure.unknown().isRetryable, isFalse);
    });

    test('copyWith preserves type, code, fieldErrors', () {
      const original = Failure(
        type: FailureType.validation,
        message: 'Original',
        code: 'V1',
        fieldErrors: {'name': ['required']},
      );
      final copy = original.copyWith(message: 'Updated');
      expect(copy.type, FailureType.validation);
      expect(copy.code, 'V1');
      expect(copy.fieldErrors, original.fieldErrors);
      expect(copy.message, 'Updated');
    });
  });
}