import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lightweight user info extracted from the configured auth provider.
///
/// This stays decoupled from SDK types so auth state can be managed without
/// pulling beta authentication packages into the app.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.imageUrl,
  });

  /// Provider user ID.
  final String id;

  /// Primary email address.
  final String email;

  /// Display name (first + last, or email fallback).
  final String? displayName;

  /// Avatar URL, if available.
  final String? imageUrl;

  /// Returns [displayName] when available, otherwise [email].
  String get label => displayName ?? email;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AuthUser(id: $id, email: $email)';
}

// ---------------------------------------------------------------------------
// Sealed auth state
// ---------------------------------------------------------------------------

/// Represents the authentication lifecycle.
///
/// Use pattern matching (`switch`/`when`) to handle each case:
/// ```dart
/// final state = ref.watch(authStateProvider);
/// switch (state) {
///   case AuthUnauthenticated():   // show sign-in
///   case AuthLoading():           // show spinner
///   case AuthAuthenticated(:var user): // show app
/// }
/// ```
sealed class AuthState {
  const AuthState();
}

/// No user session exists.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.error});

  /// If the previous sign-in attempt failed, the error message.
  final String? error;
}

/// A sign-in or token refresh is in progress.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// The user is signed in and a valid session exists.
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);

  final AuthUser user;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Manages transitions between [AuthState] variants.
///
/// The auth service drives this notifier — call [setLoading],
/// [setAuthenticated], or [setUnauthenticated] as the session changes.
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthLoading();

  /// Transition to the loading state (sign-in initiated).
  void setLoading() => state = const AuthLoading();

  /// Transition to the authenticated state with the given [user].
  void setAuthenticated(AuthUser user) => state = AuthAuthenticated(user);

  /// Transition to the unauthenticated state, optionally with an [error].
  void setUnauthenticated({String? error}) =>
      state = AuthUnauthenticated(error: error);

  /// Convenience: whether the current state is [AuthAuthenticated].
  bool get isAuthenticated => state is AuthAuthenticated;

  /// The current user, or `null` if not authenticated.
  AuthUser? get currentUser {
    final s = state;
    return s is AuthAuthenticated ? s.user : null;
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

/// Global auth state provider.
///
/// Read from anywhere in the widget tree:
/// ```dart
/// final authState = ref.watch(authStateProvider);
/// ```
///
/// Mutate through the notifier:
/// ```dart
/// ref.read(authStateProvider.notifier).setAuthenticated(user);
/// ```
final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
