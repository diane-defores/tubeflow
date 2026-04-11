import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tubeflow_app/convex/convex_provider.dart';
import 'package:tubeflow_app/models/models.dart';

// =============================================================================
// Typed Convex providers for the TubeFlow app.
//
// Each provider maps a Convex function path to a strongly-typed Dart model.
//
// * StreamProvider  — backed by ConvexService.subscribe (real-time).
// * FutureProvider  — backed by ConvexService.query   (one-shot).
// =============================================================================

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Decodes a raw Convex response (JSON string or pre-decoded value) into a
/// [List<Map<String, dynamic>>].
///
/// Returns an empty list when the response is `null` or `"null"`.
List<Map<String, dynamic>> _decodeList(dynamic raw) {
  if (raw == null) return [];
  List<dynamic> list;
  if (raw is String) {
    if (raw == 'null' || raw.isEmpty) return [];
    list = jsonDecode(raw) as List<dynamic>;
  } else if (raw is List) {
    list = raw;
  } else {
    return [];
  }
  return list
      .whereType<Map<String, dynamic>>()
      .toList(growable: false);
}

/// Decodes a raw Convex response into a single [Map<String, dynamic>], or
/// `null` if the response is empty / null.
Map<String, dynamic>? _decodeMap(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map<String, dynamic>) return raw;
  if (raw is String) {
    if (raw == 'null' || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    return null;
  }
  return null;
}

// ---------------------------------------------------------------------------
// 1. videosProvider
// ---------------------------------------------------------------------------

/// Arguments for [videosProvider].
class VideosArgs {
  const VideosArgs({
    this.sortOrder = 'newest',
    this.includeWatched = true,
  });

  final String sortOrder;
  final bool includeWatched;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideosArgs &&
          sortOrder == other.sortOrder &&
          includeWatched == other.includeWatched;

  @override
  int get hashCode => Object.hash(sortOrder, includeWatched);
}

/// Subscribes to `youtube:getAllVideos` and emits a typed
/// `List<YouTubeVideo>` on every server-side change.
final videosProvider =
    StreamProvider.family<List<YouTubeVideo>, VideosArgs>((ref, args) {
  final service = ref.watch(convexServiceProvider);
  return service
      .subscribe<dynamic>('youtube:getAllVideos', {
        'sortOrder': args.sortOrder,
        'includeWatched': args.includeWatched,
      })
      .map((raw) => _decodeList(raw)
          .map((json) => YouTubeVideo.fromJson(json))
          .toList(growable: false));
});

// ---------------------------------------------------------------------------
// 2. playlistsProvider
// ---------------------------------------------------------------------------

/// Subscribes to `youtube:getYoutubePlaylists` — real-time playlist list.
final playlistsProvider = StreamProvider<List<YouTubePlaylist>>((ref) {
  final service = ref.watch(convexServiceProvider);
  return service
      .subscribe<dynamic>('youtube:getYoutubePlaylists', {})
      .map((raw) => _decodeList(raw)
          .map((json) => YouTubePlaylist.fromJson(json))
          .toList(growable: false));
});

// ---------------------------------------------------------------------------
// 3. notesProvider
// ---------------------------------------------------------------------------

/// Subscribes to `notes:getNotes` — all notes for the current user.
final notesProvider = StreamProvider<List<Note>>((ref) {
  final service = ref.watch(convexServiceProvider);
  return service
      .subscribe<dynamic>('notes:getNotes', {})
      .map((raw) => _decodeList(raw)
          .map((json) => Note.fromJson(json))
          .toList(growable: false));
});

// ---------------------------------------------------------------------------
// 4. settingsProvider
// ---------------------------------------------------------------------------

/// Subscribes to `settings:getSettings` — current user's settings.
///
/// Emits `null` when no settings document exists yet (new user).
final settingsProvider = StreamProvider<UserSettings?>((ref) {
  final service = ref.watch(convexServiceProvider);
  return service
      .subscribe<dynamic>('settings:getSettings', {})
      .map((raw) {
    final json = _decodeMap(raw);
    return json != null ? UserSettings.fromJson(json) : null;
  });
});

// ---------------------------------------------------------------------------
// 5. subscriptionProvider
// ---------------------------------------------------------------------------

/// Subscribes to `subscriptions:getSubscription` — user's billing subscription.
///
/// Emits `null` when no subscription document exists (defaults to free).
final subscriptionProvider = StreamProvider<UserSubscription?>((ref) {
  final service = ref.watch(convexServiceProvider);
  return service
      .subscribe<dynamic>('subscriptions:getSubscription', {})
      .map((raw) {
    final json = _decodeMap(raw);
    return json != null ? UserSubscription.fromJson(json) : null;
  });
});

// ---------------------------------------------------------------------------
// 6. currentUserProvider
// ---------------------------------------------------------------------------

/// Subscribes to `users:getCurrentUser` — the currently authenticated user.
///
/// Emits `null` when the user is not authenticated.
final currentUserProvider = StreamProvider<TubeFlowUser?>((ref) {
  final service = ref.watch(convexServiceProvider);
  return service
      .subscribe<dynamic>('users:getCurrentUser', {})
      .map((raw) {
    final json = _decodeMap(raw);
    return json != null ? TubeFlowUser.fromJson(json) : null;
  });
});

