import '../../core/utils/json_helpers.dart';

/// The class is named [AppNotification] (not [Notification]) to avoid an
/// import collision with `flutter/widgets.dart`'s `Notification` class.
/// Backend field names — and the wire format — are unchanged.

enum NotificationStatus {
  pending,
  sent,
  failed,
  unknown;

  static NotificationStatus fromString(String value) {
    return NotificationStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => NotificationStatus.unknown,
    );
  }

  String get displayLabel => switch (this) {
        NotificationStatus.pending => 'Pending',
        NotificationStatus.sent => 'Sent',
        NotificationStatus.failed => 'Failed',
        NotificationStatus.unknown => 'Unknown',
      };
}

enum NotificationPriority {
  low,
  normal,
  high,
  urgent;

  static NotificationPriority fromString(String value) {
    return NotificationPriority.values.firstWhere(
      (p) => p.name == value,
      orElse: () => NotificationPriority.normal,
    );
  }

  /// True for high and urgent — useful for filtering "show first".
  bool get isProminent => this == high || this == urgent;

  String get displayLabel => switch (this) {
        NotificationPriority.low => 'Low',
        NotificationPriority.normal => 'Normal',
        NotificationPriority.high => 'High',
        NotificationPriority.urgent => 'Urgent',
      };
}

/// An in-app notification delivered to a single user.
///
/// Mirrors `App\Models\Notification` from Phase 2.5. The `channels` list
/// records which delivery channels were used (`in_app`, `sms`, `push`).
/// The `data` map carries deep-link payloads (e.g.
/// `{"delivery_id": 42, "action": "open_delivery"}`) that Phase 13's UI
/// handlers will interpret.
class AppNotification {
  final int id;
  final int userId;
  final String type;
  final String title;
  final String? body;
  final Map<String, dynamic>? data;
  final List<String> channels;
  final NotificationStatus status;
  final NotificationPriority priority;
  final DateTime? sentAt;
  final DateTime? readAt;
  final DateTime? dismissedAt;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.channels,
    required this.status,
    required this.priority,
    this.body,
    this.data,
    this.sentAt,
    this.readAt,
    this.dismissedAt,
    this.expiresAt,
    this.createdAt,
    this.updatedAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawChannels = json['channels'];
    final channels = rawChannels is List
        ? rawChannels.map((e) => e.toString()).toList(growable: false)
        : const <String>[];

    return AppNotification(
      id: asInt(json['id']),
      userId: asInt(json['user_id']),
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String?,
      data: asMap(json['data']),
      channels: channels,
      status: NotificationStatus.fromString(json['status'] as String),
      priority: NotificationPriority.fromString(json['priority'] as String),
      sentAt: parseDate(json['sent_at']),
      readAt: parseDate(json['read_at']),
      dismissedAt: parseDate(json['dismissed_at']),
      expiresAt: parseDate(json['expires_at']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'type': type,
        'title': title,
        'body': body,
        'data': data,
        'channels': channels,
        'status': status.name,
        'priority': priority.name,
        'sent_at': sentAt?.toIso8601String(),
        'read_at': readAt?.toIso8601String(),
        'dismissed_at': dismissedAt?.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  // ─── State helpers ───────────────────────────────────────
  bool get hasBeenSent => status == NotificationStatus.sent;
  bool get isRead => readAt != null;
  bool get isDismissed => dismissedAt != null;
  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  /// The one flag most screens need: "show a badge for this one".
  bool get isUnread => !isRead && !isDismissed && !isExpired;

  /// Priority filters.
  bool get isProminent => priority.isProminent;

  /// True if this notification was delivered to the in-app channel.
  bool get isInApp => channels.contains('in_app');

  bool get isSms => channels.contains('sms');

  bool get isPush => channels.contains('push');
}