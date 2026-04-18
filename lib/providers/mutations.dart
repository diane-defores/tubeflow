import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tubeflow_app/convex/convex_provider.dart';

// =============================================================================
// Convex mutation helpers for the TubeFlow app.
//
// Each function accepts a [Ref] (or [WidgetRef]) so it can access the
// [ConvexService] singleton through Riverpod, then calls the appropriate
// Convex mutation and returns the decoded result.
//
// Usage from a widget:
//
//   ElevatedButton(
//     onPressed: () => createNote(ref,
//       videoId: video.youtubeVideoId,
//       content: _controller.text,
//       timestamp: _player.position.inSeconds.toDouble(),
//     ),
//     child: Text('Save Note'),
//   )
//
// Usage from another provider / notifier:
//
//   await createNote(ref, videoId: id, content: text);
//
// After a mutation that changes data read by a FutureProvider, callers should
// invalidate the relevant provider:
//
//   ref.invalidate(hiddenItemsProvider);
//
// StreamProvider-backed data updates automatically via Convex subscriptions.
// =============================================================================

// ---------------------------------------------------------------------------
// Notes
// ---------------------------------------------------------------------------

/// Creates a new note, optionally linked to a video at a timestamp.
///
/// Returns the Convex document ID of the created note.
Future<dynamic> createNote(
  WidgetRef ref, {
  required String videoId,
  required String content,
  double? timestamp,
  String? title,
}) async {
  final service = ref.read(convexServiceProvider);
  return service.mutate<dynamic>('notes:createNote', {
    'youtubeVideoId': videoId,
    'content': content,
    if (timestamp != null) 'timestamp': timestamp,
    if (title != null) 'title': title,
  });
}

/// Updates the content of an existing note.
Future<dynamic> updateNote(WidgetRef ref, String noteId, String content) async {
  final service = ref.read(convexServiceProvider);
  return service.mutate<dynamic>('notes:updateNote', {
    'noteId': noteId,
    'content': content,
  });
}

/// Deletes a note by its Convex document ID.
Future<dynamic> deleteNote(WidgetRef ref, String noteId) async {
  final service = ref.read(convexServiceProvider);
  return service.mutate<dynamic>('notes:deleteNote', {
    'noteId': noteId,
  });
}

// ---------------------------------------------------------------------------
// Hidden items
// ---------------------------------------------------------------------------

/// Hides a video from the user's feed.
Future<dynamic> hideVideo(WidgetRef ref, String videoId) async {
  final service = ref.read(convexServiceProvider);
  return service.mutate<dynamic>('hidden:hideItem', {
    'youtubeId': videoId,
    'itemType': 'video',
  });
}

/// Hides a playlist from the user's feed.
Future<dynamic> hidePlaylist(WidgetRef ref, String playlistId) async {
  final service = ref.read(convexServiceProvider);
  return service.mutate<dynamic>('hidden:hideItem', {
    'youtubeId': playlistId,
    'itemType': 'playlist',
  });
}

/// Un-hides a previously hidden video, restoring it to the feed.
Future<dynamic> unhideVideo(WidgetRef ref, String videoId) async {
  final service = ref.read(convexServiceProvider);
  return service.mutate<dynamic>('hidden:unhideItem', {
    'youtubeId': videoId,
    'itemType': 'video',
  });
}

/// Un-hides a hidden item by its Convex document ID.
Future<dynamic> unhideItem(WidgetRef ref, String hiddenItemId) async {
  final service = ref.read(convexServiceProvider);
  return service.mutate<dynamic>('hidden:unhideItem', {
    'hiddenItemId': hiddenItemId,
  });
}

// ---------------------------------------------------------------------------
// Watch history
// ---------------------------------------------------------------------------

/// Marks a video as watched.
Future<dynamic> markWatched(WidgetRef ref, String videoId) async {
  final service = ref.read(convexServiceProvider);
  return service.mutate<dynamic>('watched:markWatched', {
    'youtubeVideoId': videoId,
  });
}

/// Removes the watched mark from a video.
Future<dynamic> unmarkWatched(WidgetRef ref, String videoId) async {
  final service = ref.read(convexServiceProvider);
  return service.mutate<dynamic>('watched:unmarkWatched', {
    'youtubeVideoId': videoId,
  });
}

// ---------------------------------------------------------------------------
// Playback progress
// ---------------------------------------------------------------------------

