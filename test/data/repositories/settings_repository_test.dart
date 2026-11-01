import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/network/api_interceptors.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/models/setting.dart';
import 'package:ods_app/data/repositories/settings_repository.dart';

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

Map<String, dynamic> _groupedBody() => {
      'success': true,
      'message': 'OK',
      'data': {
        'location': [
          {
            'key': 'location.pickup_radius_km',
            'value': 5.0,
            'category': 'location',
            'description': 'radius',
            'is_public': false,
          },
        ],
        'batching': [
          {
            'key': 'batching.window_minutes',
            'value': 20,
            'category': 'batching',
            'description': 'window',
            'is_public': false,
          },
        ],
      },
    };

void main() {
  group('SettingsRepository.list', () {
    test('groups settings by category', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _groupedBody(),
      );
      final repo = SettingsRepository(dio: _dioWith(adapter));

      final result = await repo.list();

      expect(result, isA<ApiSuccess<Map<String, List<Setting>>>>());
      final grouped = result.dataOrNull!;
      expect(grouped.keys, containsAll(['location', 'batching']));
      expect(grouped['location']!.first.key, 'location.pickup_radius_km');
      expect(grouped['batching']!.first.value, 20);
    });

    test('parses settings without id field (backend omits it)', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _groupedBody(),
      );
      final repo = SettingsRepository(dio: _dioWith(adapter));

      final result = await repo.list();
      // id defaults to 0 when backend omits it
      expect(result.dataOrNull!['location']!.first.id, 0);
    });
  });

  group('SettingsRepository.updateOne', () {
    test('PUTs a single value and parses response', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: {
          'success': true,
          'message': 'Setting updated.',
          'data': {
            'key': 'batching.window_minutes',
            'value': 30,
            'category': 'batching',
            'description': 'window',
            'is_public': false,
          },
        },
      );
      final repo = SettingsRepository(dio: _dioWith(adapter));

      final result = await repo.updateOne('batching.window_minutes', 30);

      expect(result, isA<ApiSuccess<Setting>>());
      expect(result.dataOrNull!.value, 30);
      expect(adapter.lastRequest!.method, 'PUT');
      expect(adapter.lastRequest!.path, '/owner/settings/batching.window_minutes');
      final sent = adapter.lastRequest!.data as Map<String, dynamic>;
      expect(sent['value'], 30);
    });
  });

  group('SettingsRepository.bulkUpdate', () {
    test('sends settings array and parses updated list', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: {
          'success': true,
          'message': 'Settings updated.',
          'data': [
            {
              'key': 'batching.window_minutes',
              'value': 25,
              'category': 'batching',
              'is_public': false,
            },
            {
              'key': 'location.pickup_radius_km',
              'value': 6.5,
              'category': 'location',
              'is_public': false,
            },
          ],
        },
      );
      final repo = SettingsRepository(dio: _dioWith(adapter));

      final result = await repo.bulkUpdate([
        const MapEntry('batching.window_minutes', 25),
        const MapEntry('location.pickup_radius_km', 6.5),
      ]);

      expect(result, isA<ApiSuccess<List<Setting>>>());
      expect(result.dataOrNull!.length, 2);
      final sent = adapter.lastRequest!.data as Map<String, dynamic>;
      final settings = sent['settings'] as List;
      expect(settings.length, 2);
      expect((settings[0] as Map)['key'], 'batching.window_minutes');
      expect((settings[0] as Map)['value'], 25);
    });
  });
}