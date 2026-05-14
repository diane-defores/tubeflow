/// Model representing a user's playback progress on a video.
///
/// Maps to the `videoProgress` table in Convex. Used to resume
/// playback where the user left off.
class VideoProgress {
  /// Convex document ID (`_id`).
  final String id;

  /// YouTube video ID.
  final String youtubeVideoId;

  /// Current playback position in seconds.
  final double progressSeconds;

  /// Total video duration in seconds (if known).
  final double? durationSeconds;

  /// Timestamp (ms since epoch) of the last progress update.
  final int updatedAt;

  const VideoProgress({
    required this.id,
    required this.youtubeVideoId,
    required this.progressSeconds,
    this.durationSeconds,
    required this.updatedAt,
  });

  /// Completion percentage (0.0 to 1.0), or null if duration is unknown.
  double? get completionRatio {
    if (durationSeconds == null || durationSeconds! <= 0) return null;
    return (progressSeconds / durationSeconds!).clamp(0.0, 1.0);
  }

  /// Completion as an integer percentage (0-100), or null if duration is unknown.
  int? get completionPercent {
    final ratio = completionRatio;
    return ratio != null ? (ratio * 100).round() : null;
  }

  /// Formats [progressSeconds] as "MM:SS" or "HH:MM:SS".
  String get formattedProgress => _formatDuration(progressSeconds);

  /// Formats [durationSeconds] as "MM:SS" or "HH:MM:SS", or empty string if unknown.
  String get formattedDuration =>
      durationSeconds != null ? _formatDuration(durationSeconds!) : '';

  static String _formatDuration(double seconds) {
    final totalSeconds = seconds.round();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final secs = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }

  factory VideoProgress.fromJson(Map<String, dynamic> json) {
    return VideoProgress(
      id: json['_id'] as String,
      youtubeVideoId: json['youtubeVideoId'] as String,
      progressSeconds: (json['progressSeconds'] as num).toDouble(),
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
      updatedAt: json['updatedAt'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'youtubeVideoId': youtubeVideoId,
      'progressSeconds': progressSeconds,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      'updatedAt': updatedAt,
    };
  }

  VideoProgress copyWith({
    String? id,
    String? youtubeVideoId,
    double? progressSeconds,
    double? durationSeconds,
    int? updatedAt,
  }) {
    return VideoProgress(
      id: id ?? this.id,
      youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
      progressSeconds: progressSeconds ?? this.progressSeconds,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoProgress &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'VideoProgress(id: $id, youtubeVideoId: $youtubeVideoId, '
      'progress: $formattedProgress)';
}
