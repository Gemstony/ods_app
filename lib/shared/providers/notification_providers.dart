import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import 'repository_providers.dart';

/// The number of unread, unexpired, non-dismissed notifications for the
/// signed-in user.
///
/// Returns 0 when:
///   - signed out,
///   - the fetch fails (badge is cosmetic; a network blip shouldn't break
///     the AppBar),
///   - or there are genuinely no unread notifications.
///
/// Fetches up to 50 unread notifications per call. If a user ever has more
/// than 50 unread, the badge under-counts — acceptable for MVP. A dedicated
/// `/notifications/unread-count` endpoint in Phase 13 fixes it without
/// touching this provider's contract.
///
/// Invalidated after `markRead()` / `markAllRead()` / `dismiss()` /
/// incoming FCM push (Phase 13).
final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final isAuthenticated = ref.watch(
    sessionProvider.select((s) => s.valueOrNull != null),
  );
  if (!isAuthenticated) return 0;

  final repo = ref.watch(notificationRepositoryProvider);
  final result = await repo.list(unreadOnly: true, limit: 50);

  return result.fold(
    onSuccess: (notifications) => notifications.length,
    onFailure: (_) => 0,
  );
}); 