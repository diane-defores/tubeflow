import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:replayglowz_app/auth/auth_state.dart';
import 'package:replayglowz_app/auth/firebase_config.dart';
import 'package:replayglowz_app/utils/app_logger.dart';

/// Firebase-backed auth service.
///
/// Firebase Auth is the source of truth for Flutter auth and Convex JWTs.
class AuthService {
  AuthService({required this.authNotifier}) {
    _initialise();
  }

  final AuthNotifier authNotifier;
  final Completer<void> _ready = Completer<void>();

  StreamSubscription<firebase_auth.User?>? _authSubscription;
  firebase_auth.FirebaseAuth? _auth;
  firebase_auth.User? _currentUser;
  bool _isInitialised = false;

  Future<void> get ready => _ready.future;

  bool get isInitialised => _isInitialised;

  bool get isAuthenticated => _currentUser != null;

  firebase_auth.User? get currentUser => _currentUser;

  firebase_auth.User? get authState => _currentUser;

  Future<void> _initialise() async {
    try {
      final options = firebaseOptions();
      if (options == null) {
        authNotifier.setUnauthenticated(
          error: 'Firebase Auth is not configured for this build.',
        );
        AppLogger.instance.log(
          'Firebase Auth skipped: missing FIREBASE_* dart-defines',
          source: 'AuthService',
          level: LogLevel.warning,
        );
        _ready.complete();
        return;
      }

      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }

      _auth = firebase_auth.FirebaseAuth.instance;
      _currentUser = _auth!.currentUser;
      _syncAuthUser(_currentUser);
      _authSubscription = _auth!.authStateChanges().listen(_handleAuthChange);
      _isInitialised = true;
      AppLogger.instance.log(
        'Firebase Auth initialised',
        source: 'AuthService',
      );
      _ready.complete();
    } catch (e, st) {
      authNotifier.setUnauthenticated(error: '$e');
      AppLogger.instance.log(
        'Firebase Auth initialisation failed',
        source: 'AuthService',
        level: LogLevel.error,
        error: e,
        stackTrace: st,
      );
      if (!_ready.isCompleted) {
        _ready.completeError(e, st);
      }
    }
  }

  void _handleAuthChange(firebase_auth.User? user) {
    _currentUser = user;
    _syncAuthUser(user);
  }

  void _syncAuthUser(firebase_auth.User? user) {
    if (user == null) {
      authNotifier.setUnauthenticated();
      return;
    }

    authNotifier.setAuthenticated(
      AuthUser(
        id: user.uid,
        email: user.email ?? '',
        displayName: user.displayName,
        imageUrl: user.photoURL,
      ),
    );
  }

  Future<void> signInWithGoogle() async {
    await ready;
    final auth = _auth;
    if (auth == null) {
      throw StateError('Firebase Auth is not configured for this build.');
    }

    authNotifier.setLoading();
    final provider = firebase_auth.GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile');

    try {
      if (kIsWeb) {
        await auth.signInWithPopup(provider);
      } else {
        await auth.signInWithProvider(provider);
      }
    } on firebase_auth.FirebaseAuthException catch (e, st) {
      final message = _firebaseAuthErrorMessage(e);
      authNotifier.setUnauthenticated(error: message);
      AppLogger.instance.log(
        'Firebase Google sign-in failed',
        source: 'AuthService',
        level: LogLevel.error,
        error: e,
        stackTrace: st,
      );
      rethrow;
    } catch (e, st) {
      authNotifier.setUnauthenticated(error: '$e');
      AppLogger.instance.log(
        'Firebase Google sign-in failed',
        source: 'AuthService',
        level: LogLevel.error,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  String _firebaseAuthErrorMessage(firebase_auth.FirebaseAuthException error) {
    final details = <String>[
      'Firebase Auth ${error.code}',
      if (error.message != null && error.message!.trim().isNotEmpty)
        error.message!.trim(),
    ];

    if (error.code == 'internal-error') {
      details.add(
        'Check the browser console for a blocked popup, blocked frame, or '
        'Firebase authorized-domain error.',
      );
    }

    return details.join(': ');
  }

  Future<String?> getConvexToken({bool forceRefresh = false}) async {
    await ready;
    return _auth?.currentUser?.getIdToken(forceRefresh);
  }

  Future<bool> waitForConvexTokenReady() async {
    await ready;
    for (var attempt = 0; attempt < 8; attempt++) {
      final token = await getConvexToken(forceRefresh: attempt == 0);
      if (token != null && token.isNotEmpty) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return false;
  }

  Future<void> signOut() async {
    await _auth?.signOut();
    authNotifier.setUnauthenticated();
  }

  void dispose() {
    unawaited(_authSubscription?.cancel());
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  final authNotifier = ref.read(authStateProvider.notifier);
  final service = AuthService(authNotifier: authNotifier);
  ref.onDispose(service.dispose);
  return service;
});

final convexAuthReadyProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(authServiceProvider);
  await service.ready;
  return service.waitForConvexTokenReady();
});