/// Saves (upserts) the user's playback progress for a video.
///
/// [seconds] is the current playback position. [duration] is the total video
/// length in seconds. Both values use fractional seconds.
Future<dynamic> saveProgress(
  WidgetRef ref,
  String videoId,
  double seconds,
  double duration,
) async {
  final service = ref.read(convexServiceProvider);
  return service.mutate<dynamic>('progress:saveProgress', {
    'youtubeVideoId': videoId,
    'progressSeconds': seconds,
    'durationSeconds': duration,
  });
}

/// Upserts the current playback position for a video (best-effort).
///
/// Unlike [saveProgress], this does not require a duration. Use for
/// mid-session saves (pause, background, dispose).
Future<dynamic> upsertProgress(
  WidgetRef ref,
  String videoId,
  double progressSeconds,
) async {
  final service = ref.read(convexServiceProvider);
  return service.mutate<dynamic>('progress:upsertProgress', {
    'videoId': videoId,
    'progressSeconds': progressSeconds,
  });
}

// ---------------------------------------------------------------------------
// Playlists
// ---------------------------------------------------------------------------

/// Triggers a YouTube sync for all playlists.
Future<dynamic> syncAllPlaylists(WidgetRef ref) async {
  final service = ref.read(convexServiceProvider);
  return service.mutate<dynamic>('youtube:syncAllPlaylists', {});
}

/// Triggers a YouTube sync for a single playlist.
Future<dynamic> syncPlaylist(WidgetRef ref, String playlistId) async {
  final service = ref.read(convexServiceProvider);
  return service.mutate<dynamic>('youtube:syncPlaylist', {
    'playlistId': playlistId,
  });
}

/// Disconnects the current YouTube account and clears cached playlist data.
Future<dynamic> disconnectYoutube(WidgetRef ref) async {
  final service = ref.read(convexServiceProvider);
  return service.mutate<dynamic>('youtube:disconnectYoutube', {});
}

/// Removes a video from a playlist.
Future<dynamic> removeVideoFromPlaylist(
  WidgetRef ref, {
  required String playlistId,
  required String videoId,
}) async {
  final service = ref.read(convexServiceProvider);
  return service.mutate<dynamic>('playlists:removeVideoFromPlaylist', {
    'playlistId': playlistId,
    'videoId': videoId,
  });
}

/// Creates a new playlist.
///
/// Returns the Convex document ID of the created playlist.
Future<dynamic> createPlaylist(
  WidgetRef ref, {
  required String title,
  String? description,
  String privacyStatus = 'private',
  String? color,
}) async {
  final service = ref.read(convexServiceProvider);
  return service.mutate<dynamic>('playlists:createPlaylist', {
    'title': title,
    if (description != null) 'description': description,
    'privacyStatus': privacyStatus,
    if (color != null) 'color': color,
  });
}

// ---------------------------------------------------------------------------
// Likes
// ---------------------------------------------------------------------------

/// Toggles a like or dislike on a video.
///
/// [type] should be `'like'` or `'dislike'`. Toggling the same type twice
/// removes the interaction.
Future<dynamic> toggleLike(
  WidgetRef ref,
  String videoId,
  String type,
) async {
  final service = ref.read(convexServiceProvider);
  return service.mutate<dynamic>('likes:toggleLike', {
    'youtubeVideoId': videoId,
    'type': type,
  });
}

// ---------------------------------------------------------------------------
// Comments
// ---------------------------------------------------------------------------

/// Creates a comment on a video.
///
/// Returns the Convex document ID of the created comment.
Future<dynamic> createComment(
  WidgetRef ref,
  String videoId,
  String content,
) async {
  final service = ref.read(convexServiceProvider);
  return service.mutate<dynamic>('comments:createComment', {
    'youtubeVideoId': videoId,
    'content': content,
  });
}

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

/// Marks a single notification as read.
Future<dynamic> markNotificationRead(
  WidgetRef ref,
  String notificationId,
) async {
  final service = ref.read(convexServiceProvider);
  return service.mutate<dynamic>('notifications:markAsRead', {
    'notificationId': notificationId,
  });
}

/// Marks all unread notifications as read.
Future<dynamic> markAllNotificationsRead(WidgetRef ref) async {
  final service = ref.read(convexServiceProvider);
  return service.mutate<dynamic>('notifications:markAllAsRead', {});
}

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

/// Updates user settings with a raw patch map. Only the provided fields are
/// patched; omitted fields remain unchanged on the server.
///
/// Example:
/// ```dart
/// await updateSettings(ref, {'theme': 'dark'});
/// await updateSettings(ref, {'playback': {'speed': 1.5}});
/// ```
Future<dynamic> updateSettings(
  WidgetRef ref,
  Map<String, dynamic> patch,
) async {
  final service = ref.read(convexServiceProvider);
  return service.mutate<dynamic>('settings:updateAllSettings', patch);
}
