import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/network/api_interceptors.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/models/create_user_input.dart';
import 'package:ods_app/data/repositories/user_repository.dart';

class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter({required this.statusCode, required this.body});
  final int statusCode;
  final Map<String, dynamic>? body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
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
  String role = 'manager',
  String status = 'active',
  Map<String, dynamic>? branch,
}) =>
    {
      'id': id,
      'name': 'User $id',
      'email': 'user$id@ods.test',
      'phone': '0712345678',
      'role': role,
      'status': status,
      'branch_id': 5,
      'branch': branch,
      'dispatcher_enabled': false,
      'permissions': <String>[],
    };

Map<String, dynamic> _successEnvelope(Map<String, dynamic> data) => {
      'success': true,
      'message': 'OK',
      'data': data,
    };

void main() {
  group('UserRepository.list', () {
    test('sends filters and parses list', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope({
          'data': [_userJson(id: 1), _userJson(id: 2, role: 'rider')],
          'total': 2,
          'per_page': 20,
          'current_page': 1,
          'last_page': 1,
        }),
      );
      final repo = UserRepository(dio: _dioWith(adapter));

      final result = await repo.list(role: 'manager', status: 'active');

      expect(result, isA<ApiSuccess>());
      expect(result.dataOrNull!.length, 2);
      expect(adapter.lastRequest!.queryParameters['role'], 'manager');
      expect(adapter.lastRequest!.queryParameters['status'], 'active');
    });

    test('parses nested branch on each user', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope({
          'data': [
            _userJson(id: 1, branch: {'id': 5, 'name': 'KRK', 'code': 'KRK-01'}),
          ],
          'total': 1,
          'per_page': 20,
          'current_page': 1,
          'last_page': 1,
        }),
      );
      final repo = UserRepository(dio: _dioWith(adapter));

      final result = await repo.list();
      expect(result.dataOrNull!.first.branch!.name, 'KRK');
    });
  });

  group('UserRepository.create', () {
    test('sends manager payload without rider-only fields', () async {
      final adapter = _CapturingAdapter(
        statusCode: 201,
        body: _successEnvelope(_userJson(role: 'manager')),
      );
      final repo = UserRepository(dio: _dioWith(adapter));

      final input =CreateUserInput(
        role: 'manager',
        name: 'Jane',
        email: 'j@ods.test',
        phone: '0755123456',
        password: 'Secret123!',
        passwordConfirmation: 'Secret123!',
        branchId: 5,
      );

      await repo.create(input);

      final sent = adapter.lastRequest!.data as Map<String, dynamic>;
      expect(sent['role'], 'manager');
      expect(sent['email'], 'j@ods.test');
      expect(sent['branch_id'], 5);
      // Manager payload must NOT include rider fields
      expect(sent.containsKey('nida'), isFalse);
      expect(sent.containsKey('dispatcher_enabled'), isFalse);
    });

    test('sends rider payload with all rider fields', () async {
      final adapter = _CapturingAdapter(
        statusCode: 201,
        body: _successEnvelope(_userJson(role: 'rider')),
      );
      final repo = UserRepository(dio: _dioWith(adapter));

      final input = CreateUserInput(
        role: 'rider',
        name: 'Tom',
        email: 't@ods.test',
        phone: '0767123456',
        password: 'Secret123!',
        passwordConfirmation: 'Secret123!',
        branchId: 5,
        nida: '19900101123456789012',
        sex: 'male',
        dateOfBirth: '1990-01-01',
        vehicleType: 'Motorcycle',
        vehicleColor: 'Red',
        vehicleOwnership: 'owned',
        plateNumber: 'T123ABC',
      );

      await repo.create(input);

      final sent = adapter.lastRequest!.data as Map<String, dynamic>;
      expect(sent['role'], 'rider');
      expect(sent['nida'], '19900101123456789012');
      expect(sent['sex'], 'male');
      expect(sent['date_of_birth'], '1990-01-01');
      expect(sent['vehicle_type'], 'Motorcycle');
      expect(sent['plate_number'], 'T123ABC');
    });

    test('sends receiver payload with dispatcher flag', () async {
      final adapter = _CapturingAdapter(
        statusCode: 201,
        body: _successEnvelope(_userJson(role: 'receiver')),
      );
      final repo = UserRepository(dio: _dioWith(adapter));

      final input = CreateUserInput(
        role: 'receiver',
        name: 'Alice',
        email: 'a@ods.test',
        phone: '0768123456',
        password: 'Secret123!',
        passwordConfirmation: 'Secret123!',
        branchId: 5,
        dispatcherEnabled: true,
      );

      await repo.create(input);

      final sent = adapter.lastRequest!.data as Map<String, dynamic>;
      expect(sent['role'], 'receiver');
      expect(sent['dispatcher_enabled'], true);
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
      final repo = UserRepository(dio: _dioWith(adapter));

      final result = await repo.create(CreateUserInput(
        role: 'manager',
        name: 'X',
        email: 'x@ods.test',
        phone: '0755123456',
        password: 'Secret123!',
        passwordConfirmation: 'Secret123!',
        branchId: 5,
      ));

      expect(result, isA<ApiFailure>());
      expect(
        result.failureOrNull!.fieldErrors['email'],
        contains('This email is already registered.'),
      );
    });
  });

  group('UserRepository.get', () {
    test('parses a single user', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope(_userJson(id: 99)),
      );
      final repo = UserRepository(dio: _dioWith(adapter));

      final result = await repo.get(99);

      expect(result, isA<ApiSuccess>());
      expect(result.dataOrNull!.id, 99);
      expect(adapter.lastRequest!.path, '/owner/users/99');
    });
  });

  group('UserRepository.update', () {
    test('sends only provided fields', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope(_userJson(id: 1)),
      );
      final repo = UserRepository(dio: _dioWith(adapter));

      await repo.update(1, name: 'Updated', phone: '0712345678');

      final sent = adapter.lastRequest!.data as Map<String, dynamic>;
      expect(sent['name'], 'Updated');
      expect(sent['phone'], '0712345678');
      expect(sent.containsKey('nida'), isFalse);
    });
  });

  group('UserRepository.approve', () {
    test('POSTs to the approve endpoint', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope(_userJson(id: 42, status: 'active')),
      );
      final repo = UserRepository(dio: _dioWith(adapter));

      final result = await repo.approve(42);
      expect(result.dataOrNull!.status, 'active');
      expect(adapter.lastRequest!.path, '/owner/users/42/approve');
      expect(adapter.lastRequest!.method, 'POST');
    });
  });

  group('UserRepository.updateStatus', () {
    test('PATCHes the status endpoint', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope(_userJson(id: 42, status: 'suspended')),
      );
      final repo = UserRepository(dio: _dioWith(adapter));

      final result = await repo.updateStatus(42, 'suspended');
      expect(result.dataOrNull!.status, 'suspended');
      expect(adapter.lastRequest!.path, '/owner/users/42/status');
      expect(adapter.lastRequest!.method, 'PATCH');
      final sent = adapter.lastRequest!.data as Map<String, dynamic>;
      expect(sent['status'], 'suspended');
    });
  });

  group('UserRepository.resetPassword', () {
    test('POSTs password + confirmation', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: const {
          'success': true,
          'message': 'Password reset.',
          'data': null,
        },
      );
      final repo = UserRepository(dio: _dioWith(adapter));

      final result = await repo.resetPassword(
        42,
        password: 'NewSecret123!',
        passwordConfirmation: 'NewSecret123!',
      );

      expect(result, isA<ApiSuccess>());
      expect(adapter.lastRequest!.path, '/owner/users/42/reset-password');
      final sent = adapter.lastRequest!.data as Map<String, dynamic>;
      expect(sent['password'], 'NewSecret123!');
      expect(sent['password_confirmation'], 'NewSecret123!');
    });
  });
}