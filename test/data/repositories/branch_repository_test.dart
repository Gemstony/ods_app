import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/network/api_interceptors.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/models/branch.dart';
import 'package:ods_app/data/models/branch_input.dart';
import 'package:ods_app/data/repositories/branch_repository.dart';

/// Adapter that captures the last request and returns a canned response.
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

Dio _dioWith(_CapturingAdapter adapter) {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:8000/api/v1',
    validateStatus: (s) => s != null && s < 400,
  ));
  dio.httpClientAdapter = adapter;
  dio.interceptors.add(ErrorMappingInterceptor());
  return dio;
}

Map<String, dynamic> _branchJson({int id = 1, String code = 'DSM-01'}) => {
      'id': id,
      'name': 'Dar es Salaam Central',
      'code': code,
      'address': '123 Kariakoo, DSM',
      'latitude': -6.79,
      'longitude': 39.20,
      'operating_hours': {
        'monday': {'open': '08:00', 'close': '18:00'},
      },
      'status': 'active',
      'created_by': 42,
      'created_at': '2026-10-24T07:00:00+00:00',
      'updated_at': '2026-10-24T07:00:00+00:00',
      'deleted_at': null,
    };

Map<String, dynamic> _successEnvelope(Map<String, dynamic> data) => {
      'success': true,
      'message': 'OK',
      'data': data,
    };

void main() {
  // ─── list() ────────────────────────────────────────────────
  group('BranchRepository.list', () {
    test('parses a raw array payload', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope({
          'data': [_branchJson(id: 1), _branchJson(id: 2, code: 'ARU-01')],
        }),
      );
      final repo = BranchRepository(dio: _dioWith(adapter));

      final result = await repo.list();

      expect(result, isA<ApiSuccess<List<Branch>>>());
      final branches = result.dataOrNull!;
      expect(branches.length, 2);
      expect(branches[0].id, 1);
      expect(branches[1].code, 'ARU-01');
    });

    test('parses a paginated envelope', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope({
          'data': [_branchJson(id: 1)],
          'meta': {'current_page': 1, 'per_page': 20, 'total': 1},
        }),
      );
      final repo = BranchRepository(dio: _dioWith(adapter));

      final result = await repo.list();

      expect(result, isA<ApiSuccess<List<Branch>>>());
      expect(result.dataOrNull!.length, 1);
    });

    test('sends status filter as query param', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope({'data': <Map<String, dynamic>>[]}),
      );
      final repo = BranchRepository(dio: _dioWith(adapter));

      await repo.list(status: BranchStatus.active);

      expect(adapter.lastRequest!.path, '/owner/branches');
      expect(adapter.lastRequest!.method, 'GET');
      expect(adapter.lastRequest!.queryParameters, {'status': 'active'});
    });

    test('returns empty list when no branches', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope({'data': <Map<String, dynamic>>[]}),
      );
      final repo = BranchRepository(dio: _dioWith(adapter));

      final result = await repo.list();

      expect(result, isA<ApiSuccess<List<Branch>>>());
      expect(result.dataOrNull, isEmpty);
    });

    test('returns ApiFailure on 403 from server', () async {
      final adapter = _CapturingAdapter(
        statusCode: 403,
        body: {
          'success': false,
          'message': 'You do not have access to this resource.',
          'errors': null,
        },
      );
      final repo = BranchRepository(dio: _dioWith(adapter));

      final result = await repo.list();

      expect(result, isA<ApiFailure>());
    });
  });

  // ─── get() ─────────────────────────────────────────────────
  group('BranchRepository.get', () {
    test('parses a single branch by id', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope(_branchJson(id: 7)),
      );
      final repo = BranchRepository(dio: _dioWith(adapter));

      final result = await repo.get(7);

      expect(result, isA<ApiSuccess<Branch>>());
      expect(result.dataOrNull!.id, 7);
      expect(adapter.lastRequest!.path, '/owner/branches/7');
    });

    test('returns ApiFailure on 404', () async {
      final adapter = _CapturingAdapter(
        statusCode: 404,
        body: {
          'success': false,
          'message': 'Branch not found.',
          'errors': null,
        },
      );
      final repo = BranchRepository(dio: _dioWith(adapter));

      final result = await repo.get(999);

      expect(result, isA<ApiFailure>());
      expect(result.failureOrNull!.type.name, 'notFound');
    });
  });

  // ─── create() ──────────────────────────────────────────────
  group('BranchRepository.create', () {
    test('sends POST with all fields serialized', () async {
      final adapter = _CapturingAdapter(
        statusCode: 201,
        body: _successEnvelope(_branchJson()),
      );
      final repo = BranchRepository(dio: _dioWith(adapter));

      final input = BranchInput(
        name: 'Dar es Salaam Central',
        code: 'DSM-01',
        address: '123 Kariakoo, DSM',
        latitude: -6.79,
        longitude: 39.20,
        operatingHours: {
          'monday': {'open': '08:00', 'close': '18:00'},
        },
      );

      final result = await repo.create(input);

      expect(result, isA<ApiSuccess<Branch>>());
      expect(adapter.lastRequest!.path, '/owner/branches');
      expect(adapter.lastRequest!.method, 'POST');
      final sent = adapter.lastRequest!.data as Map<String, dynamic>;
      expect(sent['name'], 'Dar es Salaam Central');
      expect(sent['code'], 'DSM-01');
      expect(sent['latitude'], -6.79);
      expect(sent['status'], 'active');
      expect(sent['operating_hours'], isNotNull);
    });

    test('omits null optional fields from payload', () async {
      final adapter = _CapturingAdapter(
        statusCode: 201,
        body: _successEnvelope(_branchJson()),
      );
      final repo = BranchRepository(dio: _dioWith(adapter));

      final input = BranchInput(
        name: 'Branch',
        code: 'BR-01',
        address: 'Address',
        latitude: 0,
        longitude: 0,
        // operatingHours not set → should be absent from JSON
      );

      await repo.create(input);

      final sent = adapter.lastRequest!.data as Map<String, dynamic>;
      expect(sent.containsKey('operating_hours'), isFalse);
    });

    test('returns ApiFailure on 422 validation error', () async {
      final adapter = _CapturingAdapter(
        statusCode: 422,
        body: {
          'success': false,
          'message': 'Validation failed.',
          'errors': {
            'code': ['This code is already in use.'],
          },
        },
      );
      final repo = BranchRepository(dio: _dioWith(adapter));

      final result = await repo.create(
        const BranchInput(
          name: 'X',
          code: 'DSM-01',
          address: 'Y',
          latitude: 0,
          longitude: 0,
        ),
      );

      expect(result, isA<ApiFailure>());
      expect(
        result.failureOrNull!.fieldErrors['code'],
        contains('This code is already in use.'),
      );
    });
  });

  // ─── update() ──────────────────────────────────────────────
  group('BranchRepository.update', () {
    test('sends PUT to the correct path', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope(_branchJson(id: 3)),
      );
      final repo = BranchRepository(dio: _dioWith(adapter));

      final input = BranchInput(
        name: 'Updated',
        code: 'DSM-01',
        address: 'New address',
        latitude: -6.80,
        longitude: 39.21,
        status: BranchStatus.inactive,
      );

      final result = await repo.update(3, input);

      expect(result, isA<ApiSuccess<Branch>>());
      expect(adapter.lastRequest!.path, '/owner/branches/3');
      expect(adapter.lastRequest!.method, 'PUT');
      final sent = adapter.lastRequest!.data as Map<String, dynamic>;
      expect(sent['status'], 'inactive');
    });
  });
}