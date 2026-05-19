import 'dart:async';
import 'dart:convert';

import 'package:convex_flutter/convex_flutter.dart';
import 'package:flutter/foundation.dart';

import 'package:replayglowz_app/convex/convex_errors.dart';
import 'package:replayglowz_app/convex/convex_web_bridge.dart';
import 'package:replayglowz_app/utils/app_logger.dart';

/// A singleton service that wraps the Convex Flutter client.
///
/// Provides query, mutation, action, subscription, and auth-token injection on
/// top of the `convex_flutter` package. Initialise once at app startup via
/// [initialize] and then access the shared instance through Riverpod (see
/// [convex_provider.dart]).
///
/// Usage:
/// ```dart
/// await ConvexService.initialize('https://your-deployment.convex.cloud');
/// final convex = ConvexService.instance;
/// convex.setAuth(() => authService.getConvexToken());
/// final videos = await convex.query<List>('youtube:getAllVideos', {});
/// ```
class ConvexService {
  ConvexService._(this.url);

  /// The Convex deployment URL (e.g. `https://xyz.convex.cloud`).
  final String url;

  /// Singleton instance, available after [initialize].
  static ConvexService? _instance;

  /// Returns the shared [ConvexService] instance.
  ///
  /// Throws [StateError] if [initialize] has not been called.
  static ConvexService get instance {
    if (_instance == null) {
      throw StateError(
        'ConvexService has not been initialised. '
        'Call ConvexService.initialize() first.',
      );
    }
    return _instance!;
  }

  /// Initialises the underlying [ConvexClient] singleton and creates the
  /// [ConvexService] wrapper.
  ///
  /// Must be called once before any queries, mutations or subscriptions.
  /// Typically called in `main()` before `runApp()`.
  static Future<ConvexService> initialize(String deploymentUrl) async {
    if (!kIsWeb) {
      await ConvexClient.initialize(
        ConvexConfig(
          deploymentUrl: deploymentUrl,
          clientId: 'replayglowz-flutter-1.0',
          operationTimeout: const Duration(seconds: 30),
        ),
      );
    }
    _instance = ConvexService._(deploymentUrl);
    return _instance!;
  }

  /// Handle returned by [setAuthWithRefresh], disposed on [clearAuth]/[dispose].
  dynamic _authHandle;

  /// Token provider wired from Firebase Auth during bootstrap.
  Future<String?> Function()? _tokenProvider;

  /// Whether the service has been disposed.
  bool _disposed = false;

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  /// Registers a callback that returns a fresh JWT for Convex auth and sets up
  /// automatic token refresh.
  ///
  /// Typically wired to the Firebase-backed auth service.
  Future<void> setAuth(Future<String?> Function() getToken) async {
    _tokenProvider = getToken;
    if (kIsWeb) {
      return;
    }

    _authHandle = await ConvexClient.instance.setAuthWithRefresh(
      fetchToken: () async {
        final token = await getToken();
        return token;
      },
      onAuthChange: (isAuthenticated) {
        // Auth state tracked by ConvexClient internally.
      },
    );
  }

  /// Sets a one-shot auth token (useful for testing or manual token management).
  Future<void> setAuthToken(String token) async {
    if (kIsWeb) {
      _tokenProvider = () async => token;
      return;
    }

    await ConvexClient.instance.setAuth(token: token);
  }

