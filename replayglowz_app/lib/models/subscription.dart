/// Subscription plan tiers.
enum SubscriptionPlan {
  free,
  pro,
  team;

  static SubscriptionPlan fromJson(String value) {
    switch (value) {
      case 'pro':
        return SubscriptionPlan.pro;
      case 'team':
        return SubscriptionPlan.team;
      case 'free':
      default:
        return SubscriptionPlan.free;
    }
  }

  String toJson() => name;
}

/// Subscription lifecycle status.
enum SubscriptionStatus {
  active,
  canceled,
  pastDue,
  trialing,
  revoked;

  static SubscriptionStatus fromJson(String value) {
    switch (value) {
      case 'active':
        return SubscriptionStatus.active;
      case 'canceled':
        return SubscriptionStatus.canceled;
      case 'past_due':
        return SubscriptionStatus.pastDue;
      case 'trialing':
        return SubscriptionStatus.trialing;
      case 'revoked':
        return SubscriptionStatus.revoked;
      default:
        return SubscriptionStatus.active;
    }
  }

  String toJson() {
    switch (this) {
      case SubscriptionStatus.active:
        return 'active';
      case SubscriptionStatus.canceled:
        return 'canceled';
      case SubscriptionStatus.pastDue:
        return 'past_due';
      case SubscriptionStatus.trialing:
        return 'trialing';
      case SubscriptionStatus.revoked:
        return 'revoked';
    }
  }
}

/// Feature limits and capabilities for a subscription tier.
class SubscriptionFeatures {
  /// Maximum number of videos the user can save.
  final int maxVideos;

  /// Maximum notes allowed per video.
  final int maxNotesPerVideo;

  /// Maximum number of playlists the user can create.
  final int maxPlaylists;

  /// Whether AI-powered summaries are available.
  final bool aiSummaries;

  /// Whether note export functionality is available.
  final bool exportNotes;

  const SubscriptionFeatures({
    this.maxVideos = 50,
    this.maxNotesPerVideo = 10,
    this.maxPlaylists = 5,
    this.aiSummaries = false,
    this.exportNotes = false,
  });

  /// Default feature set for the free plan.
  static const free = SubscriptionFeatures();

  /// Feature set for the pro plan.
  static const pro = SubscriptionFeatures(
    maxVideos: -1, // unlimited
    maxNotesPerVideo: -1,
    maxPlaylists: -1,
    aiSummaries: true,
    exportNotes: true,
  );

  /// Feature set for the team plan.
  static const team = SubscriptionFeatures(
    maxVideos: -1,
    maxNotesPerVideo: -1,
    maxPlaylists: -1,
    aiSummaries: true,
    exportNotes: true,
  );

  /// Returns the feature set for the given [plan].
  static SubscriptionFeatures forPlan(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return free;
      case SubscriptionPlan.pro:
        return pro;
      case SubscriptionPlan.team:
        return team;
    }
  }

  /// Whether the given limit is unlimited (-1).
  static bool isUnlimited(int limit) => limit < 0;

  factory SubscriptionFeatures.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SubscriptionFeatures();
    return SubscriptionFeatures(
      maxVideos: json['maxVideos'] as int? ?? 50,
      maxNotesPerVideo: json['maxNotesPerVideo'] as int? ?? 10,
      maxPlaylists: json['maxPlaylists'] as int? ?? 5,
      aiSummaries: json['aiSummaries'] as bool? ?? false,
      exportNotes: json['exportNotes'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maxVideos': maxVideos,
      'maxNotesPerVideo': maxNotesPerVideo,
      'maxPlaylists': maxPlaylists,
      'aiSummaries': aiSummaries,
      'exportNotes': exportNotes,
    };
  }
}

/// User subscription state, including plan, billing status, and feature access.
///
/// Maps to the `subscriptions` table in Convex.
class UserSubscription {
  /// Convex document ID (`_id`).
  final String id;

  /// Auth provider user ID.
  final String userId;

  /// Current subscription plan tier.
  final SubscriptionPlan plan;

  /// Billing lifecycle status.
  final SubscriptionStatus status;

  /// Feature limits derived from the plan.
  final SubscriptionFeatures features;

  /// Whether the subscription will cancel at the end of the current period.
  final bool cancelAtPeriodEnd;

  /// Start of the current billing period (ms since epoch).
  final int? currentPeriodStart;

  /// End of the current billing period (ms since epoch).
  final int? currentPeriodEnd;

  /// Creation timestamp (ms since epoch).
  final int createdAt;

  /// Last update timestamp (ms since epoch).
  final int updatedAt;

  const UserSubscription({
    required this.id,
    required this.userId,
    required this.plan,
    required this.status,
    required this.features,
    this.cancelAtPeriodEnd = false,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Whether the subscription grants full access (active or trialing).
  bool get isActive =>
      status == SubscriptionStatus.active ||
      status == SubscriptionStatus.trialing;

  /// Whether the subscription is on a paid plan (pro or team).
  bool get isPaid => plan != SubscriptionPlan.free;

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    final plan = SubscriptionPlan.fromJson(json['plan'] as String);
    return UserSubscription(
      id: json['_id'] as String,
      userId: json['userId'] as String,
      plan: plan,
      status: SubscriptionStatus.fromJson(json['status'] as String),
      features: json['features'] != null
          ? SubscriptionFeatures.fromJson(
              json['features'] as Map<String, dynamic>,
            )
          : SubscriptionFeatures.forPlan(plan),
      cancelAtPeriodEnd: json['cancelAtPeriodEnd'] as bool? ?? false,
      currentPeriodStart: json['currentPeriodStart'] as int?,
      currentPeriodEnd: json['currentPeriodEnd'] as int?,
      createdAt: json['createdAt'] as int,
      updatedAt: json['updatedAt'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'plan': plan.toJson(),
      'status': status.toJson(),
      'features': features.toJson(),
      'cancelAtPeriodEnd': cancelAtPeriodEnd,
      if (currentPeriodStart != null) 'currentPeriodStart': currentPeriodStart,
      if (currentPeriodEnd != null) 'currentPeriodEnd': currentPeriodEnd,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  UserSubscription copyWith({
    String? id,
    String? userId,
    SubscriptionPlan? plan,
    SubscriptionStatus? status,
    SubscriptionFeatures? features,
    bool? cancelAtPeriodEnd,
    int? currentPeriodStart,
    int? currentPeriodEnd,
    int? createdAt,
    int? updatedAt,
  }) {
    return UserSubscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      plan: plan ?? this.plan,
      status: status ?? this.status,
      features: features ?? this.features,
      cancelAtPeriodEnd: cancelAtPeriodEnd ?? this.cancelAtPeriodEnd,
      currentPeriodStart: currentPeriodStart ?? this.currentPeriodStart,
      currentPeriodEnd: currentPeriodEnd ?? this.currentPeriodEnd,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSubscription &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'UserSubscription(id: $id, plan: ${plan.name}, status: ${status.name})';
}
