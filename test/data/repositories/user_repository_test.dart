import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/network/api_interceptors.dart';
import 'package:ods_app/core/network/api_result.dart';
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

Map<String, dynamic> _userJson(int id, {String role = 'manager'}) => {
      'id': id,
      'name': 'User $id',
      'email': 'user$id@ods.test',
      'phone': '071234567$id',
      'role': role,
      'status': 'active',
      'branch_id': 1,
      'dispatcher_enabled': false,
      'permissions': <String>[],
    };

void main() {
  group('UserRepository.list', () {
    test('sends role and status filters', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: {
          'success': true,
          'message': 'OK',
          'data': {
            'data': [_userJson(1), _userJson(2)],
            'total': 2,
            'per_page': 20,
            'current_page': 1,
            'last_page': 1,
          },
        },
      );
      final repo = UserRepository(dio: _dioWith(adapter));

      final result = await repo.list(
        role: 'manager',
        status: 'active',
        perPage: 100,
      );

      expect(result, isA<ApiSuccess>());
      expect(result.dataOrNull!.length, 2);
      expect(adapter.lastRequest!.path, '/owner/users');
      expect(adapter.lastRequest!.queryParameters['role'], 'manager');
      expect(adapter.lastRequest!.queryParameters['status'], 'active');
      expect(adapter.lastRequest!.queryParameters['per_page'], 100);
    });

    test('returns empty list when no users', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: {
          'success': true,
          'message': 'OK',
          'data': {
            'data': <Map<String, dynamic>>[],
            'total': 0,
            'per_page': 20,
            'current_page': 1,
            'last_page': 1,
          },
        },
      );
      final repo = UserRepository(dio: _dioWith(adapter));

      final result = await repo.list();
      expect(result.dataOrNull, isEmpty);
    });
  });
}