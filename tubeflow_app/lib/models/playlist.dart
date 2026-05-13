/// Model representing a YouTube playlist cached from the user's account.
///
/// Maps to the `youtubePlaylistsCache` table in Convex, with additional
/// computed fields used by the Flutter UI.
class YouTubePlaylist {
  /// Convex document ID (`_id`).
  final String id;

  /// YouTube playlist ID (e.g. "PLrAXtmErZgOeiKm4sgNOknGvNjby9efdf").
  final String youtubePlaylistId;

  /// Playlist title.
  final String title;

  /// Playlist description.
  final String? description;

  /// Default thumbnail URL from YouTube.
  final String? thumbnailUrl;

  /// User-chosen custom thumbnail URL (overrides [thumbnailUrl] when set).
  final String? customThumbnailUrl;

  /// Current number of videos in the local cache.
  final int videoCount;

  /// Original video count as reported by YouTube API.
  final int originalVideoCount;

  /// YouTube privacy status (e.g. "public", "private", "unlisted").
  final String privacyStatus;

  /// ISO 8601 publish date from YouTube.
  final String? publishedAt;

  /// Timestamp (ms since epoch) of the most recently added video.
  final int? lastVideoAddedAt;

  /// Timestamp (ms since epoch) when this entry was cached.
  final int cachedAt;

  /// Whether the cached data is considered stale and should be refreshed.
  final bool isStale;

  /// Hex color code for playlist theming (e.g. "#8b5cf6").
  final String? color;

  const YouTubePlaylist({
    required this.id,
    required this.youtubePlaylistId,
    required this.title,
    this.description,
    this.thumbnailUrl,
    this.customThumbnailUrl,
    required this.videoCount,
    required this.originalVideoCount,
    required this.privacyStatus,
    this.publishedAt,
    this.lastVideoAddedAt,
    required this.cachedAt,
    required this.isStale,
    this.color,
  });

  /// Returns the best available thumbnail: custom first, then YouTube default.
  String? get effectiveThumbnailUrl => customThumbnailUrl ?? thumbnailUrl;

  factory YouTubePlaylist.fromJson(Map<String, dynamic> json) {
    return YouTubePlaylist(
      id: json['_id'] as String,
      youtubePlaylistId: json['youtubePlaylistId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      customThumbnailUrl: json['customThumbnailUrl'] as String?,
      videoCount: json['videoCount'] as int,
      originalVideoCount:
          json['originalVideoCount'] as int? ?? json['videoCount'] as int,
      privacyStatus: json['privacyStatus'] as String,
      publishedAt: json['publishedAt'] as String?,
      lastVideoAddedAt: json['lastVideoAddedAt'] as int?,
      cachedAt: json['cachedAt'] as int,
      isStale: json['isStale'] as bool? ?? false,
      color: json['color'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'youtubePlaylistId': youtubePlaylistId,
      'title': title,
      if (description != null) 'description': description,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (customThumbnailUrl != null) 'customThumbnailUrl': customThumbnailUrl,
      'videoCount': videoCount,
      'originalVideoCount': originalVideoCount,
      'privacyStatus': privacyStatus,
      if (publishedAt != null) 'publishedAt': publishedAt,
      if (lastVideoAddedAt != null) 'lastVideoAddedAt': lastVideoAddedAt,
      'cachedAt': cachedAt,
      'isStale': isStale,
      if (color != null) 'color': color,
    };
  }

  YouTubePlaylist copyWith({
    String? id,
    String? youtubePlaylistId,
    String? title,
    String? description,
    String? thumbnailUrl,
    String? customThumbnailUrl,
    int? videoCount,
    int? originalVideoCount,
    String? privacyStatus,
    String? publishedAt,
    int? lastVideoAddedAt,
    int? cachedAt,
    bool? isStale,
    String? color,
  }) {
    return YouTubePlaylist(
      id: id ?? this.id,
      youtubePlaylistId: youtubePlaylistId ?? this.youtubePlaylistId,
      title: title ?? this.title,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      customThumbnailUrl: customThumbnailUrl ?? this.customThumbnailUrl,
      videoCount: videoCount ?? this.videoCount,
      originalVideoCount: originalVideoCount ?? this.originalVideoCount,
      privacyStatus: privacyStatus ?? this.privacyStatus,
      publishedAt: publishedAt ?? this.publishedAt,
      lastVideoAddedAt: lastVideoAddedAt ?? this.lastVideoAddedAt,
      cachedAt: cachedAt ?? this.cachedAt,
      isStale: isStale ?? this.isStale,
      color: color ?? this.color,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is YouTubePlaylist &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'YouTubePlaylist(id: $id, title: $title)';
}
