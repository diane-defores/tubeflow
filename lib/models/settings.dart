/// Theme preference for the application.
enum ThemeMode {
  light,
  dark,
  system;

  static ThemeMode fromJson(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  String toJson() => name;
}

/// Position of mobile video player controls overlay.
enum MobileControlsPosition {
  bottom,
  player;

  static MobileControlsPosition fromJson(String? value) {
    switch (value) {
      case 'player':
        return MobileControlsPosition.player;
      case 'bottom':
      default:
        return MobileControlsPosition.bottom;
    }
  }

  String toJson() => name;
}

/// Sort direction for notes display.
enum NoteSortOrder {
  asc,
  desc;

  static NoteSortOrder fromJson(String? value) {
    switch (value) {
      case 'asc':
        return NoteSortOrder.asc;
      case 'desc':
      default:
        return NoteSortOrder.desc;
    }
  }

  String toJson() => name;
}

/// Transcript provider identifier.
enum TranscriptProvider {
  youtubeCaptions,
  fasterWhisper,
  sensevoice,
  openaiMini,
  openai,
  deepgram;

  static TranscriptProvider? fromJson(String? value) {
    switch (value) {
      case 'youtube_captions':
        return TranscriptProvider.youtubeCaptions;
      case 'faster_whisper':
        return TranscriptProvider.fasterWhisper;
      case 'sensevoice':
        return TranscriptProvider.sensevoice;
      case 'openai_mini':
        return TranscriptProvider.openaiMini;
      case 'openai':
        return TranscriptProvider.openai;
      case 'deepgram':
        return TranscriptProvider.deepgram;
      default:
        return null;
    }
  }

  String toJson() {
    switch (this) {
      case TranscriptProvider.youtubeCaptions:
        return 'youtube_captions';
      case TranscriptProvider.fasterWhisper:
        return 'faster_whisper';
      case TranscriptProvider.sensevoice:
        return 'sensevoice';
      case TranscriptProvider.openaiMini:
        return 'openai_mini';
      case TranscriptProvider.openai:
        return 'openai';
      case TranscriptProvider.deepgram:
        return 'deepgram';
    }
  }
}

/// Sort criteria for transcript provider list.
enum TranscriptSortBy {
  recommended,
  price,
  speed,
  quality,
  name;

  static TranscriptSortBy fromJson(String? value) {
    switch (value) {
      case 'price':
        return TranscriptSortBy.price;
      case 'speed':
        return TranscriptSortBy.speed;
      case 'quality':
        return TranscriptSortBy.quality;
      case 'name':
        return TranscriptSortBy.name;
      case 'recommended':
      default:
        return TranscriptSortBy.recommended;
    }
  }

  String toJson() => name;
}

// ---------------------------------------------------------------------------
// Nested settings objects
// ---------------------------------------------------------------------------

/// Notification preferences.
class NotificationSettings {
  final bool email;
  final bool push;
  final bool newComments;
  final bool newLikes;

