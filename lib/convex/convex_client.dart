import 'dart:async';
import 'dart:convert';

import 'package:convex_flutter/convex_flutter.dart';

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
/// convex.setAuth(() => clerkService.getConvexToken());
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
    await ConvexClient.initialize(
      ConvexConfig(
        deploymentUrl: deploymentUrl,
        clientId: 'tubeflow-flutter-1.0',
        operationTimeout: const Duration(seconds: 30),
      ),
    );
    _instance = ConvexService._(deploymentUrl);
    return _instance!;
  }

  /// Handle returned by [setAuthWithRefresh], disposed on [clearAuth]/[dispose].
  dynamic _authHandle;

  /// Whether the service has been disposed.
  bool _disposed = false;

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  /// Registers a callback that returns a fresh JWT for Convex auth and sets up
  /// automatic token refresh.
  ///
  /// Typically wired to `ClerkService.getConvexToken`.
  Future<void> setAuth(Future<String?> Function() getToken) async {
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
    await ConvexClient.instance.setAuth(token: token);
  }

  /// Clears the current auth state.
  void clearAuth() {
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
    await _waitForConnection();
    final result = await ConvexClient.instance.mutation(
      name: path,
      args: args,
    );
    return _decode<T>(result);
  }

  // ---------------------------------------------------------------------------
  // Action
  // ---------------------------------------------------------------------------

  /// Executes a Convex action and returns the decoded result.
  Future<T> action<T>(String path, Map<String, dynamic> args) async {
    _assertNotDisposed();
    await _waitForConnection();
    final result = await ConvexClient.instance.action(
      name: path,
      args: args,
    );
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
    ConvexClient.instance.dispose();
    _instance = null;
  }

  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError('ConvexService has already been disposed.');
    }
  }

  Future<void> _waitForConnection() async {
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
