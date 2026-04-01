import 'dart:developer' as developer;

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
/// This is a lightweight service that manages auth state through [AuthNotifier].
/// The actual Clerk SDK integration happens via the `ClerkAuth` widget in the
/// widget tree (see `clerk_flutter`). This service provides imperative methods
/// for sign-in / sign-out that the UI can call.
///
/// Because `clerk_flutter 0.0.14-beta` exposes `ClerkAuth` as an
/// InheritedWidget (not a directly instantiable service), this class does NOT
/// hold a reference to `ClerkAuth`. Instead it acts as a stub that drives
/// [AuthNotifier] state while the real Clerk widget-tree integration is wired
/// up separately.
class ClerkService {
  ClerkService({required this.authNotifier}) {
    _init();
  }

  /// The notifier that reflects auth state across the app.
  final AuthNotifier authNotifier;

  /// Whether the service considers itself ready.
  bool _initialised = false;

  /// Whether the service initialised successfully.
  bool get isInitialised => _initialised;

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

    _initialised = true;
  }

  // ---------------------------------------------------------------------------
  // Sign-in methods
  // ---------------------------------------------------------------------------

  /// Starts the Google OAuth sign-in flow.
  ///
  /// TODO: Wire up to Clerk widget-tree API once `clerk_flutter` stabilises.
  /// For now this is a stub that sets auth state to loading.
  Future<void> signInWithGoogle() async {
    if (!_initialised) {
      authNotifier.setUnauthenticated(
        error: 'Clerk is not initialised. Check your publishable key.',
      );
      return;
    }

    authNotifier.setLoading();

    // TODO: Implement actual Google OAuth via ClerkAuth widget context.
    // The clerk_flutter 0.0.14-beta SDK requires using ClerkAuth as an
    // InheritedWidget — sign-in should be triggered from within the widget
    // tree using ClerkAuth.of(context). For now we reset to unauthenticated.
    developer.log(
      'signInWithGoogle() stub called — real OAuth not yet wired',
      name: 'ClerkService',
    );
    authNotifier.setUnauthenticated(
      error: 'Google sign-in not yet implemented.',
    );
  }

  /// Starts the Apple OAuth sign-in flow.
  ///
  /// TODO: Wire up to Clerk widget-tree API once `clerk_flutter` stabilises.
  Future<void> signInWithApple() async {
    if (!_initialised) {
      authNotifier.setUnauthenticated(
        error: 'Clerk is not initialised. Check your publishable key.',
      );
      return;
    }

    authNotifier.setLoading();

    // TODO: Implement actual Apple OAuth via ClerkAuth widget context.
    developer.log(
      'signInWithApple() stub called — real OAuth not yet wired',
      name: 'ClerkService',
    );
    authNotifier.setUnauthenticated(
      error: 'Apple sign-in not yet implemented.',
    );
  }

  // ---------------------------------------------------------------------------
  // Sign-out
  // ---------------------------------------------------------------------------

  /// Signs the current user out and clears the session.
  ///
  /// TODO: Call actual Clerk sign-out via widget context.
  Future<void> signOut() async {
    authNotifier.setUnauthenticated();
  }

  // ---------------------------------------------------------------------------
  // Convex token
  // ---------------------------------------------------------------------------

  /// Returns a JWT suitable for authenticating with the Convex backend.
  ///
  /// TODO: Retrieve token from Clerk session via widget context using the
  /// `'convex'` JWT template. Returns `null` until implemented.
  Future<String?> getConvexToken() async {
    // TODO: Implement once Clerk widget-tree auth is wired up.
    return null;
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

  /// Cleans up resources. Safe to call multiple times.
  void dispose() {
    _initialised = false;
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
