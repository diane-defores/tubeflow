/// Format seconds into "m:ss" or "h:mm:ss" string.
String formatDuration(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Format a timestamp (seconds) for display in notes: "[3:45]"
String formatTimestamp(double seconds) {
  final total = seconds.floor();
  final mins = total ~/ 60;
  final secs = total % 60;
  return '$mins:${secs.toString().padLeft(2, '0')}';
}

/// Parse a duration string like "PT3M45S" or "3:45" to seconds.
int? parseDuration(String? duration) {
  if (duration == null || duration.isEmpty) return null;

  // ISO 8601 format: PT3M45S
  final iso = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
  final isoMatch = iso.firstMatch(duration);
  if (isoMatch != null) {
    final hours = int.tryParse(isoMatch.group(1) ?? '0') ?? 0;
    final minutes = int.tryParse(isoMatch.group(2) ?? '0') ?? 0;
    final seconds = int.tryParse(isoMatch.group(3) ?? '0') ?? 0;
    return hours * 3600 + minutes * 60 + seconds;
  }

  // Simple format: "3:45" or "1:03:45"
  final parts = duration.split(':').map((p) => int.tryParse(p) ?? 0).toList();
  if (parts.length == 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
  if (parts.length == 2) return parts[0] * 60 + parts[1];

  return null;
}
