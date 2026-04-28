enum FeedbackEntryType {
  text,
  audio;

  static FeedbackEntryType fromJson(String value) {
    return FeedbackEntryType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => FeedbackEntryType.text,
    );
  }
}

enum FeedbackEntryStatus {
  newEntry('new'),
  reviewed('reviewed');

  const FeedbackEntryStatus(this.jsonValue);

  final String jsonValue;

  static FeedbackEntryStatus fromJson(String value) {
    return FeedbackEntryStatus.values.firstWhere(
      (status) => status.jsonValue == value,
      orElse: () => FeedbackEntryStatus.newEntry,
    );
  }
}

class FeedbackEntry {
  const FeedbackEntry({
    required this.id,
    required this.type,
    required this.status,
    required this.platform,
    required this.locale,
    required this.createdAt,
    this.message,
    this.audioStorageId,
    this.audioDurationMs,
    this.audioUrl,
    this.buildCommitSha,
    this.buildEnvironment,
    this.buildTimestamp,
    this.userId,
    this.userEmail,
    this.reviewedAt,
    this.reviewedByEmail,
  });

  final String id;
  final FeedbackEntryType type;
  final FeedbackEntryStatus status;
  final String? message;
  final String? audioStorageId;
  final int? audioDurationMs;
  final String? audioUrl;
  final String platform;
  final String locale;
  final String? buildCommitSha;
  final String? buildEnvironment;
  final String? buildTimestamp;
  final String? userId;
  final String? userEmail;
  final int createdAt;
  final int? reviewedAt;
  final String? reviewedByEmail;

  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;
  bool get isAnonymous => userEmail == null || userEmail!.isEmpty;
  bool get isUnread => status == FeedbackEntryStatus.newEntry;

  String? get buildCommitShort {
    final value = buildCommitSha;
    if (value == null || value.isEmpty) return null;
    if (value.length <= 7) return value;
    return value.substring(0, 7);
  }

  factory FeedbackEntry.fromJson(Map<String, dynamic> json) {
    return FeedbackEntry(
      id: (json['id'] ?? json['_id']) as String,
      type: FeedbackEntryType.fromJson(json['type'] as String? ?? 'text'),
      status: FeedbackEntryStatus.fromJson(
        json['status'] as String? ?? 'new',
      ),
      message: json['message'] as String?,
      audioStorageId: json['audioStorageId'] as String?,
      audioDurationMs: json['audioDurationMs'] as int?,
      audioUrl: json['audioUrl'] as String?,
      platform: json['platform'] as String? ?? 'other',
      locale: json['locale'] as String? ?? 'en',
      buildCommitSha: json['buildCommitSha'] as String?,
      buildEnvironment: json['buildEnvironment'] as String?,
      buildTimestamp: json['buildTimestamp'] as String?,
      userId: json['userId'] as String?,
      userEmail: json['userEmail'] as String?,
      createdAt: json['createdAt'] as int? ?? 0,
      reviewedAt: json['reviewedAt'] as int?,
      reviewedByEmail: json['reviewedByEmail'] as String?,
    );
  }
}
