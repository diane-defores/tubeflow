import 'dart:async';
import 'dart:developer' as developer;

import 'package:clerk_flutter/clerk_flutter.dart';
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

/// Name of the JWT template configured in the Clerk dashboard for Convex.
///
/// Must match `applicationID` in `packages/backend/convex/auth.config.ts`.
const _convexJwtTemplate = 'convex';

// ---------------------------------------------------------------------------
// ClerkService
// ---------------------------------------------------------------------------

/// Owns a long-lived [ClerkAuthState] and exposes it to the rest of the app.
///
/// The [ClerkAuthState] is created once during bootstrap and shared between
/// the sign-in page (which mounts `ClerkAuth(authState: ...)`) and the
/// Convex client (which calls [getConvexToken] on every authenticated
/// request). Because the state lives in this service — not inside the
/// sign-in widget — the Clerk session survives navigation out of `/sign-in`.
class ClerkService {
  ClerkService({required this.authNotifier}) {
    _readyFuture = _init();
  }

  final AuthNotifier authNotifier;

  ClerkAuthState? _authState;
  late final Future<void> _readyFuture;

  /// Completes once [authState] is available (or initialisation has failed).
  Future<void> get ready => _readyFuture;

  /// The live Clerk auth state. Null until [ready] completes, or if the
  /// publishable key is missing.
  ClerkAuthState? get authState => _authState;

  String get publishableKey => _publishableKey;

  bool get isInitialised => _authState != null;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  Future<void> _init() async {
    if (_publishableKey.isEmpty) {
      developer.log(
        'CLERK_PUBLISHABLE_KEY is empty — auth will not work. '
        'Pass --dart-define=CLERK_PUBLISHABLE_KEY=pk_... at build time.',
        name: 'ClerkService',
      );
      return;
    }

    try {
      _authState = await ClerkAuthState.create(
        config: ClerkAuthConfig(publishableKey: _publishableKey),
      );
    } catch (e, st) {
      developer.log(
        'Failed to initialise ClerkAuthState',
        name: 'ClerkService',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Sign-out
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    try {
      await _authState?.signOut();
    } catch (e, st) {
      developer.log('Clerk signOut failed',
          name: 'ClerkService', error: e, stackTrace: st);
    }
    authNotifier.setUnauthenticated();
  }

  // ---------------------------------------------------------------------------
  // Convex token
  // ---------------------------------------------------------------------------

  /// Returns a JWT suitable for authenticating with Convex, minted from the
  /// `convex` JWT template configured in the Clerk dashboard.
  ///
  /// Returns `null` when the user has no active Clerk session, or when
  /// minting the token fails — in both cases Convex will fall back to
  /// unauthenticated access rather than raising.
  Future<String?> getConvexToken() async {
    final auth = _authState;
    if (auth == null || !auth.isSignedIn) {
      return null;
    }

    try {
      final token = await auth.sessionToken(templateName: _convexJwtTemplate);
      return token.jwt;
    } catch (e, st) {
      developer.log(
        'Failed to mint Convex JWT from Clerk',
        name: 'ClerkService',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Convenience getters
  // ---------------------------------------------------------------------------

  bool get isAuthenticated => authNotifier.isAuthenticated;

  AuthUser? get currentUser => authNotifier.currentUser;

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  void dispose() {
    try {
      _authState?.terminate();
    } catch (_) {
      // ignore — already terminated
    }
    _authState = null;
  }
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

/// Provides the singleton [ClerkService] wired to the global [AuthNotifier].
final clerkServiceProvider = Provider<ClerkService>((ref) {
  final authNotifier = ref.watch(authStateProvider.notifier);
  final service = ClerkService(authNotifier: authNotifier);

  ref.onDispose(() => service.dispose());

  return service;
});
