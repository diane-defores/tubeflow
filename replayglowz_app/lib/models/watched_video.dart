/// Model representing a video the user has watched.
///
/// Maps to the `watchedVideos` table in Convex. Used for watch history
/// display and to visually mark videos as seen in playlists.
class WatchedVideo {
  /// Convex document ID (`_id`).
  final String id;

  /// YouTube video ID that was watched.
  final String youtubeVideoId;

  /// Timestamp (ms since epoch) when the video was marked as watched.
  final int watchedAt;

  const WatchedVideo({
    required this.id,
    required this.youtubeVideoId,
    required this.watchedAt,
  });

  factory WatchedVideo.fromJson(Map<String, dynamic> json) {
    return WatchedVideo(
      id: json['_id'] as String,
      youtubeVideoId: json['youtubeVideoId'] as String,
      watchedAt: json['watchedAt'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'youtubeVideoId': youtubeVideoId,
      'watchedAt': watchedAt,
    };
  }

  WatchedVideo copyWith({String? id, String? youtubeVideoId, int? watchedAt}) {
    return WatchedVideo(
      id: id ?? this.id,
      youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
      watchedAt: watchedAt ?? this.watchedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchedVideo &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'WatchedVideo(id: $id, youtubeVideoId: $youtubeVideoId)';
}
