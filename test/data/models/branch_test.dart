import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/data/models/branch.dart';

Map<String, dynamic> _fullJson() => {
      'id': 1,
      'name': 'Dar es Salaam Central',
      'code': 'DSM-01',
      'address': '123 Kariakoo Street, Dar es Salaam',
      'latitude': -6.7924,
      'longitude': 39.2083,
      'operating_hours': {
        'monday': {'open': '08:00', 'close': '18:00'},
        'sunday': null,
      },
      'status': 'active',
      'created_by': 42,
      'created_at': '2026-10-24T07:00:00+00:00',
      'updated_at': '2026-10-24T07:00:00+00:00',
      'deleted_at': null,
    };

void main() {
  group('Branch.fromJson', () {
    test('parses all fields', () {
      final branch = Branch.fromJson(_fullJson());

      expect(branch.id, 1);
      expect(branch.name, 'Dar es Salaam Central');
      expect(branch.code, 'DSM-01');
      expect(branch.address, contains('Kariakoo'));
      expect(branch.latitude, -6.7924);
      expect(branch.longitude, 39.2083);
      expect(branch.status, BranchStatus.active);
      expect(branch.createdBy, 42);
      expect(branch.isActive, isTrue);
      expect(branch.isDeleted, isFalse);
      expect(branch.operatingHours, isNotNull);
      expect(branch.operatingHours!['monday'], isNotNull);
      expect(branch.operatingHours!['sunday'], isNull);
    });

    test('handles missing optional fields', () {
      final json = Map<String, dynamic>.from(_fullJson())
        ..remove('created_by')
        ..remove('created_at')
        ..remove('updated_at')
        ..remove('deleted_at')
        ..remove('operating_hours');
      final branch = Branch.fromJson(json);

      expect(branch.createdBy, isNull);
      expect(branch.createdAt, isNull);
      expect(branch.updatedAt, isNull);
      expect(branch.deletedAt, isNull);
      expect(branch.operatingHours, isNull);
    });

    test('handles numeric fields as strings (defensive parsing)', () {
      final json = Map<String, dynamic>.from(_fullJson())
        ..['id'] = '1'
        ..['latitude'] = '-6.7924'
        ..['longitude'] = '39.2083'
        ..['created_by'] = '42';
      final branch = Branch.fromJson(json);

      expect(branch.id, 1);
      expect(branch.latitude, -6.7924);
      expect(branch.createdBy, 42);
    });

    test('falls back to inactive for unknown status', () {
      final json = Map<String, dynamic>.from(_fullJson())
        ..['status'] = 'renovating';
      final branch = Branch.fromJson(json);
      expect(branch.status, BranchStatus.inactive);
      expect(branch.isActive, isFalse);
    });

    test('handles soft-deleted branch', () {
      final json = Map<String, dynamic>.from(_fullJson())
        ..['deleted_at'] = '2026-10-25T00:00:00+00:00';
      final branch = Branch.fromJson(json);
      expect(branch.isDeleted, isTrue);
    });
  });

  group('Branch round-trip', () {
    test('fromJson → toJson → fromJson preserves all fields', () {
      final original = Branch.fromJson(_fullJson());
      final roundtripped = Branch.fromJson(original.toJson());

      expect(roundtripped.id, original.id);
      expect(roundtripped.name, original.name);
      expect(roundtripped.code, original.code);
      expect(roundtripped.latitude, original.latitude);
      expect(roundtripped.longitude, original.longitude);
      expect(roundtripped.status, original.status);
      expect(roundtripped.createdBy, original.createdBy);
      expect(roundtripped.createdAt, original.createdAt);
    });
  });

  group('Branch.coordinates', () {
    test('formats coordinates with 5 decimal places', () {
      final branch = Branch.fromJson(_fullJson());
      expect(branch.coordinates, '-6.79240, 39.20830');
    });
  });
}