  const NotificationSettings({
    this.email = true,
    this.push = true,
    this.newComments = true,
    this.newLikes = true,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const NotificationSettings();
    return NotificationSettings(
      email: json['email'] as bool? ?? true,
      push: json['push'] as bool? ?? true,
      newComments: json['newComments'] as bool? ?? true,
      newLikes: json['newLikes'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'push': push,
      'newComments': newComments,
      'newLikes': newLikes,
    };
  }

  NotificationSettings copyWith({
    bool? email,
    bool? push,
    bool? newComments,
    bool? newLikes,
  }) {
    return NotificationSettings(
      email: email ?? this.email,
      push: push ?? this.push,
      newComments: newComments ?? this.newComments,
      newLikes: newLikes ?? this.newLikes,
    );
  }
}

/// Video playback preferences.
class PlaybackSettings {
  final bool autoplay;
  final String? defaultQuality;
  final double? defaultSpeed;
  final MobileControlsPosition? mobileControlsPosition;
  final bool? captionsEnabled;
  final String? captionsLanguage;

  /// Percentage (0.0-1.0) of video watched before auto-marking as watched.
  final double? autoMarkWatchedThreshold;

  const PlaybackSettings({
    this.autoplay = true,
    this.defaultQuality,
    this.defaultSpeed,
    this.mobileControlsPosition,
    this.captionsEnabled,
    this.captionsLanguage,
    this.autoMarkWatchedThreshold,
  });

  factory PlaybackSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PlaybackSettings();
    return PlaybackSettings(
      autoplay: json['autoplay'] as bool? ?? true,
      defaultQuality: json['defaultQuality'] as String?,
      defaultSpeed: (json['defaultSpeed'] as num?)?.toDouble(),
      mobileControlsPosition: json['mobileControlsPosition'] != null
          ? MobileControlsPosition.fromJson(
              json['mobileControlsPosition'] as String?)
          : null,
      captionsEnabled: json['captionsEnabled'] as bool?,
      captionsLanguage: json['captionsLanguage'] as String?,
      autoMarkWatchedThreshold:
          (json['autoMarkWatchedThreshold'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'autoplay': autoplay,
      if (defaultQuality != null) 'defaultQuality': defaultQuality,
      if (defaultSpeed != null) 'defaultSpeed': defaultSpeed,
      if (mobileControlsPosition != null)
        'mobileControlsPosition': mobileControlsPosition!.toJson(),
      if (captionsEnabled != null) 'captionsEnabled': captionsEnabled,
      if (captionsLanguage != null) 'captionsLanguage': captionsLanguage,
      if (autoMarkWatchedThreshold != null)
        'autoMarkWatchedThreshold': autoMarkWatchedThreshold,
    };
  }

  PlaybackSettings copyWith({
    bool? autoplay,
    String? defaultQuality,
    double? defaultSpeed,
    MobileControlsPosition? mobileControlsPosition,
    bool? captionsEnabled,
    String? captionsLanguage,
    double? autoMarkWatchedThreshold,
  }) {
    return PlaybackSettings(
      autoplay: autoplay ?? this.autoplay,
      defaultQuality: defaultQuality ?? this.defaultQuality,
      defaultSpeed: defaultSpeed ?? this.defaultSpeed,
      mobileControlsPosition:
          mobileControlsPosition ?? this.mobileControlsPosition,
      captionsEnabled: captionsEnabled ?? this.captionsEnabled,
      captionsLanguage: captionsLanguage ?? this.captionsLanguage,
      autoMarkWatchedThreshold:
          autoMarkWatchedThreshold ?? this.autoMarkWatchedThreshold,
    );
  }
}

/// Note-taking preferences.
class NoteSettings {
  final bool defaultTimestamped;
  final NoteSortOrder? sortOrder;

  const NoteSettings({
    this.defaultTimestamped = true,
    this.sortOrder,
  });

  factory NoteSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const NoteSettings();
    return NoteSettings(
      defaultTimestamped: json['defaultTimestamped'] as bool? ?? true,
      sortOrder: json['sortOrder'] != null
          ? NoteSortOrder.fromJson(json['sortOrder'] as String?)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'defaultTimestamped': defaultTimestamped,
      if (sortOrder != null) 'sortOrder': sortOrder!.toJson(),
    };
  }

  NoteSettings copyWith({
    bool? defaultTimestamped,
    NoteSortOrder? sortOrder,
  }) {
    return NoteSettings(
      defaultTimestamped: defaultTimestamped ?? this.defaultTimestamped,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

/// YouTube channel auto-sync preferences.
class ChannelSyncSettings {
  final bool autoSyncOnVisit;

  /// Sync interval in minutes. 0 means disabled.
  final int? syncIntervalMinutes;

  /// Timestamp (ms since epoch) of last automatic sync.
  final int? lastAutoSyncAt;

  const ChannelSyncSettings({
    this.autoSyncOnVisit = false,
    this.syncIntervalMinutes,
    this.lastAutoSyncAt,
  });

  factory ChannelSyncSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ChannelSyncSettings();
    return ChannelSyncSettings(
      autoSyncOnVisit: json['autoSyncOnVisit'] as bool? ?? false,
      syncIntervalMinutes: json['syncIntervalMinutes'] as int?,
      lastAutoSyncAt: json['lastAutoSyncAt'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'autoSyncOnVisit': autoSyncOnVisit,
      if (syncIntervalMinutes != null)
        'syncIntervalMinutes': syncIntervalMinutes,
      if (lastAutoSyncAt != null) 'lastAutoSyncAt': lastAutoSyncAt,
    };
  }

  ChannelSyncSettings copyWith({
    bool? autoSyncOnVisit,
    int? syncIntervalMinutes,
    int? lastAutoSyncAt,
  }) {
    return ChannelSyncSettings(
      autoSyncOnVisit: autoSyncOnVisit ?? this.autoSyncOnVisit,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      lastAutoSyncAt: lastAutoSyncAt ?? this.lastAutoSyncAt,
    );
  }
}

/// Transcript generation preferences.
class TranscriptSettings {
  final TranscriptProvider? defaultProvider;
  final String? defaultLanguage;
  final bool? autoAttemptYoutubeCaptions;
  final bool? autoAttemptLocalFallback;
  final TranscriptSortBy? sortBy;

  const TranscriptSettings({
    this.defaultProvider,
    this.defaultLanguage,
    this.autoAttemptYoutubeCaptions,
    this.autoAttemptLocalFallback,
    this.sortBy,
  });

  factory TranscriptSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TranscriptSettings();
    return TranscriptSettings(
      defaultProvider: json['defaultProvider'] != null
          ? TranscriptProvider.fromJson(json['defaultProvider'] as String?)
          : null,
      defaultLanguage: json['defaultLanguage'] as String?,
      autoAttemptYoutubeCaptions:
          json['autoAttemptYoutubeCaptions'] as bool?,
      autoAttemptLocalFallback: json['autoAttemptLocalFallback'] as bool?,
      sortBy: json['sortBy'] != null
          ? TranscriptSortBy.fromJson(json['sortBy'] as String?)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (defaultProvider != null)
        'defaultProvider': defaultProvider!.toJson(),
      if (defaultLanguage != null) 'defaultLanguage': defaultLanguage,
      if (autoAttemptYoutubeCaptions != null)
        'autoAttemptYoutubeCaptions': autoAttemptYoutubeCaptions,
      if (autoAttemptLocalFallback != null)
        'autoAttemptLocalFallback': autoAttemptLocalFallback,
      if (sortBy != null) 'sortBy': sortBy!.toJson(),
    };
  }

  TranscriptSettings copyWith({
    TranscriptProvider? defaultProvider,
    String? defaultLanguage,
    bool? autoAttemptYoutubeCaptions,
    bool? autoAttemptLocalFallback,
    TranscriptSortBy? sortBy,
  }) {
    return TranscriptSettings(
      defaultProvider: defaultProvider ?? this.defaultProvider,
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
      autoAttemptYoutubeCaptions:
          autoAttemptYoutubeCaptions ?? this.autoAttemptYoutubeCaptions,
      autoAttemptLocalFallback:
          autoAttemptLocalFallback ?? this.autoAttemptLocalFallback,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

// ---------------------------------------------------------------------------
// Top-level settings model
// ---------------------------------------------------------------------------

/// Complete user settings document.
///
/// Maps to the `settings` table in Convex. All nested objects use sensible
/// defaults so the UI always has a valid settings state even when the
/// backend returns partial data.
class UserSettings {
  /// Convex document ID (`_id`).
  final String id;

  /// Clerk user ID.
  final String userId;

  /// App theme preference.
  final ThemeMode theme;

  /// BCP-47 language code (e.g. "en", "fr").
  final String? language;

  /// Notification preferences.
  final NotificationSettings notifications;

  /// Video playback preferences.
  final PlaybackSettings playback;

  /// Note-taking preferences.
  final NoteSettings notes;

  /// YouTube channel auto-sync preferences.
  final ChannelSyncSettings channelSync;

  /// Transcript generation preferences.
  final TranscriptSettings transcripts;

  /// Last update timestamp (ms since epoch).
  final int? updatedAt;

  const UserSettings({
    required this.id,
    required this.userId,
    this.theme = ThemeMode.system,
    this.language,
    this.notifications = const NotificationSettings(),
    this.playback = const PlaybackSettings(),
    this.notes = const NoteSettings(),
    this.channelSync = const ChannelSyncSettings(),
    this.transcripts = const TranscriptSettings(),
    this.updatedAt,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      id: json['_id'] as String,
      userId: json['userId'] as String,
      theme: ThemeMode.fromJson(json['theme'] as String?),
      language: json['language'] as String?,
      notifications: NotificationSettings.fromJson(
          json['notifications'] as Map<String, dynamic>?),
      playback: PlaybackSettings.fromJson(
          json['playback'] as Map<String, dynamic>?),
      notes:
          NoteSettings.fromJson(json['notes'] as Map<String, dynamic>?),
      channelSync: ChannelSyncSettings.fromJson(
          json['channelSync'] as Map<String, dynamic>?),
      transcripts: TranscriptSettings.fromJson(
          json['transcripts'] as Map<String, dynamic>?),
      updatedAt: json['updatedAt'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'theme': theme.toJson(),
      if (language != null) 'language': language,
      'notifications': notifications.toJson(),
      'playback': playback.toJson(),
      'notes': notes.toJson(),
      'channelSync': channelSync.toJson(),
      'transcripts': transcripts.toJson(),
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  UserSettings copyWith({
    String? id,
    String? userId,
    ThemeMode? theme,
    String? language,
    NotificationSettings? notifications,
    PlaybackSettings? playback,
    NoteSettings? notes,
    ChannelSyncSettings? channelSync,
    TranscriptSettings? transcripts,
    int? updatedAt,
  }) {
    return UserSettings(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      theme: theme ?? this.theme,
      language: language ?? this.language,
      notifications: notifications ?? this.notifications,
      playback: playback ?? this.playback,
      notes: notes ?? this.notes,
      channelSync: channelSync ?? this.channelSync,
      transcripts: transcripts ?? this.transcripts,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSettings &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'UserSettings(id: $id, userId: $userId)';
}
