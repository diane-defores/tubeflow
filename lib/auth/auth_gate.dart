import 'dart:developer' as developer;

import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tubeflow_app/app/router.dart';
import 'package:tubeflow_app/auth/auth_state.dart';

const _clerkPublishableKey = String.fromEnvironment(
  'CLERK_PUBLISHABLE_KEY',
  defaultValue: '',
);

class ClerkSignInPage extends StatelessWidget {
  const ClerkSignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (_clerkPublishableKey.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Clerk is not configured for this build. '
              'The app is accessible in guest mode.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return ClerkAuth(
      config: ClerkAuthConfig(
        publishableKey: _clerkPublishableKey,
        loading: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading sign-in...',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      child: const ClerkErrorListener(
        child: AuthGate(
          child: SizedBox.shrink(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AuthGate
// ---------------------------------------------------------------------------

/// Sign-in screen that uses [ClerkAuthBuilder] to react to Clerk auth state.
///
/// - **Signed out**: shows branding + [ClerkAuthentication] (Google, Apple, etc.)
/// - **Signed in**: syncs user to [AuthNotifier] → GoRouter redirects to app
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClerkAuthBuilder(
      signedInBuilder: (context, authState) {
        // Clerk signed the user in — sync to our AuthNotifier so the
        // router picks it up and redirects away from /sign-in.
        _syncSignedIn(ref, context);
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
      signedOutBuilder: (context, authState) {
        return _SignInScreen(child: child);
      },
    );
  }

  void _syncSignedIn(WidgetRef ref, BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      final notifier = ref.read(authStateProvider.notifier);
      if (notifier.isAuthenticated) {
        context.go(Routes.videos);
        return;
      }

      try {
        final clerk = ClerkAuth.of(context);
        final user = clerk.user;
        if (user != null) {
          notifier.setAuthenticated(AuthUser(
            id: user.id,
            email: user.emailAddresses?.firstOrNull?.identifier ?? '',
            displayName:
                '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim(),
            imageUrl: user.imageUrl,
          ));
          if (context.mounted) {
            context.go(Routes.videos);
          }
          return;
        }
      } catch (e) {
        developer.log('Failed to read Clerk user', error: e);
      }

      // Fallback: mark as authenticated even without user details so
      // the router can redirect away from the sign-in screen.
      notifier.setAuthenticated(const AuthUser(id: 'clerk-user', email: ''));
      if (context.mounted) {
        context.go(Routes.videos);
      }
    });
  }
}

// ---------------------------------------------------------------------------
// Sign-in screen
// ---------------------------------------------------------------------------

class _SignInScreen extends StatelessWidget {
  const _SignInScreen({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 48),

                  // --- Logo / branding ---
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.play_circle_filled_rounded,
                      size: 48,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // --- Title ---
                  Text(
                    'TubeFlow',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // --- Subtitle ---
                  Text(
                    'Watch videos. Take notes.\nStay in the flow.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // --- Clerk sign-in (handles Google, Apple, etc.) ---
                  const ClerkAuthentication(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
