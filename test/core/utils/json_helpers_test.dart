import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/utils/json_helpers.dart';

void main() {
  group('asInt', () {
    test('accepts int', () => expect(asInt(42), 42));
    test('accepts double (truncates)', () => expect(asInt(42.9), 42));
    test('accepts numeric string', () => expect(asInt('42'), 42));
    test('throws on garbage', () {
      expect(() => asInt('not-a-number'), throwsFormatException);
      expect(() => asInt(null), throwsFormatException);
      expect(() => asInt({'a': 1}), throwsFormatException);
    });
  });

  group('asDouble', () {
    test('accepts double', () => expect(asDouble(42.5), 42.5));
    test('widens int to double', () => expect(asDouble(42), 42.0));
    test('accepts numeric string', () => expect(asDouble('42.5'), 42.5));
    test('throws on garbage', () {
      expect(() => asDouble('not-a-number'), throwsFormatException);
      expect(() => asDouble(null), throwsFormatException);
    });
  });

  group('asBool', () {
    test('accepts true / false', () {
      expect(asBool(true), isTrue);
      expect(asBool(false), isFalse);
    });
    test('accepts 1 / 0', () {
      expect(asBool(1), isTrue);
      expect(asBool(0), isFalse);
    });
    test('accepts "true" / "false"', () {
      expect(asBool('true'), isTrue);
      expect(asBool('false'), isFalse);
    });
    test('throws on garbage', () {
      expect(() => asBool('yes'), throwsFormatException);
      expect(() => asBool(2), throwsFormatException);
    });
  });

  group('parseDate', () {
    test('returns null for null', () => expect(parseDate(null), isNull));
    test('parses ISO string', () {
      final d = parseDate('2026-10-24T07:30:00+00:00');
      expect(d, isNotNull);
      expect(d!.year, 2026);
    });
    test('returns null on garbage', () {
      expect(parseDate('not-a-date'), isNull);
    });
    test('passes through existing DateTime', () {
      final now = DateTime.now();
      expect(parseDate(now), same(now));
    });
  });

  group('asMap', () {
    test('returns null for null', () => expect(asMap(null), isNull));
    test('returns null for non-map', () => expect(asMap('str'), isNull));
    test('converts Map into Map<String, dynamic>', () {
      final result = asMap({'a': 1, 'b': 'two'});
      expect(result, {'a': 1, 'b': 'two'});
    });
  });

  group('asList', () {
    test('returns null for non-list', () {
      expect(asList<int>(null, (j) => asInt(j['v'])), isNull);
      expect(asList<int>('not-list', (j) => asInt(j['v'])), isNull);
    });
    test('parses each item using callback', () {
      final raw = [
        {'v': 1},
        {'v': 2},
        {'v': 3},
      ];
      final parsed = asList<int>(raw, (j) => asInt(j['v']));
      expect(parsed, [1, 2, 3]);
    });
    test('skips non-map entries', () {
      final raw = [
        {'v': 1},
        'not-a-map',
        {'v': 2},
      ];
      final parsed = asList<int>(raw, (j) => asInt(j['v']));
      expect(parsed, [1, 2]);
    });
  });
}