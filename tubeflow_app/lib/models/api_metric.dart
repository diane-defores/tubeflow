/// Model representing a YouTube API usage metric entry.
///
/// Maps to the `apiMetrics` table in Convex. Used for tracking API
/// quota consumption and monitoring error rates.
class ApiMetric {
  /// Convex document ID (`_id`).
  final String id;

  /// API endpoint called (e.g. "playlists.list", "search.list").
  final String endpoint;

  /// Cost of this call in YouTube API quota units.
  final int quotaUnits;

  /// Whether the API call succeeded.
  final bool success;

  /// Error message if the call failed.
  final String? errorMessage;

  /// Response time in milliseconds.
  final int? responseTimeMs;

  /// Timestamp (ms since epoch) when the call was made.
  final int timestamp;

  const ApiMetric({
    required this.id,
    required this.endpoint,
    required this.quotaUnits,
    required this.success,
    this.errorMessage,
    this.responseTimeMs,
    required this.timestamp,
  });

  /// Whether this metric represents a failed API call.
  bool get isError => !success;

  factory ApiMetric.fromJson(Map<String, dynamic> json) {
    return ApiMetric(
      id: json['_id'] as String,
      endpoint: json['endpoint'] as String,
      quotaUnits: json['quotaUnits'] as int,
      success: json['success'] as bool,
      errorMessage: json['errorMessage'] as String?,
      responseTimeMs: json['responseTimeMs'] as int?,
      timestamp: json['timestamp'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'endpoint': endpoint,
      'quotaUnits': quotaUnits,
      'success': success,
      if (errorMessage != null) 'errorMessage': errorMessage,
      if (responseTimeMs != null) 'responseTimeMs': responseTimeMs,
      'timestamp': timestamp,
    };
  }

  ApiMetric copyWith({
    String? id,
    String? endpoint,
    int? quotaUnits,
    bool? success,
    String? errorMessage,
    int? responseTimeMs,
    int? timestamp,
  }) {
    return ApiMetric(
      id: id ?? this.id,
      endpoint: endpoint ?? this.endpoint,
      quotaUnits: quotaUnits ?? this.quotaUnits,
      success: success ?? this.success,
      errorMessage: errorMessage ?? this.errorMessage,
      responseTimeMs: responseTimeMs ?? this.responseTimeMs,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApiMetric && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ApiMetric(id: $id, endpoint: $endpoint, success: $success)';
}
