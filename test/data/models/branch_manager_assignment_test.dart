import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/data/models/branch_manager_assignment.dart';

void main() {
  group('BranchManagerAssignment.fromJson', () {
    test('parses an active assignment', () {
      final a = BranchManagerAssignment.fromJson({
        'id': 1,
        'user': {'id': 5, 'name': 'Jane Manager', 'email': 'jane@ods.test'},
        'assigned_at': '2026-10-24T10:00:00+00:00',
        'assigned_by': {'id': 42, 'name': 'Ahmed'},
        'unassigned_at': null,
        'unassigned_by': null,
        'is_active': true,
      });

      expect(a.id, 1);
      expect(a.userId, 5);
      expect(a.userName, 'Jane Manager');
      expect(a.userEmail, 'jane@ods.test');
      expect(a.assignedAt, isNotNull);
      expect(a.assignedById, 42);
      expect(a.assignedByName, 'Ahmed');
      expect(a.unassignedAt, isNull);
      expect(a.isActive, isTrue);
    });

    test('parses a past assignment', () {
      final a = BranchManagerAssignment.fromJson({
        'id': 1,
        'user': {'id': 5, 'name': 'Jane Manager', 'email': 'jane@ods.test'},
        'assigned_at': '2026-01-01T00:00:00+00:00',
        'assigned_by': null,
        'unassigned_at': '2026-06-01T00:00:00+00:00',
        'unassigned_by': {'id': 42, 'name': 'Ahmed'},
        'is_active': false,
      });

      expect(a.unassignedAt, isNotNull);
      expect(a.unassignedByName, 'Ahmed');
      expect(a.isActive, isFalse);
      expect(a.assignedById, isNull);
    });

    test('handles missing optional fields', () {
      final a = BranchManagerAssignment.fromJson({
        'id': 1,
        'user': {'id': 5, 'name': 'Jane', 'email': 'j@ods.test'},
        'is_active': true,
      });

      expect(a.assignedAt, isNull);
      expect(a.assignedById, isNull);
      expect(a.unassignedById, isNull);
    });
  });
}