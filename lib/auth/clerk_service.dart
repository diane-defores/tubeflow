import 'dart:developer' as developer;

import 'package:clerk_flutter/clerk_flutter.dart' as clerk;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tubeflow_app/auth/auth_state.dart';

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

/// Clerk publishable key injected at build time via `--dart-define`.
const _publishableKey = String.fromEnvironment(
  'CLERK_PUBLISHABLE_KEY',
  defaultValue: '',
);

// ---------------------------------------------------------------------------
// ClerkService
// ---------------------------------------------------------------------------

/// Provides Clerk authentication for TubeFlow.
///
/// Wraps the `clerk_flutter` SDK and drives the [AuthNotifier] so the rest of
/// the app can react to auth state changes through Riverpod.
///
/// Because `clerk_flutter` is still in beta, every SDK call is wrapped in a
/// try/catch so the app degrades gracefully instead of crashing.
class ClerkService {
  ClerkService({required this.authNotifier}) {
    _init();
  }

  /// The notifier that reflects auth state across the app.
  final AuthNotifier authNotifier;

  /// The underlying Clerk SDK auth object.
  ///
  /// Initialised lazily in [_init]. Null if the publishable key is missing
  /// or the SDK failed to initialise.
  clerk.ClerkAuth? _auth;

  /// Whether the Clerk SDK initialised successfully.
  bool get isInitialised => _auth != null;

  /// The Clerk publishable key used for this instance.
  String get publishableKey => _publishableKey;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  void _init() {
    if (_publishableKey.isEmpty) {
      developer.log(
        'CLERK_PUBLISHABLE_KEY is empty — auth will not work. '
        'Pass --dart-define=CLERK_PUBLISHABLE_KEY=pk_... at build time.',
        name: 'ClerkService',
      );
      return;
    }

    try {
      _auth = clerk.ClerkAuth(publishableKey: _publishableKey);
      _listenToSessionChanges();
    } catch (e, st) {
      developer.log(
        'Failed to initialise clerk_flutter: $e',
        name: 'ClerkService',
        error: e,
        stackTrace: st,
      );
      // Leave _auth null — all methods will fall back gracefully.
    }
  }

  /// Listens to Clerk session stream and pushes state to [authNotifier].
  void _listenToSessionChanges() {
    final auth = _auth;
    if (auth == null) return;

    try {
      auth.addListener(_onAuthChanged);
      // Check if there is already an active session from a persisted login.
      _syncCurrentSession();
    } catch (e) {
      developer.log(
        'Could not listen to Clerk session changes: $e',
        name: 'ClerkService',
      );
    }
  }

  void _onAuthChanged() {
    _syncCurrentSession();
  }

  /// Reads the current Clerk session and updates [authNotifier].
  void _syncCurrentSession() {
    try {
      final auth = _auth;
      if (auth == null) return;

      final user = auth.user;
      if (user != null) {
        authNotifier.setAuthenticated(
          AuthUser(
            id: user.id,
            email: user.primaryEmailAddress?.emailAddress ?? '',
            displayName: _buildDisplayName(user),
            imageUrl: user.imageUrl,
          ),
        );
      } else {
        // Only go to unauthenticated if we are not already loading.
        if (authNotifier.state is! AuthLoading) {
          authNotifier.setUnauthenticated();
        }
      }
    } catch (e) {
      developer.log(
        'Error syncing Clerk session: $e',
        name: 'ClerkService',
      );
    }
  }

  static String? _buildDisplayName(clerk.User user) {
    final first = user.firstName ?? '';
    final last = user.lastName ?? '';
    final full = '$first $last'.trim();
    return full.isEmpty ? null : full;
  }

  // ---------------------------------------------------------------------------
  // Sign-in methods
  // ---------------------------------------------------------------------------

  /// Starts the Google OAuth sign-in flow.
  ///
  /// Updates [authNotifier] to [AuthLoading] while in progress and to
  /// [AuthAuthenticated] or [AuthUnauthenticated] on completion.
  Future<void> signInWithGoogle() async {
    await _oauthSignIn(clerk.OAuthProvider.google);
  }

  /// Starts the Apple OAuth sign-in flow.
  Future<void> signInWithApple() async {
    await _oauthSignIn(clerk.OAuthProvider.apple);
  }

  /// Generic OAuth sign-in through the Clerk SDK.
  Future<void> _oauthSignIn(clerk.OAuthProvider provider) async {
    final auth = _auth;
    if (auth == null) {
      authNotifier.setUnauthenticated(
        error: 'Clerk is not initialised. Check your publishable key.',
      );
      return;
    }

    authNotifier.setLoading();

    try {
      // clerk_flutter provides a method to start an OAuth flow.
      // The exact API depends on the beta version; wrap to handle changes.
      await auth.signInWithOAuth(provider);

      // After the OAuth redirect completes the SDK updates its internal
      // session state, which triggers _onAuthChanged -> _syncCurrentSession.
      // If the listener did not fire synchronously, do a manual sync.
      _syncCurrentSession();
    } catch (e, st) {
      developer.log(
        'OAuth sign-in failed ($provider): $e',
        name: 'ClerkService',
        error: e,
        stackTrace: st,
      );
      authNotifier.setUnauthenticated(error: 'Sign-in failed. Please retry.');
    }
  }

  // ---------------------------------------------------------------------------
  // Sign-out
  // ---------------------------------------------------------------------------

  /// Signs the current user out and clears the session.
  Future<void> signOut() async {
    final auth = _auth;
    if (auth == null) {
      authNotifier.setUnauthenticated();
      return;
    }

    try {
      await auth.signOut();
    } catch (e) {
      developer.log(
        'Sign-out error: $e',
        name: 'ClerkService',
      );
    } finally {
      authNotifier.setUnauthenticated();
    }
  }

  // ---------------------------------------------------------------------------
  // Convex token
  // ---------------------------------------------------------------------------

  /// Returns a JWT suitable for authenticating with the Convex backend.
  ///
  /// Uses the Clerk JWT template named `'convex'`. Returns `null` if the user
  /// is not authenticated or token retrieval fails.
  Future<String?> getConvexToken() async {
    final auth = _auth;
    if (auth == null) return null;

    try {
      final session = auth.session;
      if (session == null) return null;

      // Request a token using the 'convex' JWT template configured in Clerk.
      final token = await session.getToken(template: 'convex');
      return token;
    } catch (e) {
      developer.log(
        'Failed to get Convex token: $e',
        name: 'ClerkService',
      );
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Convenience getters
  // ---------------------------------------------------------------------------

  /// Whether the user currently has an active session.
  bool get isAuthenticated => authNotifier.isAuthenticated;

  /// The current [AuthUser], or `null`.
  AuthUser? get currentUser => authNotifier.currentUser;

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  /// Disposes SDK resources. Call when the app is shutting down.
  void dispose() {
    try {
      _auth?.removeListener(_onAuthChanged);
      _auth?.dispose();
    } catch (_) {
      // Best-effort cleanup.
    }
    _auth = null;
  }
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

/// Provides the singleton [ClerkService] wired to the global [AuthNotifier].
///
/// The service is created once and disposed when the provider scope is
/// destroyed (i.e. when the app shuts down).
final clerkServiceProvider = Provider<ClerkService>((ref) {
  final authNotifier = ref.watch(authStateProvider.notifier);
  final service = ClerkService(authNotifier: authNotifier);

  ref.onDispose(() => service.dispose());

  return service;
});
