import 'dart:collection';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Severity of a log entry.
enum LogLevel { info, warning, error }

class LogEntry {
  LogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
    this.error,
    this.stackTrace,
  });

  final DateTime timestamp;
  final LogLevel level;
  final String source;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  String format() {
    final ts = timestamp.toIso8601String();
    final lvl = level.name.toUpperCase();
    final head = '[$ts] $lvl $source: $message';
    final errStr = error != null ? '\n  error: $error' : '';
    final stStr = stackTrace != null ? '\n  stack: $stackTrace' : '';
    return '$head$errStr$stStr';
  }
}

/// In-memory ring buffer of recent log entries.
///
/// Lets the Preferences screen display what happened during startup (Clerk
/// init, Convex connection, uncaught errors) on devices without DevTools.
class AppLogger extends ChangeNotifier {
  AppLogger._();

  static final AppLogger instance = AppLogger._();

  static const int _maxEntries = 200;

  final Queue<LogEntry> _entries = Queue<LogEntry>();

  List<LogEntry> get entries => List.unmodifiable(_entries);

  void log(
    String message, {
    String source = 'app',
    LogLevel level = LogLevel.info,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      source: source,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
    _entries.addLast(entry);
    while (_entries.length > _maxEntries) {
      _entries.removeFirst();
    }
    developer.log(
      message,
      name: source,
      error: error,
      stackTrace: stackTrace,
      level: level == LogLevel.error ? 1000 : (level == LogLevel.warning ? 900 : 800),
    );
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  String formatAll() {
    if (_entries.isEmpty) return '(no logs)';
    return _entries.map((e) => e.format()).join('\n');
  }
}
