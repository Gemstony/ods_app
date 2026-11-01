import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/data/models/auth/auth_user.dart';

Map<String, dynamic> _baseJson() => {
      'id': 42,
      'name': 'Ahmed Juma',
      'email': 'ahmed@ods.test',
      'phone': '0712345678',
      'role': 'manager',
      'status': 'active',
      'branch_id': 5,
      'dispatcher_enabled': false,
      'permissions': <String>['manage_staff'],
    };

void main() {
  group('AuthUser.fromJson', () {
    test('parses base fields without branch', () {
      final user = AuthUser.fromJson(_baseJson());
      expect(user.id, 42);
      expect(user.name, 'Ahmed Juma');
      expect(user.role, 'manager');
      expect(user.branchId, 5);
      expect(user.branch, isNull);
    });

    test('parses nested branch', () {
      final user = AuthUser.fromJson({
        ..._baseJson(),
        'branch': {'id': 5, 'name': 'Kariakoo', 'code': 'KRK-01'},
      });
      expect(user.branch, isNotNull);
      expect(user.branch!.id, 5);
      expect(user.branch!.name, 'Kariakoo');
      expect(user.branch!.code, 'KRK-01');
    });

    test('missing branch field leaves it null', () {
      final user = AuthUser.fromJson(_baseJson());
      expect(user.branch, isNull);
    });
  });

  group('UserBranchRef.fromJson', () {
    test('parses all fields', () {
      final ref = UserBranchRef.fromJson(
          {'id': 1, 'name': 'Branch', 'code': 'BR-1'});
      expect(ref.id, 1);
      expect(ref.name, 'Branch');
      expect(ref.code, 'BR-1');
    });

    test('handles id as string', () {
      final ref = UserBranchRef.fromJson(
          {'id': '42', 'name': 'Branch', 'code': 'BR-42'});
      expect(ref.id, 42);
    });
  });
}