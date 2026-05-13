import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tubeflow_app/app/router.dart';
import 'package:tubeflow_app/auth/auth_state.dart';
import 'package:tubeflow_app/auth/auth_service.dart';
import 'package:tubeflow_app/widgets/error_feedback.dart';

class AuthSignInPage extends ConsumerStatefulWidget {
  const AuthSignInPage({super.key});

  @override
  ConsumerState<AuthSignInPage> createState() => _AuthSignInPageState();
}

class _AuthSignInPageState extends ConsumerState<AuthSignInPage> {
  bool _submitting = false;

  String _redirectTarget() {
    final target = GoRouterState.of(context).uri.queryParameters['tf_redirect'];
    if (target == null || target.isEmpty) return Routes.videos;
    return target.startsWith('/') ? target : '/$target';
  }

  Future<void> _signIn() async {
    setState(() => _submitting = true);
    try {
      final service = ref.read(authServiceProvider);
      await service.signInWithGoogle();
      if (!mounted) return;
      context.go(_redirectTarget());
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, error: e, prefix: 'Sign-in failed');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);
    final service = ref.watch(authServiceProvider);

    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next is AuthAuthenticated && mounted) {
        context.go(_redirectTarget());
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.play_circle_outline,
                  size: 44,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text('TubeFlow', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text(
                  'Sign in with Google to sync videos, playlists, notes, and '
                  'YouTube connection state through Convex.',
                  style: theme.textTheme.bodyLarge,
                ),
                if (authState case AuthUnauthenticated(
                  :final error,
                ) when error != null && error.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  InlineErrorCard(error: error, prefix: 'Auth unavailable'),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _submitting || !service.isInitialised
                      ? null
                      : _signIn,
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(
                    service.isInitialised
                        ? 'Continue with Google'
                        : 'Firebase Auth not configured',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthSsoCallbackPage extends StatelessWidget {
  const AuthSsoCallbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthSignInPage();
  }
}
