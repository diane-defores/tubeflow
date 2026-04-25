import 'dart:async';
import 'dart:convert';

import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tubeflow_app/auth/auth_state.dart';
import 'package:tubeflow_app/auth/clerk_http_service.dart';
import 'package:tubeflow_app/auth/clerk_web_bridge.dart';
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
const _knownClerkWebSessionKey = 'known_clerk_web_session';
const _lastKnownWebUserKey = 'last_known_clerk_web_user';
const _postOAuthRouteParam = 'tf_redirect';

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
  bool _webStartupRestorePending = false;

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
    authNotifier.setLoading();

    if (_publishableKey.isEmpty) {
      AppLogger.instance.log(
        'CLERK_PUBLISHABLE_KEY is empty — auth will not work. '
        'Pass --dart-define=CLERK_PUBLISHABLE_KEY=pk_... at build time.',
        source: 'ClerkService',
        level: LogLevel.warning,
      );
      authNotifier.setUnauthenticated();
      return;
    }

    final config = kIsWeb
        ? ClerkAuthConfig(
            publishableKey: _publishableKey,
            persistor: ClerkWebPersistor(),
            fileCache: NoopClerkFileCache(),
            httpService: ClerkHttpService(),
          )
        : ClerkAuthConfig(publishableKey: _publishableKey);

    try {
      if (kIsWeb) {
        await initClerkWebBridge(_publishableKey);
        if (await _handleWebOAuthRedirectIfNeeded()) {
          return;
        }
        _webStartupRestorePending = true;
      }
      _authState = await ClerkAuthState.create(config: config);
      if (_authState?.env.isEmpty == true) {
        AppLogger.instance.log(
          'Clerk env is empty after create(); forcing refreshEnvironment()',
          source: 'ClerkService',
          level: LogLevel.warning,
        );
        await _authState?.refreshEnvironment();
      }
      if (_authState?.client.isEmpty == true) {
        AppLogger.instance.log(
          'Clerk client is empty after create(); forcing refreshClient()',
          source: 'ClerkService',
          level: LogLevel.warning,
        );
        await _authState?.refreshClient();
      }
      AppLogger.instance.log(
        'ClerkAuthState.create succeeded (isSignedIn=${_authState?.isSignedIn}, envEmpty=${_authState?.env.isEmpty}, clientEmpty=${_authState?.client.isEmpty})',
        source: 'ClerkService',
      );
      _authState?.addListener(_syncAuthNotifier);
      if (kIsWeb) {
        await _restoreWebSessionOnStartup();
      } else {
        _syncAuthNotifier();
      }
    } catch (e, st) {
      AppLogger.instance.log(
        'Failed to initialise ClerkAuthState',
        source: 'ClerkService',
        level: LogLevel.error,
        error: e,
        stackTrace: st,
      );
      authNotifier.setUnauthenticated(error: '$e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Reactive sync Clerk → AuthNotifier
  // ---------------------------------------------------------------------------

  Future<bool> _handleWebOAuthRedirectIfNeeded() async {
    if (!kIsWeb || Uri.base.path != '/sso-callback') {
      return false;
    }

    final target = Uri.base.queryParameters[_postOAuthRouteParam] ?? '/videos';
    final completeUrl = Uri.parse(Uri.base.origin)
        .replace(fragment: target.startsWith('/') ? target : '/$target')
        .toString();

    AppLogger.instance.log(
      'Handling Clerk OAuth redirect callback; completeUrl=$completeUrl',
      source: 'ClerkService',
    );

    try {
      await clerkWebHandleOAuthRedirect(completeUrl);
    } catch (e, st) {
      AppLogger.instance.log(
        'Clerk OAuth redirect callback failed',
        source: 'ClerkService',
        level: LogLevel.error,
        error: e,
        stackTrace: st,
      );
      authNotifier.setUnauthenticated(error: '$e');
    }
    return true;
  }

  /// Listener wired on [ClerkAuthState]. Translates the Clerk session into
  /// the app's sealed [AuthState] so the router can react immediately.
  void _syncAuthNotifier() {
    final auth = _authState;
    if (auth == null) {
      authNotifier.setLoading();
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
      unawaited(_persistKnownWebSession(true));
      unawaited(_persistLastKnownWebUser(authUser));
    } else {
      if (kIsWeb) {
        if (_webStartupRestorePending) {
          authNotifier.setLoading();
          return;
        }
        unawaited(_syncWebBridgeAuthState());
        return;
      }
      if (authNotifier.isAuthenticated) {
        AppLogger.instance.log('Clerk session ended', source: 'ClerkService');
      }
      authNotifier.setUnauthenticated();
    }
  }

  Future<void> _restoreWebSessionOnStartup() async {
    const maxAttempts = 7;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final auth = _authState;
      if (auth?.isSignedIn == true) {
        _webStartupRestorePending = false;
        _syncAuthNotifier();
        AppLogger.instance.log(
          'Clerk web startup restore resolved via ClerkAuthState on attempt $attempt',
          source: 'ClerkService',
        );
        return;
      }

      final signedIn = await clerkWebIsSignedIn();
      final user = signedIn ? await clerkWebGetUser() : null;

      AppLogger.instance.log(
        'Clerk web startup restore attempt $attempt/$maxAttempts: bridgeSignedIn=$signedIn user=${user?.id ?? 'none'}',
        source: 'ClerkService',
      );

      if (signedIn && user != null && user.id.isNotEmpty) {
        _webStartupRestorePending = false;
        final authUser = AuthUser(
          id: user.id,
          email: user.email,
          displayName: user.displayName.isEmpty ? null : user.displayName,
          imageUrl: user.imageUrl.isEmpty ? null : user.imageUrl,
        );
        AppLogger.instance.log(
          'Clerk JS web session restored during startup: ${authUser.id}',
          source: 'ClerkService',
        );
        authNotifier.setAuthenticated(authUser);
        await _persistKnownWebSession(true);
        await _persistLastKnownWebUser(authUser);
        return;
      }

      if (attempt < maxAttempts) {
        await _authState?.refreshClient();
        if (_authState?.env.isEmpty == true) {
          await _authState?.refreshEnvironment();
        }
        await Future<void>.delayed(const Duration(milliseconds: 450));
      }
    }

    _webStartupRestorePending = false;
    authNotifier.setUnauthenticated();
    await _persistKnownWebSession(false);
    AppLogger.instance.log(
      'Clerk web startup restore exhausted without an active session; sign-in is required',
      source: 'ClerkService',
      level: LogLevel.warning,
    );
  }

  Future<void> _syncWebBridgeAuthState() async {
    final signedIn = await clerkWebIsSignedIn();
    if (!signedIn) {
      if (_webStartupRestorePending) {
        authNotifier.setLoading();
        return;
      }
      if (authNotifier.isAuthenticated) {
        AppLogger.instance.log(
          'Clerk JS web session ended',
          source: 'ClerkService',
        );
      }
      authNotifier.setUnauthenticated();
      return;
    }

    final user = await clerkWebGetUser();
    if (user == null || user.id.isEmpty) {
      return;
    }

    final authUser = AuthUser(
      id: user.id,
      email: user.email,
      displayName: user.displayName.isEmpty ? null : user.displayName,
      imageUrl: user.imageUrl.isEmpty ? null : user.imageUrl,
    );

    if (authNotifier.currentUser?.id != authUser.id) {
      AppLogger.instance.log(
        'Clerk JS web session synced: ${authUser.id}',
        source: 'ClerkService',
      );
    }
    authNotifier.setAuthenticated(authUser);
    unawaited(_persistKnownWebSession(true));
    unawaited(_persistLastKnownWebUser(authUser));
  }

  Future<void> markAuthenticatedUser(AuthUser user) async {
    authNotifier.setAuthenticated(user);
    await _persistKnownWebSession(true);
    await _persistLastKnownWebUser(user);
  }

  AuthUser _toAuthUser(clerk.User user) {
    final displayName = '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim();
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
      if (kIsWeb) {
        await clerkWebSignOut();
      }
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
    await _persistKnownWebSession(false);
    await _persistLastKnownWebUser(null);
    authNotifier.setUnauthenticated();
  }

  Future<void> _persistKnownWebSession(bool value) async {
    if (!kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_knownClerkWebSessionKey, value);
  }

  Future<void> _persistLastKnownWebUser(AuthUser? user) async {
    if (!kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    if (user == null) {
      await prefs.remove(_lastKnownWebUserKey);
      return;
    }

    await prefs.setString(
      _lastKnownWebUserKey,
      jsonEncode({
        'id': user.id,
        'email': user.email,
        'displayName': user.displayName,
        'imageUrl': user.imageUrl,
      }),
    );
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
    if (kIsWeb) {
      try {
        final token = await clerkWebGetToken(template: _convexJwtTemplate);
        if (token != null && token.isNotEmpty) {
          return token;
        }
      } catch (e, st) {
        AppLogger.instance.log(
          'Failed to mint Convex JWT from Clerk JS bridge',
          source: 'ClerkService',
          level: LogLevel.error,
          error: e,
          stackTrace: st,
        );
      }
    }

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
