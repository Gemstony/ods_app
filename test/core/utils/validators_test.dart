import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/utils/validators.dart';

void main() {
  group('required', () {
    test('returns error on null', () {
      expect(Validators.required(null), isNotNull);
    });
    test('returns error on empty', () {
      expect(Validators.required(''), isNotNull);
    });
    test('returns error on whitespace-only', () {
      expect(Validators.required('   '), isNotNull);
    });
    test('passes on real value', () {
      expect(Validators.required('abc'), isNull);
    });
  });

  group('email', () {
    for (final ok in [
      'a@b.co',
      'user.name@domain.co.tz',
      'user+tag@sub.domain.com',
    ]) {
      test('accepts $ok', () => expect(Validators.email(ok), isNull));
    }
    for (final bad in ['', 'not-an-email', 'a@b', '@b.co', 'a@.co']) {
      test('rejects "$bad"', () => expect(Validators.email(bad), isNotNull));
    }
  });

  group('phone (Tanzania)', () {
    for (final ok in [
      '0712345678',
      '0755123456',
      '0655123456',
      '+255712345678',
      '255712345678',
      '0712 345 678'
    ]) {
      test('accepts $ok', () => expect(Validators.phone(ok), isNull));
    }
    for (final bad in ['0712345', '0212345678', '1234567890', '+1 555 0100']) {
      test('rejects "$bad"', () => expect(Validators.phone(bad), isNotNull));
    }
  });

  group('nida', () {
    test('accepts 20 digits', () {
      expect(Validators.nida('12345678901234567890'), isNull);
    });
    test('rejects 19 digits', () {
      expect(Validators.nida('1234567890123456789'), isNotNull);
    });
    test('rejects letters', () {
      expect(Validators.nida('1234567890123456789a'), isNotNull);
    });
  });

  group('plateNumber', () {
    for (final ok in ['ABC123', 'T123ABC', 'abc123d']) {
      test('accepts $ok', () => expect(Validators.plateNumber(ok), isNull));
    }
    for (final bad in ['', '123', 'ABCDEFG', 'T1234']) {
      test('rejects "$bad"',
          () => expect(Validators.plateNumber(bad), isNotNull));
    }
  });

  group('password', () {
    test('rejects short', () {
      expect(Validators.password('abc'), isNotNull);
    });
    test('accepts 8+', () {
      expect(Validators.password('abcdefgh'), isNull);
    });
    test('confirmPassword matches', () {
      expect(Validators.confirmPassword('a', 'a'), isNull);
    });
    test('confirmPassword mismatch', () {
      expect(Validators.confirmPassword('a', 'b'), isNotNull);
    });
  });
}