// ---------------------------------------------------------------------------
// 7. youtubeConnectionProvider
// ---------------------------------------------------------------------------

/// Subscribes to `youtube:getYoutubeConnectionStatus` — whether YouTube OAuth
/// is connected.
///
/// Emits a simple [Map] with at least a `connected` boolean field.
final youtubeConnectionProvider =
    StreamProvider<Map<String, dynamic>?>((ref) {
  final service = ref.watch(convexServiceProvider);
  return service
      .subscribe<dynamic>('youtube:getYoutubeConnectionStatus', {})
      .map((raw) => _decodeMap(raw));
});

// ---------------------------------------------------------------------------
// 8. hiddenItemsProvider
// ---------------------------------------------------------------------------

/// One-shot query for `hidden:getHiddenItems`.
final hiddenItemsProvider = FutureProvider<List<HiddenItem>>((ref) async {
  final service = ref.watch(convexServiceProvider);
  final raw = await service.query<dynamic>('hidden:getHiddenItems', {});
  return _decodeList(raw)
      .map((json) => HiddenItem.fromJson(json))
      .toList(growable: false);
});

// ---------------------------------------------------------------------------
// 9. watchedVideosProvider
// ---------------------------------------------------------------------------

/// One-shot query for `watched:getWatchedVideos`.
final watchedVideosProvider =
    FutureProvider<List<WatchedVideo>>((ref) async {
  final service = ref.watch(convexServiceProvider);
  final raw = await service.query<dynamic>('watched:getWatchedVideos', {});
  return _decodeList(raw)
      .map((json) => WatchedVideo.fromJson(json))
      .toList(growable: false);
});

// ---------------------------------------------------------------------------
// 10. videoProgressProvider(videoId)
// ---------------------------------------------------------------------------

/// One-shot query for `progress:getProgress` for a single video.
///
/// Returns `null` when no progress has been saved for this video.
final videoProgressProvider =
    FutureProvider.family<VideoProgress?, String>((ref, videoId) async {
  final service = ref.watch(convexServiceProvider);
  final raw = await service.query<dynamic>('progress:getProgress', {
    'youtubeVideoId': videoId,
  });
  final json = _decodeMap(raw);
  return json != null ? VideoProgress.fromJson(json) : null;
});

// ---------------------------------------------------------------------------
// 11. quotaUsageProvider
// ---------------------------------------------------------------------------

/// One-shot query for `metrics:getTodayQuotaUsage`.
///
/// Returns the raw map which typically includes `{ used: int, limit: int }`.
final quotaUsageProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final service = ref.watch(convexServiceProvider);
  final raw =
      await service.query<dynamic>('metrics:getTodayQuotaUsage', {});
  return _decodeMap(raw);
});

// ---------------------------------------------------------------------------
// 12. playlistVideosProvider(playlistId)
// ---------------------------------------------------------------------------

/// Subscribes to `youtube:getPlaylistVideos` for a specific playlist.
final playlistVideosProvider =
    StreamProvider.family<List<YouTubeVideo>, String>((ref, playlistId) {
  final service = ref.watch(convexServiceProvider);
  return service
      .subscribe<dynamic>('youtube:getPlaylistVideos', {
        'playlistId': playlistId,
      })
      .map((raw) => _decodeList(raw)
          .map((json) => YouTubeVideo.fromJson(json))
          .toList(growable: false));
});

// ---------------------------------------------------------------------------
// 13. notificationsProvider
// ---------------------------------------------------------------------------

/// Subscribes to `notifications:getNotifications` — current user's notifications.
final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final service = ref.watch(convexServiceProvider);
  return service
      .subscribe<dynamic>('notifications:getNotifications', {})
      .map((raw) => _decodeList(raw)
          .map((json) => AppNotification.fromJson(json))
          .toList(growable: false));
});

// ---------------------------------------------------------------------------
// 14. unreadNotificationCountProvider
// ---------------------------------------------------------------------------

/// Subscribes to `notifications:getUnreadCount` — unread notification count.
final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(convexServiceProvider);
  return service
      .subscribe<dynamic>('notifications:getUnreadCount', {})
      .map((raw) {
    if (raw is int) return raw;
    if (raw is String) {
      final parsed = int.tryParse(raw);
      return parsed ?? 0;
    }
    if (raw is num) return raw.toInt();
    return 0;
  });
});

// ---------------------------------------------------------------------------
// 15. videoNotesProvider(videoId)
// ---------------------------------------------------------------------------

/// Subscribes to `notes:getNotesByYoutubeVideo` for a specific video.
final videoNotesProvider =
    StreamProvider.family<List<Note>, String>((ref, videoId) {
  final service = ref.watch(convexServiceProvider);
  return service
      .subscribe<dynamic>('notes:getNotesByYoutubeVideo', {
        'youtubeVideoId': videoId,
      })
      .map((raw) => _decodeList(raw)
          .map((json) => Note.fromJson(json))
          .toList(growable: false));
});
