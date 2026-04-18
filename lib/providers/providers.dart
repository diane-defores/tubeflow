import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tubeflow_app/auth/auth_state.dart';
import 'package:tubeflow_app/convex/convex_client.dart';
import 'package:tubeflow_app/convex/convex_provider.dart';
import 'package:tubeflow_app/models/models.dart';
import 'package:tubeflow_app/utils/app_logger.dart';

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

Map<String, dynamic> _normalizeSettingsMap(
  Map<String, dynamic>? raw,
  AuthUser user,
) {
  final json = <String, dynamic>{...?raw};
  json['_id'] ??= 'settings:${user.id}';
  json['userId'] ??= user.id;
  json['theme'] ??= 'system';
  json['language'] ??= 'en';
  json['notifications'] ??= <String, dynamic>{
    'email': true,
    'push': true,
    'newComments': true,
    'newLikes': false,
    'newVideos': true,
    'feedRefreshIntervalMinutes': 60,
  };
  json['playback'] ??= <String, dynamic>{
    'autoplay': true,
    'defaultQuality': 'auto',
    'defaultSpeed': 1,
    'mobileControlsPosition': 'bottom',
    'captionsEnabled': false,
    'autoMarkWatchedThreshold': 0.9,
  };
  json['notes'] ??= <String, dynamic>{
    'defaultTimestamped': true,
    'sortOrder': 'asc',
  };
  json['channelSync'] ??= <String, dynamic>{
    'autoSyncOnVisit': false,
    'syncIntervalMinutes': 0,
  };
  json['transcripts'] ??= <String, dynamic>{
    'defaultLanguage': 'en',
    'autoAttemptYoutubeCaptions': true,
    'autoAttemptLocalFallback': true,
    'sortBy': 'recommended',
  };
  return json;
}

Map<String, dynamic> _normalizeSubscriptionMap(
  Map<String, dynamic>? raw,
  AuthUser user,
) {
  final json = <String, dynamic>{...?raw};
  json['_id'] ??= 'subscription:${user.id}';
  json['userId'] ??= user.id;
  json['plan'] ??= 'free';
  json['status'] ??= 'active';
  json['features'] ??= <String, dynamic>{
    'maxVideos': 10,
    'maxNotesPerVideo': 50,
    'maxPlaylists': 3,
    'aiSummaries': false,
    'exportNotes': false,
  };
  json['cancelAtPeriodEnd'] ??= false;
  json['createdAt'] ??= 0;
  json['updatedAt'] ??= 0;
  return json;
}

class PreferencesData {
  const PreferencesData({
    required this.settings,
    required this.subscription,
    required this.user,
  });

  final UserSettings settings;
  final UserSubscription subscription;
  final TubeFlowUser? user;
}

TubeFlowUser _fallbackUserFromAuth(AuthUser user) {
  return TubeFlowUser(
    id: 'user:${user.id}',
    clerkId: user.id,
    email: user.email,
    name: user.displayName,
    avatarUrl: user.imageUrl,
    youtubeConnected: false,
    createdAt: 0,
    updatedAt: 0,
  );
}

Future<dynamic> _queryWithTimeout(
  ConvexService service,
  String path,
  Map<String, dynamic> args,
) async {
  return service
      .query<dynamic>(path, args)
      .timeout(const Duration(seconds: 8));
}

Future<dynamic> _mutateWithTimeout(
  ConvexService service,
  String path,
  Map<String, dynamic> args,
) async {
  return service
      .mutate<dynamic>(path, args)
      .timeout(const Duration(seconds: 8));
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

/// One-shot query for `youtube:getYoutubeConnectionStatus`.
///
/// This intentionally uses [ConvexService.query] instead of a websocket
/// subscription because the web app already has a more reliable HTTP path for
/// one-shot reads than for auth-sensitive realtime subscriptions.
final youtubeConnectionProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final service = ref.watch(convexServiceProvider);
  final raw = await service.query<dynamic>(
    'youtube:getYoutubeConnectionStatus',
    {},
  );
  return _decodeMap(raw);
});

// ---------------------------------------------------------------------------
// Preferences data provider
// ---------------------------------------------------------------------------

/// Loads the Preferences screen data in a robust, one-shot flow:
/// 1. ensure the Convex user exists
/// 2. fetch settings, subscription, and current user
///
/// This intentionally uses queries instead of subscriptions to avoid the
/// "infinite shimmer" case when a real-time subscription is established before
/// Convex auth is fully ready.
final preferencesDataProvider = FutureProvider<PreferencesData?>((ref) async {
  final authState = ref.watch(authStateProvider);
  if (authState is! AuthAuthenticated) {
    return null;
  }

  final service = ref.watch(convexServiceProvider);
  final authUser = authState.user;

  AppLogger.instance.log(
    'preferencesDataProvider start for ${authUser.id}',
    source: 'PreferencesData',
  );

  try {
    await _mutateWithTimeout(service, 'users:ensureUser', {
      'email': authUser.email,
      if (authUser.displayName != null) 'name': authUser.displayName,
      if (authUser.imageUrl != null) 'avatarUrl': authUser.imageUrl,
    });
    AppLogger.instance.log(
      'users:ensureUser succeeded',
      source: 'PreferencesData',
    );
  } catch (e, st) {
    AppLogger.instance.log(
      'users:ensureUser failed; falling back to local defaults',
      source: 'PreferencesData',
      level: LogLevel.warning,
      error: e,
      stackTrace: st,
    );
  }

  dynamic settingsRaw;
  dynamic subscriptionRaw;
  dynamic currentUserRaw;

  try {
    settingsRaw = await _queryWithTimeout(service, 'settings:getSettings', {});
    AppLogger.instance.log(
      'settings:getSettings succeeded',
      source: 'PreferencesData',
    );
  } catch (e, st) {
    AppLogger.instance.log(
      'settings:getSettings failed; using defaults',
      source: 'PreferencesData',
      level: LogLevel.warning,
      error: e,
      stackTrace: st,
    );
  }

  try {
    subscriptionRaw = await _queryWithTimeout(
      service,
      'subscriptions:getSubscription',
      {},
    );
    AppLogger.instance.log(
      'subscriptions:getSubscription succeeded',
      source: 'PreferencesData',
    );
  } catch (e, st) {
    AppLogger.instance.log(
      'subscriptions:getSubscription failed; using free plan fallback',
      source: 'PreferencesData',
      level: LogLevel.warning,
      error: e,
      stackTrace: st,
    );
  }

  try {
    currentUserRaw = await _queryWithTimeout(service, 'users:getCurrentUser', {});
    AppLogger.instance.log(
      'users:getCurrentUser succeeded',
      source: 'PreferencesData',
    );
  } catch (e, st) {
    AppLogger.instance.log(
      'users:getCurrentUser failed; using auth fallback user',
      source: 'PreferencesData',
      level: LogLevel.warning,
      error: e,
      stackTrace: st,
    );
  }

  final settings = UserSettings.fromJson(
    _normalizeSettingsMap(_decodeMap(settingsRaw), authUser),
  );
  final subscription = UserSubscription.fromJson(
    _normalizeSubscriptionMap(_decodeMap(subscriptionRaw), authUser),
  );
  final userJson = _decodeMap(currentUserRaw);
  final user = userJson != null
      ? TubeFlowUser.fromJson(userJson)
      : _fallbackUserFromAuth(authUser);

  return PreferencesData(
    settings: settings,
    subscription: subscription,
    user: user,
  );
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
