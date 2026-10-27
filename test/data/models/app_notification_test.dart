import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/data/models/app_notification.dart';

Map<String, dynamic> _pendingJson() => {
      'id': 1,
      'user_id': 42,
      'type': 'delivery.assigned',
      'title': 'New delivery assigned',
      'body': 'You have been assigned delivery ODS-20261024-ABC123',
      'data': {'delivery_id': 100, 'action': 'open_delivery'},
      'channels': ['in_app'],
      'status': 'pending',
      'priority': 'normal',
      'sent_at': null,
      'read_at': null,
      'dismissed_at': null,
      'expires_at': null,
      'created_at': '2026-10-24T07:00:00+00:00',
      'updated_at': '2026-10-24T07:00:00+00:00',
    };

Map<String, dynamic> _sentJson() => {
      ..._pendingJson(),
      'status': 'sent',
      'sent_at': '2026-10-24T07:01:00+00:00',
    };

void main() {
  group('NotificationStatus enum', () {
    test('fromString maps all three statuses', () {
      expect(NotificationStatus.fromString('pending'), NotificationStatus.pending);
      expect(NotificationStatus.fromString('sent'), NotificationStatus.sent);
      expect(NotificationStatus.fromString('failed'), NotificationStatus.failed);
    });

    test('fromString falls back to unknown', () {
      expect(
          NotificationStatus.fromString('bounced'), NotificationStatus.unknown);
    });
  });

  group('NotificationPriority enum', () {
    test('fromString maps all four priorities', () {
      expect(NotificationPriority.fromString('low'), NotificationPriority.low);
      expect(NotificationPriority.fromString('normal'), NotificationPriority.normal);
      expect(NotificationPriority.fromString('high'), NotificationPriority.high);
      expect(NotificationPriority.fromString('urgent'), NotificationPriority.urgent);
    });

    test('fromString falls back to normal', () {
      expect(NotificationPriority.fromString('critical'),
          NotificationPriority.normal);
    });

    test('isProminent is true for high and urgent', () {
      expect(NotificationPriority.high.isProminent, isTrue);
      expect(NotificationPriority.urgent.isProminent, isTrue);
      expect(NotificationPriority.normal.isProminent, isFalse);
      expect(NotificationPriority.low.isProminent, isFalse);
    });
  });

  group('AppNotification.fromJson', () {
    test('parses a pending notification', () {
      final n = AppNotification.fromJson(_pendingJson());
      expect(n.id, 1);
      expect(n.userId, 42);
      expect(n.type, 'delivery.assigned');
      expect(n.title, 'New delivery assigned');
      expect(n.body, contains('ODS-20261024'));
      expect(n.status, NotificationStatus.pending);
      expect(n.priority, NotificationPriority.normal);
      expect(n.hasBeenSent, isFalse);
      expect(n.isRead, isFalse);
      expect(n.isDismissed, isFalse);
      expect(n.isUnread, isTrue);
    });

    test('parses sent notification with data payload', () {
      final n = AppNotification.fromJson(_sentJson());
      expect(n.hasBeenSent, isTrue);
      expect(n.sentAt, isNotNull);
      expect(n.data, {'delivery_id': 100, 'action': 'open_delivery'});
    });

    test('parses read notification', () {
      final n = AppNotification.fromJson(_sentJson()
        ..['read_at'] = '2026-10-24T08:00:00+00:00');
      expect(n.isRead, isTrue);
      expect(n.isUnread, isFalse);
    });

    test('parses dismissed notification', () {
      final n = AppNotification.fromJson(_sentJson()
        ..['dismissed_at'] = '2026-10-24T09:00:00+00:00');
      expect(n.isDismissed, isTrue);
      expect(n.isUnread, isFalse);
    });

    test('parses expired notification', () {
      final n = AppNotification.fromJson(_sentJson()
        ..['expires_at'] =
            DateTime.now().subtract(const Duration(hours: 1)).toIso8601String());
      expect(n.isExpired, isTrue);
      expect(n.isUnread, isFalse);
    });

    test('parses channels array', () {
      final n = AppNotification.fromJson(
        _pendingJson()..['channels'] = ['in_app', 'sms'],
      );
      expect(n.channels, ['in_app', 'sms']);
      expect(n.isInApp, isTrue);
      expect(n.isSms, isTrue);
      expect(n.isPush, isFalse);
    });

    test('handles empty channels array', () {
      final n = AppNotification.fromJson(_pendingJson()..['channels'] = []);
      expect(n.channels, isEmpty);
      expect(n.isInApp, isFalse);
    });

    test('handles null data payload', () {
      final n = AppNotification.fromJson(_pendingJson()..['data'] = null);
      expect(n.data, isNull);
    });

    test('parses urgent priority', () {
      final n = AppNotification.fromJson(_pendingJson()..['priority'] = 'urgent');
      expect(n.priority, NotificationPriority.urgent);
      expect(n.isProminent, isTrue);
    });
  });

  group('AppNotification round-trip', () {
    test('fromJson → toJson → fromJson preserves all fields', () {
      final original = AppNotification.fromJson(_sentJson());
      final roundtripped = AppNotification.fromJson(original.toJson());
      expect(roundtripped.id, original.id);
      expect(roundtripped.type, original.type);
      expect(roundtripped.title, original.title);
      expect(roundtripped.channels, original.channels);
      expect(roundtripped.status, original.status);
      expect(roundtripped.priority, original.priority);
      expect(roundtripped.data, original.data);
    });

    test('read/dismissed timestamps preserved', () {
      final original = AppNotification.fromJson(_sentJson()
        ..['read_at'] = '2026-10-24T08:00:00+00:00'
        ..['dismissed_at'] = '2026-10-24T09:00:00+00:00');
      final roundtripped = AppNotification.fromJson(original.toJson());
      expect(roundtripped.isRead, isTrue);
      expect(roundtripped.isDismissed, isTrue);
    });
  });

  group('AppNotification defensive parsing', () {
    test('accepts string id', () {
      final n = AppNotification.fromJson(_pendingJson()
        ..['id'] = '1'
        ..['user_id'] = '42');
      expect(n.id, 1);
      expect(n.userId, 42);
    });

    test('handles missing data payload gracefully', () {
      final json = Map<String, dynamic>.from(_pendingJson())..remove('data');
      final n = AppNotification.fromJson(json);
      expect(n.data, isNull);
    });
  });
}