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
  // Sign-out
  // ---------------------------------------------------------------------------

  /// Signs the current user out and clears the session.
  ///
  /// Note: Sign-in is handled by the [ClerkAuthentication] widget in the
  /// widget tree. This method only handles sign-out via [AuthNotifier].
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
