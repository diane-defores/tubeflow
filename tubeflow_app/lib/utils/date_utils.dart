import 'package:intl/intl.dart';

/// Format a timestamp as a relative time string ("2h ago", "3 days ago", etc.)
String formatTimeAgo(String? dateString, {String locale = 'en'}) {
  if (dateString == null || dateString.isEmpty) return '';

  final date = DateTime.tryParse(dateString);
  if (date == null) return '';

  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inSeconds < 60) return locale == 'fr' ? "à l'instant" : 'just now';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return locale == 'fr' ? 'il y a ${m}min' : '${m}m ago';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return locale == 'fr' ? 'il y a ${h}h' : '${h}h ago';
  }
  if (diff.inDays < 7) {
    final d = diff.inDays;
    return locale == 'fr' ? 'il y a ${d}j' : '${d}d ago';
  }
  if (diff.inDays < 30) {
    final w = diff.inDays ~/ 7;
    return locale == 'fr' ? 'il y a ${w}sem' : '${w}w ago';
  }
  if (diff.inDays < 365) {
    final m = diff.inDays ~/ 30;
    return locale == 'fr' ? 'il y a ${m}mois' : '${m}mo ago';
  }

  final y = diff.inDays ~/ 365;
  return locale == 'fr' ? 'il y a ${y}an${y > 1 ? 's' : ''}' : '${y}y ago';
}

/// Format a timestamp (milliseconds since epoch) as a date string.
String formatDate(int? timestampMs, {String locale = 'en'}) {
  if (timestampMs == null) return '';
  final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  final fmt = locale == 'fr' ? DateFormat('d MMM yyyy', 'fr') : DateFormat('MMM d, yyyy');
  return fmt.format(date);
}

/// Format a timestamp (milliseconds since epoch) as a date + time string.
String formatDateTime(int? timestampMs, {String locale = 'en'}) {
  if (timestampMs == null) return '';
  final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  final fmt = locale == 'fr'
      ? DateFormat('d MMM yyyy HH:mm', 'fr')
      : DateFormat('MMM d, yyyy HH:mm');
  return fmt.format(date);
}
