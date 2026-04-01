/// Model representing an authenticated TubeFlow user.
///
/// Maps to the `users` table in Convex. Sensitive fields (OAuth tokens)
/// are intentionally excluded from the client model.
class TubeFlowUser {
  /// Convex document ID (`_id`).
  final String id;

  /// Clerk authentication user ID.
  final String clerkId;

  /// User's email address.
  final String email;

  /// Display name.
  final String? name;

  /// URL of the user's avatar image.
  final String? avatarUrl;

  /// Whether the user has connected their YouTube account via OAuth.
  final bool? youtubeConnected;

  /// Account creation timestamp (ms since epoch).
  final int? createdAt;

  /// Last update timestamp (ms since epoch).
  final int? updatedAt;

  const TubeFlowUser({
    required this.id,
    required this.clerkId,
    required this.email,
    this.name,
    this.avatarUrl,
    this.youtubeConnected,
    this.createdAt,
    this.updatedAt,
  });

  /// User's display name, falling back to email if no name is set.
  String get displayName => name ?? email;

  /// Whether YouTube features are available for this user.
  bool get hasYouTubeAccess => youtubeConnected == true;

  factory TubeFlowUser.fromJson(Map<String, dynamic> json) {
    return TubeFlowUser(
      id: json['_id'] as String,
      clerkId: json['clerkId'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      youtubeConnected: json['youtubeConnected'] as bool?,
      createdAt: json['createdAt'] as int?,
      updatedAt: json['updatedAt'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'clerkId': clerkId,
      'email': email,
      if (name != null) 'name': name,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (youtubeConnected != null) 'youtubeConnected': youtubeConnected,
      if (createdAt != null) 'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  TubeFlowUser copyWith({
    String? id,
    String? clerkId,
    String? email,
    String? name,
    String? avatarUrl,
    bool? youtubeConnected,
    int? createdAt,
    int? updatedAt,
  }) {
    return TubeFlowUser(
      id: id ?? this.id,
      clerkId: clerkId ?? this.clerkId,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      youtubeConnected: youtubeConnected ?? this.youtubeConnected,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TubeFlowUser &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'TubeFlowUser(id: $id, email: $email)';
}
