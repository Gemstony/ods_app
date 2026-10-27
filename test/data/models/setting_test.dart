import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/data/models/setting.dart';

Map<String, dynamic> _settingJson(String key, dynamic value,
    {String category = 'general', bool isPublic = false}) =>
    {
      'id': 1,
      'key': key,
      'value': value,
      'category': category,
      'description': 'A setting',
      'is_public': isPublic,
      'updated_by': null,
      'created_at': '2026-10-24T07:00:00+00:00',
      'updated_at': '2026-10-24T07:00:00+00:00',
    };

void main() {
  group('Setting.fromJson', () {
    test('parses core fields', () {
      final s = Setting.fromJson(
        _settingJson('batching.window_minutes', 20, category: 'batching'),
      );
      expect(s.id, 1);
      expect(s.key, 'batching.window_minutes');
      expect(s.category, 'batching');
      expect(s.isPublic, isFalse);
    });

    test('parses is_public true', () {
      final s = Setting.fromJson(
        _settingJson('app.app_name', 'ODS',
            category: 'app', isPublic: true),
      );
      expect(s.isPublic, isTrue);
    });
  });

  group('Setting typed getters', () {
    test('asInt works for int value', () {
      final s = Setting.fromJson(_settingJson('k', 20));
      expect(s.asInt, 20);
    });

    test('asInt converts double to int', () {
      final s = Setting.fromJson(_settingJson('k', 20.0));
      expect(s.asInt, 20);
    });

    test('asDouble works for int value', () {
      final s = Setting.fromJson(_settingJson('k', 5));
      expect(s.asDouble, 5.0);
    });

    test('asDouble works for double value', () {
      final s = Setting.fromJson(_settingJson('k', 5.5));
      expect(s.asDouble, 5.5);
    });

    test('asBool works for bool value', () {
      expect(Setting.fromJson(_settingJson('k', true)).asBool, isTrue);
      expect(Setting.fromJson(_settingJson('k', false)).asBool, isFalse);
    });

    test('asString works for String value', () {
      final s = Setting.fromJson(_settingJson('k', 'weekly'));
      expect(s.asString, 'weekly');
    });

    test('asStringList works for array of strings', () {
      final s = Setting.fromJson(
        _settingJson('k', ['fuel', 'salary', 'rent']),
      );
      expect(s.asStringList, ['fuel', 'salary', 'rent']);
    });

    test('asInt throws when value is a String', () {
      final s = Setting.fromJson(_settingJson('k', 'not-a-number'));
      expect(() => s.asInt, throwsA(anything));
    });

    test('asBool throws when value is a String', () {
      final s = Setting.fromJson(_settingJson('k', 'true'));
      expect(() => s.asBool, throwsA(anything));
    });
  });

  group('Setting.displayValue', () {
    test('renders null as em-dash', () {
      expect(Setting.fromJson(_settingJson('k', null)).displayValue, '—');
    });
    test('renders scalar values', () {
      expect(Setting.fromJson(_settingJson('k', 20)).displayValue, '20');
      expect(Setting.fromJson(_settingJson('k', true)).displayValue, 'true');
      expect(Setting.fromJson(_settingJson('k', 'weekly')).displayValue, 'weekly');
    });
    test('renders list values joined', () {
      final s = Setting.fromJson(_settingJson('k', ['a', 'b', 'c']));
      expect(s.displayValue, 'a, b, c');
    });
  });

  group('Setting round-trip', () {
    test('fromJson → toJson → fromJson preserves value and metadata', () {
      final original = Setting.fromJson(
        _settingJson('batching.window_minutes', 20,
            category: 'batching', isPublic: false),
      );
      final roundtripped = Setting.fromJson(original.toJson());

      expect(roundtripped.key, original.key);
      expect(roundtripped.value, original.value);
      expect(roundtripped.category, original.category);
      expect(roundtripped.isPublic, original.isPublic);
    });
  });
}