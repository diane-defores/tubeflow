// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:io';

import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/src/utils/clerk_file_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kClerkPersistPrefix = 'clerk_sdk:';

/// Web-safe persistor backed by SharedPreferences (localStorage on web).
///
/// This avoids `path_provider` + file system usage which breaks on Flutter web.
class ClerkWebPersistor implements clerk.Persistor {
  SharedPreferences? _prefs;

  @override
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  void terminate() {
    _prefs = null;
  }

  String _key(String key) => '$_kClerkPersistPrefix$key';

  @override
  Future<T?> read<T>(String key) async {
    final prefs = _prefs;
    if (prefs == null) return null;

    final raw = prefs.getString(_key(key));
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw);
      return decoded as T?;
    } catch (_) {
      // Backwards/invalid value in storage.
      return null;
    }
  }

  @override
  Future<void> write<T>(String key, T value) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(_key(key), jsonEncode(value));
  }

  @override
  Future<void> delete(String key) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.remove(_key(key));
  }
}

/// No-op file cache for Flutter web.
///
/// clerk_flutter's default caching uses the file system via `path_provider`.
/// On web we don't need (and can't use) a `dart:io` file cache, so we replace
/// it with a stub that simply yields nothing.
class NoopClerkFileCache implements ClerkFileCache {
  @override
  Future<void> initialize() async {}

  @override
  void terminate() {}

  @override
  Stream<File> stream(
    Uri uri, {
    Duration ttl = ClerkFileCache.defaultTTL,
    Map<String, String>? headers,
  }) {
    return const Stream.empty();
  }
}

