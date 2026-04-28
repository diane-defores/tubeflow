/// Model representing a user comment on a YouTube video.
///
/// Maps to the `youtubeComments` table in Convex. These are in-app
/// comments (not YouTube API comments) attached to videos by YouTube ID.
class YouTubeComment {
  /// Convex document ID (`_id`).
  final String id;

  /// YouTube video ID the comment belongs to.
  final String youtubeVideoId;

  /// Clerk user ID of the comment author.
  final String userId;

  /// Comment text content.
  final String content;

  /// Creation timestamp (ms since epoch).
  final int createdAt;

  /// Display name of the comment author (denormalized from user record).
  final String? userName;

  /// Avatar URL of the comment author (denormalized from user record).
  final String? userAvatar;

  const YouTubeComment({
    required this.id,
    required this.youtubeVideoId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.userName,
    this.userAvatar,
  });

  factory YouTubeComment.fromJson(Map<String, dynamic> json) {
    return YouTubeComment(
      id: json['_id'] as String,
      youtubeVideoId: json['youtubeVideoId'] as String,
      userId: json['userId'] as String,
      content: json['content'] as String,
      createdAt: json['createdAt'] as int,
      userName: json['userName'] as String?,
      userAvatar: json['userAvatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'youtubeVideoId': youtubeVideoId,
      'userId': userId,
      'content': content,
      'createdAt': createdAt,
      if (userName != null) 'userName': userName,
      if (userAvatar != null) 'userAvatar': userAvatar,
    };
  }

  YouTubeComment copyWith({
    String? id,
    String? youtubeVideoId,
    String? userId,
    String? content,
    int? createdAt,
    String? userName,
    String? userAvatar,
  }) {
    return YouTubeComment(
      id: id ?? this.id,
      youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is YouTubeComment &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'YouTubeComment(id: $id, userId: $userId)';
}
