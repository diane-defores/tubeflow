/// Model representing a YouTube video cached from a user's playlist.
///
/// Maps to the `youtubeVideosCache` table in Convex, with additional
/// denormalized fields from the parent playlist for display convenience.
class YouTubeVideo {
  /// Convex document ID (`_id`).
  final String id;

  /// YouTube video ID (e.g. "dQw4w9WgXcQ").
  final String youtubeVideoId;

  /// ID of the playlist this video belongs to.
  final String playlistId;

  /// Video title.
  final String title;

  /// Video description (may be truncated by YouTube API).
  final String? description;

  /// URL of the video thumbnail.
  final String? thumbnailUrl;

  /// Name of the YouTube channel that uploaded this video.
  final String channelTitle;

  /// Thumbnail URL of the uploading channel.
  final String? channelThumbnailUrl;

  /// YouTube channel ID of the uploader.
  final String? youtubeChannelId;

  /// ISO 8601 duration string (e.g. "PT5M30S").
  final String? duration;

  /// ISO 8601 publish date from YouTube.
  final String? publishedAt;

  /// Timestamp (ms since epoch) when this entry was cached.
  final int cachedAt;

  /// Hex color code inherited from the parent playlist (e.g. "#8b5cf6").
  final String? playlistColor;

  /// Title of the parent playlist (denormalized for display).
  final String? playlistTitle;

  const YouTubeVideo({
    required this.id,
    required this.youtubeVideoId,
    required this.playlistId,
    required this.title,
    this.description,
    this.thumbnailUrl,
    required this.channelTitle,
    this.channelThumbnailUrl,
    this.youtubeChannelId,
    this.duration,
    this.publishedAt,
    required this.cachedAt,
    this.playlistColor,
    this.playlistTitle,
  });

  factory YouTubeVideo.fromJson(Map<String, dynamic> json) {
    return YouTubeVideo(
      id: json['_id'] as String,
      youtubeVideoId: json['youtubeVideoId'] as String,
      playlistId: json['youtubePlaylistId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      channelTitle: json['channelTitle'] as String,
      channelThumbnailUrl: json['channelThumbnailUrl'] as String?,
      youtubeChannelId: json['youtubeChannelId'] as String?,
      duration: json['duration'] as String?,
      publishedAt: json['publishedAt'] as String?,
      cachedAt: json['cachedAt'] as int,
      playlistColor: json['playlistColor'] as String?,
      playlistTitle: json['playlistTitle'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'youtubeVideoId': youtubeVideoId,
      'youtubePlaylistId': playlistId,
      'title': title,
      if (description != null) 'description': description,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      'channelTitle': channelTitle,
      if (channelThumbnailUrl != null)
        'channelThumbnailUrl': channelThumbnailUrl,
      if (youtubeChannelId != null) 'youtubeChannelId': youtubeChannelId,
      if (duration != null) 'duration': duration,
      if (publishedAt != null) 'publishedAt': publishedAt,
      'cachedAt': cachedAt,
      if (playlistColor != null) 'playlistColor': playlistColor,
      if (playlistTitle != null) 'playlistTitle': playlistTitle,
    };
  }

  YouTubeVideo copyWith({
    String? id,
    String? youtubeVideoId,
    String? playlistId,
    String? title,
    String? description,
    String? thumbnailUrl,
    String? channelTitle,
    String? channelThumbnailUrl,
    String? youtubeChannelId,
    String? duration,
    String? publishedAt,
    int? cachedAt,
    String? playlistColor,
    String? playlistTitle,
  }) {
    return YouTubeVideo(
      id: id ?? this.id,
      youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
      playlistId: playlistId ?? this.playlistId,
      title: title ?? this.title,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      channelTitle: channelTitle ?? this.channelTitle,
      channelThumbnailUrl: channelThumbnailUrl ?? this.channelThumbnailUrl,
      youtubeChannelId: youtubeChannelId ?? this.youtubeChannelId,
      duration: duration ?? this.duration,
      publishedAt: publishedAt ?? this.publishedAt,
      cachedAt: cachedAt ?? this.cachedAt,
      playlistColor: playlistColor ?? this.playlistColor,
      playlistTitle: playlistTitle ?? this.playlistTitle,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is YouTubeVideo &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'YouTubeVideo(id: $id, title: $title)';
}
