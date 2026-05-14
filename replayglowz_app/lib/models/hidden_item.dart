/// Type of content that can be hidden by the user.
enum HiddenItemType {
  video,
  playlist;

  static HiddenItemType fromJson(String value) {
    switch (value) {
      case 'video':
        return HiddenItemType.video;
      case 'playlist':
        return HiddenItemType.playlist;
      default:
        throw ArgumentError('Unknown HiddenItemType: $value');
    }
  }

  String toJson() => name;
}

/// Model representing a user-hidden video or playlist.
///
/// Maps to the `hiddenItems` table in Convex. Used to filter out
/// content the user has explicitly dismissed from their feed.
class HiddenItem {
  /// Convex document ID (`_id`).
  final String id;

  /// Type of hidden content.
  final HiddenItemType itemType;

  /// YouTube ID of the hidden item (video ID or playlist ID).
  final String youtubeId;

  /// Timestamp (ms since epoch) when the item was hidden.
  final int hiddenAt;

  const HiddenItem({
    required this.id,
    required this.itemType,
    required this.youtubeId,
    required this.hiddenAt,
  });

  factory HiddenItem.fromJson(Map<String, dynamic> json) {
    return HiddenItem(
      id: json['_id'] as String,
      itemType: HiddenItemType.fromJson(json['itemType'] as String),
      youtubeId: json['youtubeId'] as String,
      hiddenAt: json['hiddenAt'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'itemType': itemType.toJson(),
      'youtubeId': youtubeId,
      'hiddenAt': hiddenAt,
    };
  }

  HiddenItem copyWith({
    String? id,
    HiddenItemType? itemType,
    String? youtubeId,
    int? hiddenAt,
  }) {
    return HiddenItem(
      id: id ?? this.id,
      itemType: itemType ?? this.itemType,
      youtubeId: youtubeId ?? this.youtubeId,
      hiddenAt: hiddenAt ?? this.hiddenAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiddenItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'HiddenItem(id: $id, type: ${itemType.name}, youtubeId: $youtubeId)';
}