  /// Clears the current auth state.
  void clearAuth() {
    _tokenProvider = null;
    if (_authHandle != null) {
      try {
        _authHandle.dispose();
      } catch (_) {
        // Handle may already be disposed.
      }
      _authHandle = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Query
  // ---------------------------------------------------------------------------

  /// Executes a Convex query function and returns the decoded result.
  ///
  /// [path] is the Convex function path (e.g. `'youtube:getAllVideos'`).
  /// [args] are the function arguments as a JSON-serialisable map.
  ///
  /// The raw JSON string from the Convex client is decoded into the requested
  /// Dart type [T]. For lists, use `query<List>(...)`; for maps, use
  /// `query<Map<String, dynamic>>(...)`.
  Future<T> query<T>(String path, Map<String, dynamic> args) async {
    _assertNotDisposed();
    if (kIsWeb) {
      try {
        return await _queryViaHttpBridge<T>(path, args);
      } catch (e, st) {
        AppLogger.instance.log(
          '[http_bridge_failed] Convex HTTP query bridge failed for $path',
          source: 'ConvexService',
          level: LogLevel.warning,
          error: e,
          stackTrace: st,
        );
        rethrow;
      }
    }
    await _waitForConnection();
    final result = await ConvexClient.instance.query(path, args);
    return _decode<T>(result);
  }

  // ---------------------------------------------------------------------------
  // Mutation
  // ---------------------------------------------------------------------------

  /// Executes a Convex mutation and returns the decoded result.
  Future<T> mutate<T>(String path, Map<String, dynamic> args) async {
    _assertNotDisposed();
    if (kIsWeb) {
      try {
        return await _mutationViaHttpBridge<T>(path, args);
      } catch (e, st) {
        AppLogger.instance.log(
          '[http_bridge_failed] Convex HTTP mutation bridge failed for $path',
          source: 'ConvexService',
          level: LogLevel.warning,
          error: e,
          stackTrace: st,
        );
        rethrow;
      }
    }
    await _waitForConnection();
    final result = await ConvexClient.instance.mutation(name: path, args: args);
    return _decode<T>(result);
  }

  // ---------------------------------------------------------------------------
  // Action
  // ---------------------------------------------------------------------------

  /// Executes a Convex action and returns the decoded result.
  Future<T> action<T>(String path, Map<String, dynamic> args) async {
    _assertNotDisposed();
    if (kIsWeb) {
      try {
        return await _actionViaHttpBridge<T>(path, args);
      } catch (e, st) {
        AppLogger.instance.log(
          '[http_bridge_failed] Convex HTTP action bridge failed for $path',
          source: 'ConvexService',
          level: LogLevel.warning,
          error: e,
          stackTrace: st,
        );
        rethrow;
      }
    }
    await _waitForConnection();
    final result = await ConvexClient.instance.action(name: path, args: args);
    return _decode<T>(result);
  }

  // ---------------------------------------------------------------------------
  // Subscription
  // ---------------------------------------------------------------------------

  /// Subscribes to a Convex query and returns a broadcast [Stream] that emits
  /// each time the server-side data changes.
  ///
  /// The stream stays open until the listener cancels or [dispose] is called.
  /// Each emission is the fully decoded JSON payload from the server.
  Stream<T> subscribe<T>(String path, Map<String, dynamic> args) {
    _assertNotDisposed();

    if (kIsWeb) {
      return _subscribeViaHttpPolling<T>(path, args);
    }

    final controller = StreamController<T>.broadcast();
    SubscriptionHandle? handle;

    // Track whether we have set up the subscription yet.
    bool subscribed = false;

    void startSubscription() async {
      if (subscribed) return;
      subscribed = true;

      try {
        await _waitForConnection();
        handle = await ConvexClient.instance.subscribe(
          name: path,
          args: args,
          onUpdate: (value) {
            if (!controller.isClosed) {
              try {
                final decoded = _decode<T>(value);
                controller.add(decoded);
              } catch (e, st) {
                controller.addError(e, st);
              }
            }
          },
          onError: (message, value) {
            if (!controller.isClosed) {
              controller.addError(
                Exception('Convex subscription error: $message'),
              );
            }
          },
        );
      } catch (e, st) {
        if (!controller.isClosed) {
          controller.addError(e, st);
        }
      }
    }

    controller.onListen = () {
      startSubscription();
    };

    controller.onCancel = () {
      handle?.cancel();
      handle = null;
      controller.close();
    };

    // Start immediately so the first listener gets data without delay.
    startSubscription();

    return controller.stream;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Tears down the underlying client and releases resources.
  ///
  /// After calling this, any further calls to [query], [mutate], or
  /// [subscribe] will throw.
  void dispose() {
    _disposed = true;
    clearAuth();
    if (!kIsWeb) {
      ConvexClient.instance.dispose();
    }
    _instance = null;
  }

  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError('ConvexService has already been disposed.');
    }
  }

  Future<void> _waitForConnection() async {
    if (kIsWeb) return;

    if (ConvexClient.instance.isConnected) return;

    await ConvexClient.instance.connectionState
        .firstWhere((state) => state == WebSocketConnectionState.connected)
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw TimeoutException(
            'Timed out while waiting for the Convex WebSocket connection.',
          ),
        );
  }

