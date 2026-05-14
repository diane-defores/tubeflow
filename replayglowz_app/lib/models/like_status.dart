/// The type of like interaction a user can have on a video.
enum LikeType {
  like,
  dislike;

  static LikeType? fromJson(String? value) {
    switch (value) {
      case 'like':
        return LikeType.like;
      case 'dislike':
        return LikeType.dislike;
      default:
        return null;
    }
  }

  String toJson() => name;
}

/// Aggregated like/dislike status for a video, including the current
/// user's interaction.
///
/// This is a computed model assembled from the `youtubeLikes` table in
/// Convex -- it is not a direct table mapping but rather a query result.
class LikeStatus {
  /// The current user's like state (null if they haven't interacted).
  final LikeType? userLike;

  /// Total number of likes on the video.
  final int likeCount;

  /// Total number of dislikes on the video.
  final int dislikeCount;

  const LikeStatus({this.userLike, this.likeCount = 0, this.dislikeCount = 0});

  /// Whether the current user has liked this video.
  bool get isLiked => userLike == LikeType.like;

  /// Whether the current user has disliked this video.
  bool get isDisliked => userLike == LikeType.dislike;

  /// Whether the current user has any interaction on this video.
  bool get hasInteraction => userLike != null;

  /// Net score (likes minus dislikes).
  int get netScore => likeCount - dislikeCount;

  factory LikeStatus.fromJson(Map<String, dynamic> json) {
    return LikeStatus(
      userLike: LikeType.fromJson(json['userLike'] as String?),
      likeCount: json['likeCount'] as int? ?? 0,
      dislikeCount: json['dislikeCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userLike': userLike?.toJson(),
      'likeCount': likeCount,
      'dislikeCount': dislikeCount,
    };
  }

  LikeStatus copyWith({
    LikeType? userLike,
    int? likeCount,
    int? dislikeCount,
    bool clearUserLike = false,
  }) {
    return LikeStatus(
      userLike: clearUserLike ? null : (userLike ?? this.userLike),
      likeCount: likeCount ?? this.likeCount,
      dislikeCount: dislikeCount ?? this.dislikeCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LikeStatus &&
          runtimeType == other.runtimeType &&
          userLike == other.userLike &&
          likeCount == other.likeCount &&
          dislikeCount == other.dislikeCount;

  @override
  int get hashCode => Object.hash(userLike, likeCount, dislikeCount);

  @override
  String toString() =>
      'LikeStatus(userLike: ${userLike?.name}, '
      'likes: $likeCount, dislikes: $dislikeCount)';
}
