/// Notification type identifiers matching Convex schema.
enum NotificationType {
  newVideo,
  transcriptReady,
  system;

  static NotificationType fromJson(String? value) {
    switch (value) {
      case 'new_video':
        return NotificationType.newVideo;
      case 'transcript_ready':
        return NotificationType.transcriptReady;
      case 'system':
      default:
        return NotificationType.system;
    }
  }

  String toJson() {
    switch (this) {
      case NotificationType.newVideo:
        return 'new_video';
      case NotificationType.transcriptReady:
        return 'transcript_ready';
      case NotificationType.system:
        return 'system';
    }
  }
}

/// A user notification from the Convex `notifications` table.
class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String? body;
  final String? youtubeVideoId;
  final String? youtubeChannelId;
  final String? thumbnailUrl;
  final bool read;
  final int createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    this.body,
    this.youtubeVideoId,
    this.youtubeChannelId,
    this.thumbnailUrl,
    this.read = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['_id'] as String,
      userId: json['userId'] as String,
      type: NotificationType.fromJson(json['type'] as String?),
      title: json['title'] as String,
      body: json['body'] as String?,
      youtubeVideoId: json['youtubeVideoId'] as String?,
      youtubeChannelId: json['youtubeChannelId'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      read: json['read'] as bool? ?? false,
      createdAt: json['createdAt'] as int,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotification &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
