import 'dart:async';

import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tubeflow_app/auth/auth_state.dart';
import 'package:tubeflow_app/auth/clerk_web_persistor.dart';
import 'package:tubeflow_app/utils/app_logger.dart';

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

/// Clerk publishable key injected at build time via `--dart-define`.
const _legacyPublishableKey = String.fromEnvironment(
  'NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY',
  defaultValue: '',
);

const _publishableKey = String.fromEnvironment(
  'CLERK_PUBLISHABLE_KEY',
  defaultValue: _legacyPublishableKey,
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
      AppLogger.instance.log(
        'CLERK_PUBLISHABLE_KEY is empty — auth will not work. '
        'Pass --dart-define=CLERK_PUBLISHABLE_KEY=pk_... at build time.',
        source: 'ClerkService',
        level: LogLevel.warning,
      );
      return;
    }

    final config = kIsWeb
        ? ClerkAuthConfig(
            publishableKey: _publishableKey,
            persistor: ClerkWebPersistor(),
            fileCache: NoopClerkFileCache(),
          )
        : ClerkAuthConfig(publishableKey: _publishableKey);

    try {
      _authState = await ClerkAuthState.create(
        config: config,
      );
      AppLogger.instance.log(
        'ClerkAuthState.create succeeded (isSignedIn=${_authState?.isSignedIn})',
        source: 'ClerkService',
      );
      _authState?.addListener(_syncAuthNotifier);
      _syncAuthNotifier();
    } catch (e, st) {
      AppLogger.instance.log(
        'Failed to initialise ClerkAuthState',
        source: 'ClerkService',
        level: LogLevel.error,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Reactive sync Clerk → AuthNotifier
  // ---------------------------------------------------------------------------

  /// Listener wired on [ClerkAuthState]. Translates the Clerk session into
  /// the app's sealed [AuthState] so the router can react immediately.
  void _syncAuthNotifier() {
    final auth = _authState;
    if (auth == null) {
      authNotifier.setUnauthenticated();
      return;
    }

    if (auth.isSignedIn) {
      final user = auth.user;
      final authUser = user != null
          ? _toAuthUser(user)
          : const AuthUser(id: 'clerk-user', email: '');
      if (authNotifier.currentUser?.id != authUser.id) {
        AppLogger.instance.log(
          'Clerk session synced: ${authUser.id}',
          source: 'ClerkService',
        );
      }
      authNotifier.setAuthenticated(authUser);
    } else {
      if (authNotifier.isAuthenticated) {
        AppLogger.instance.log('Clerk session ended', source: 'ClerkService');
      }
      authNotifier.setUnauthenticated();
    }
  }

  AuthUser _toAuthUser(clerk.User user) {
    final displayName =
        '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim();
    return AuthUser(
      id: user.id,
      email: user.emailAddresses?.firstOrNull?.identifier ?? '',
      displayName: displayName.isEmpty ? null : displayName,
      imageUrl: user.imageUrl,
    );
  }

  // ---------------------------------------------------------------------------
  // Sign-out
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    try {
      await _authState?.signOut();
    } catch (e, st) {
      AppLogger.instance.log(
        'Clerk signOut failed',
        source: 'ClerkService',
        level: LogLevel.error,
        error: e,
        stackTrace: st,
      );
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
      AppLogger.instance.log(
        'Failed to mint Convex JWT from Clerk',
        source: 'ClerkService',
        level: LogLevel.error,
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
      _authState?.removeListener(_syncAuthNotifier);
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
