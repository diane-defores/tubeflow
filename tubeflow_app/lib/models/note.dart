/// Model representing a user note, optionally linked to a YouTube video
/// at a specific timestamp.
///
/// Maps to the `notes` table in Convex.
class Note {
  /// Convex document ID (`_id`).
  final String id;

  /// Clerk user ID of the note owner.
  final String userId;

  /// Note title.
  final String title;

  /// Note content (plain text or markdown).
  final String content;

  /// AI-generated summary of the note content.
  final String? summary;

  /// YouTube video ID this note is attached to (null for standalone notes).
  final String? youtubeVideoId;

  /// Video timestamp in seconds where this note was taken.
  final double? timestamp;

  /// Creation timestamp (ms since epoch).
  final int? createdAt;

  const Note({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    this.summary,
    this.youtubeVideoId,
    this.timestamp,
    this.createdAt,
  });

  /// Whether this note is attached to a specific video timestamp.
  bool get isTimestamped => youtubeVideoId != null && timestamp != null;

  /// Formats the timestamp as "MM:SS" or "HH:MM:SS" for display.
  String? get formattedTimestamp {
    if (timestamp == null) return null;
    final totalSeconds = timestamp!.round();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['_id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      summary: json['summary'] as String?,
      youtubeVideoId: json['youtubeVideoId'] as String?,
      timestamp: (json['timestamp'] as num?)?.toDouble(),
      createdAt: json['createdAt'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'title': title,
      'content': content,
      if (summary != null) 'summary': summary,
      if (youtubeVideoId != null) 'youtubeVideoId': youtubeVideoId,
      if (timestamp != null) 'timestamp': timestamp,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }

  Note copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    String? summary,
    String? youtubeVideoId,
    double? timestamp,
    int? createdAt,
  }) {
    return Note(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      summary: summary ?? this.summary,
      youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Note && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Note(id: $id, title: $title)';
}