  Future<T> _queryViaHttpBridge<T>(
    String path,
    Map<String, dynamic> args,
  ) async {
    final token = await _getFreshAuthToken();
    if (token == null || token.isEmpty) {
      throw StateError(
        'Missing Convex auth token for HTTP query bridge ($path).',
      );
    }
    final result = await convexWebQuery(
      convexUrl: url,
      authToken: token,
      path: path,
      args: args,
    );
    return _decode<T>(result);
  }

  Future<T> _mutationViaHttpBridge<T>(
    String path,
    Map<String, dynamic> args,
  ) async {
    final token = await _getFreshAuthToken();
    if (token == null || token.isEmpty) {
      throw StateError(
        'Missing Convex auth token for HTTP mutation bridge ($path).',
      );
    }
    final result = await convexWebMutation(
      convexUrl: url,
      authToken: token,
      path: path,
      args: args,
    );
    return _decode<T>(result);
  }

  Future<T> _actionViaHttpBridge<T>(
    String path,
    Map<String, dynamic> args,
  ) async {
    final token = await _getFreshAuthToken();
    if (token == null || token.isEmpty) {
      throw StateError(
        'Missing Convex auth token for HTTP action bridge ($path).',
      );
    }
    final result = await convexWebAction(
      convexUrl: url,
      authToken: token,
      path: path,
      args: args,
    );
    return _decode<T>(result);
  }

  Future<String?> _getFreshAuthToken() async {
    final getToken = _tokenProvider;
    if (getToken == null) {
      return null;
    }
    try {
      return await getToken();
    } catch (e, st) {
      if (!isConvexUnauthorizedError(e)) {
        AppLogger.instance.log(
          '[convex_auth_not_ready] Failed to refresh Convex auth token',
          source: 'ConvexService',
          level: LogLevel.warning,
          error: e,
          stackTrace: st,
        );
      }
      return null;
    }
  }

  Stream<T> _subscribeViaHttpPolling<T>(
    String path,
    Map<String, dynamic> args,
  ) {
    late StreamController<T> controller;
    Timer? timer;
    var running = false;
    String? lastEncoded;
    var pollInterval = const Duration(seconds: 10);
    const minPollInterval = Duration(seconds: 3);
    const maxPollInterval = Duration(seconds: 30);

    Duration nextPollInterval(Duration current) {
      if (current >= maxPollInterval) {
        return maxPollInterval;
      }
      final next = Duration(seconds: current.inSeconds * 2);
      return next > maxPollInterval ? maxPollInterval : next;
    }

    Future<void> tick() async {
      if (running || controller.isClosed) {
        return;
      }
      running = true;
      try {
        final value = await _queryViaHttpBridge<T>(path, args);
        final encoded = jsonEncode(value);
        if (encoded != lastEncoded && !controller.isClosed) {
          lastEncoded = encoded;
          controller.add(value);
          pollInterval = minPollInterval;
        } else {
          pollInterval = nextPollInterval(pollInterval);
        }
      } catch (e, st) {
        if (!controller.isClosed) {
          controller.addError(e, st);
        }
        pollInterval = nextPollInterval(pollInterval);
      } finally {
        running = false;
        if (!controller.isClosed) {
          timer?.cancel();
          timer = Timer(pollInterval, tick);
        }
      }
    }

    controller = StreamController<T>.broadcast(
      onListen: () {
        pollInterval = const Duration(seconds: 10);
        timer?.cancel();
        timer = Timer(const Duration(milliseconds: 1), tick);
      },
      onCancel: () {
        timer?.cancel();
        timer = null;
      },
    );

    return controller.stream;
  }

  // ---------------------------------------------------------------------------
  // JSON decoding helper
  // ---------------------------------------------------------------------------

  /// Decodes a raw JSON string from the Convex client into the target type [T].
  ///
  /// If the raw value is already the expected type (e.g. when the client
  /// returns a pre-decoded object), it is returned directly.
  static T _decode<T>(dynamic raw) {
    if (raw is T) return raw;
    if (raw is String) {
      final decoded = jsonDecode(raw);
      if (decoded is T) return decoded;
      // For nullable types or `dynamic`, just return whatever we got.
      return decoded as T;
    }
    return raw as T;
  }
}
