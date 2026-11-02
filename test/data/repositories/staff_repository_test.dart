import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/network/api_interceptors.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/models/create_user_input.dart';
import 'package:ods_app/data/repositories/staff_repository.dart';

/// Tracks every request; tests use `lastPut`/`lastPost`/`lastPatch`
/// getters to find mutations even when a follow-up GET happens.
class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter({required this.statusCode, required this.body});
  final int statusCode;
  final Map<String, dynamic>? body;
  final List<RequestOptions> captured = [];

  RequestOptions get lastPost {
    final posts = captured.where((r) => r.method == 'POST').toList();
    if (posts.isEmpty) {
      throw StateError(
        'No POST captured. Requests: '
        '${captured.map((r) => '${r.method} ${r.path}').toList()}',
      );
    }
    return posts.last;
  }

  RequestOptions get lastPut {
    final puts = captured.where((r) => r.method == 'PUT').toList();
    if (puts.isEmpty) {
      throw StateError(
        'No PUT captured. Requests: '
        '${captured.map((r) => '${r.method} ${r.path}').toList()}',
      );
    }
    return puts.last;
  }

  RequestOptions get lastPatch {
    final patches = captured.where((r) => r.method == 'PATCH').toList();
    if (patches.isEmpty) {
      throw StateError(
        'No PATCH captured. Requests: '
        '${captured.map((r) => '${r.method} ${r.path}').toList()}',
      );
    }
    return patches.last;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured.add(options);
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(_CapturingAdapter a) {
  final d = Dio(BaseOptions(
    baseUrl: 'http://localhost:8000/api/v1',
    validateStatus: (s) => s != null && s < 400,
  ));
  d.httpClientAdapter = a;
  d.interceptors.add(ErrorMappingInterceptor());
  return d;
}

Map<String, dynamic> _userJson({
  int id = 1,
  String role = 'receiver',
  String status = 'active',
}) =>
    {
      'id': id,
      'name': 'User $id',
      'email': 'u$id@ods.test',
      'phone': '0712345678',
      'role': role,
      'status': status,
      'branch_id': 5,
      'dispatcher_enabled': false,
      'permissions': <String>[],
    };

Map<String, dynamic> _successList(List<Map<String, dynamic>> data) => {
      'success': true,
      'message': 'OK',
      'data': {
        'data': data,
        'total': data.length,
        'per_page': 20,
        'current_page': 1,
        'last_page': 1,
      },
    };

Map<String, dynamic> _successOne(Map<String, dynamic> user) => {
      'success': true,
      'message': 'OK',
      'data': user,
    };

void main() {
  group('StaffRepository.list', () {
    test('sends filters and parses list', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successList([
          _userJson(id: 1, role: 'receiver'),
          _userJson(id: 2, role: 'rider'),
        ]),
      );
      final repo = StaffRepository(dio: _dioWith(adapter));

      final result = await repo.list(role: 'rider', status: 'active');

      expect(result, isA<ApiSuccess>());
      expect(result.dataOrNull!.length, 2);
      final request = adapter.captured.first;
      expect(request.path, '/manager/staff');
      expect(request.queryParameters['role'], 'rider');
      expect(request.queryParameters['status'], 'active');
    });
  });

  group('StaffRepository.create', () {
    test('does NOT include branch_id in payload', () async {
      final adapter = _CapturingAdapter(
        statusCode: 201,
        body: _successOne(_userJson()),
      );
      final repo = StaffRepository(dio: _dioWith(adapter));

      final input = CreateUserInput(
        role: 'receiver',
        name: 'New',
        email: 'new@ods.test',
        phone: '0755123456',
        password: 'SecretPass123!',
        passwordConfirmation: 'SecretPass123!',
        // branchId intentionally omitted
      );

      await repo.create(input);

      final sent = adapter.lastPost.data as Map<String, dynamic>;
      expect(sent.containsKey('branch_id'), isFalse);
      expect(sent['role'], 'receiver');
    });

    test('includes rider fields for rider role', () async {
      final adapter = _CapturingAdapter(
        statusCode: 201,
        body: _successOne(_userJson(role: 'rider')),
      );
      final repo = StaffRepository(dio: _dioWith(adapter));

      final input = CreateUserInput(
        role: 'rider',
        name: 'Rider',
        email: 'r@ods.test',
        phone: '0767123456',
        password: 'SecretPass123!',
        passwordConfirmation: 'SecretPass123!',
        nida: '19900101123456789012',
        sex: 'male',
        dateOfBirth: '1990-01-01',
        vehicleType: 'Motorcycle',
        vehicleColor: 'Red',
        vehicleOwnership: 'owned',
        plateNumber: 'T123ABC',
      );

      await repo.create(input);

      final sent = adapter.lastPost.data as Map<String, dynamic>;
      expect(sent['nida'], '19900101123456789012');
      expect(sent['vehicle_type'], 'Motorcycle');
      expect(sent.containsKey('branch_id'), isFalse);
    });

    test('maps 422 field errors', () async {
      final adapter = _CapturingAdapter(
        statusCode: 422,
        body: {
          'success': false,
          'message': 'Validation failed.',
          'errors': {
            'email': ['This email is already registered.'],
          },
        },
      );
      final repo = StaffRepository(dio: _dioWith(adapter));

      final result = await repo.create(CreateUserInput(
        role: 'receiver',
        name: 'X',
        email: 'x@ods.test',
        phone: '0755123456',
        password: 'SecretPass123!',
        passwordConfirmation: 'SecretPass123!',
      ));

      expect(result, isA<ApiFailure>());
      expect(
        result.failureOrNull!.fieldErrors['email'],
        contains('This email is already registered.'),
      );
    });
  });

  group('StaffRepository.update', () {
    test('sends only provided fields', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successOne(_userJson(id: 42)),
      );
      final repo = StaffRepository(dio: _dioWith(adapter));

      await repo.update(42, name: 'Updated', phone: '0755123456');

      final sent = adapter.lastPut.data as Map<String, dynamic>;
      expect(sent['name'], 'Updated');
      expect(sent['phone'], '0755123456');
      expect(sent.containsKey('nida'), isFalse);
    });
  });

  group('StaffRepository.updateStatus', () {
    test('PATCHes the status endpoint', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successOne(_userJson(id: 42, status: 'suspended')),
      );
      final repo = StaffRepository(dio: _dioWith(adapter));

      final result = await repo.updateStatus(42, 'suspended');

      expect(result.dataOrNull!.status, 'suspended');
      expect(adapter.lastPatch.path, '/manager/staff/42/status');
      final sent = adapter.lastPatch.data as Map<String, dynamic>;
      expect(sent['status'], 'suspended');
    });
  });

  group('StaffRepository.resetPassword', () {
    test('POSTs password + confirmation', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: const {
          'success': true,
          'message': 'Password reset.',
          'data': null,
        },
      );
      final repo = StaffRepository(dio: _dioWith(adapter));

      final result = await repo.resetPassword(
        42,
        password: 'NewSecret123!',
        passwordConfirmation: 'NewSecret123!',
      );

      expect(result, isA<ApiSuccess>());
      expect(adapter.lastPost.path, '/manager/staff/42/reset-password');
    });
  });
}