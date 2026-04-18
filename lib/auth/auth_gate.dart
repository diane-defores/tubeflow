import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tubeflow_app/app/build_info.dart';
import 'package:tubeflow_app/app/router.dart';
import 'package:tubeflow_app/auth/auth_state.dart';
import 'package:tubeflow_app/auth/clerk_service.dart';
import 'package:tubeflow_app/utils/app_logger.dart';
import 'package:tubeflow_app/widgets/error_feedback.dart';

class ClerkSignInPage extends ConsumerWidget {
  const ClerkSignInPage({super.key});

  Future<void> _handleClerkError(
    BuildContext context,
    clerk.ClerkError error,
  ) async {
    if (!context.mounted) return;
    showErrorSnackBar(
      context,
      error: error.toString(),
      prefix: 'Sign-in error',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(clerkServiceProvider).authState;

    if (authState == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: InlineErrorCard(
              error:
                  'Clerk is not configured for this build. '
                  'The app is accessible in guest mode.',
              prefix: 'Sign-in unavailable',
            ),
          ),
        ),
      );
    }

    return ClerkAuth(
      authState: authState,
      child: ClerkErrorListener(
        handler: _handleClerkError,
        child: AuthGate(child: SizedBox.shrink()),
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
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
        final clerkAuth = ClerkAuth.of(context);
        final user = clerkAuth.user;
        if (user != null) {
          AppLogger.instance.log(
            'Clerk user synced: ${user.id}',
            source: 'AuthGate',
          );
          notifier.setAuthenticated(
            AuthUser(
              id: user.id,
              email: user.emailAddresses?.firstOrNull?.identifier ?? '',
              displayName: '${user.firstName ?? ''} ${user.lastName ?? ''}'
                  .trim(),
              imageUrl: user.imageUrl,
            ),
          );
          if (context.mounted) {
            context.go(Routes.videos);
          }
          return;
        }
      } catch (e) {
        AppLogger.instance.log(
          'Failed to read Clerk user',
          source: 'AuthGate',
          level: LogLevel.error,
          error: e,
        );
      }

      notifier.setAuthenticated(const AuthUser(id: 'clerk-user', email: ''));
      if (context.mounted) {
        context.go(Routes.videos);
      }
    });
  }
}

// ---------------------------------------------------------------------------
// Sign-in screen — custom UI replacing ClerkAuthentication widget
// ---------------------------------------------------------------------------

class _SignInScreen extends ConsumerStatefulWidget {
  const _SignInScreen({required this.child});

  final Widget child;

  @override
  ConsumerState<_SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<_SignInScreen> {
  bool _loading = false;
  String? _error;

  List<String> _diagnosticLines({
    ClerkAuthState? authState,
    ClerkService? clerkService,
  }) {
    final envEmpty = authState?.env.isEmpty ?? true;
    final strategies = envEmpty || authState == null
        ? const <String>[]
        : authState.env.strategies.map((s) => s.name).toList();
    final social = envEmpty || authState == null
        ? const <String>[]
        : authState.env.socialConnections
              .map((s) => s.strategy.provider ?? s.strategy.name)
              .toList();

    return [
      'TubeFlow sign-in diagnostics',
      'Build commit: $buildCommitSha',
      'Build environment: $buildEnvironment',
      'Build timestamp: $buildTimestamp',
      'Build mode: ${buildModeLabel()}',
      'Current URL: ${kIsWeb ? Uri.base.toString() : 'not-web'}',
      'Current host: ${kIsWeb ? Uri.base.host : 'not-web'}',
      'Current path: ${kIsWeb ? Uri.base.path : 'not-web'}',
      'CONVEX_URL: ${convexUrl.isNotEmpty ? convexUrl : '(missing)'}',
      'CLERK_PUBLISHABLE_KEY: ${clerkPublishableKey.isNotEmpty ? maskValue(clerkPublishableKey) : '(missing)'}',
      'TUBEFLOW_APP_URL: ${tubeFlowAppUrl.isNotEmpty ? tubeFlowAppUrl : '(missing)'}',
      'TUBEFLOW_APP_URL host match: ${hostMatchLabel(tubeFlowAppUrl)}',
      'Clerk service initialised: ${clerkService?.isInitialised == true ? 'yes' : 'no'}',
      'Clerk env empty: ${envEmpty ? 'yes' : 'no'}',
      'Clerk isSignedIn: ${authState?.isSignedIn == true ? 'yes' : 'no'}',
      'Strategies: ${strategies.isEmpty ? 'none' : strategies.join(', ')}',
      'Social connections: ${social.isEmpty ? 'none' : social.join(', ')}',
      'Last sign-in error: ${_error ?? 'none'}',
    ];
  }

  Future<void> _copyDiagnostics({
    required ClerkAuthState authState,
    required ClerkService clerkService,
  }) async {
    final lines = [
      ..._diagnosticLines(authState: authState, clerkService: clerkService),
      '',
      'Recent logs:',
      AppLogger.instance.formatAll(),
    ];

    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign-in diagnostics copied.')),
    );
  }

  @override
  void initState() {
    super.initState();
    _logEnvState();
  }

  void _logEnvState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final authState = ClerkAuth.of(context);
        final envEmpty = authState.env.isEmpty;
        final strategies = envEmpty
            ? <clerk.Strategy>[]
            : authState.env.strategies;
        final social = envEmpty
            ? <clerk.SocialConnection>[]
            : authState.env.socialConnections;
        AppLogger.instance.log(
          'SignIn env: isEmpty=$envEmpty, '
          'strategies=${strategies.map((s) => s.name).toList()}, '
          'social=${social.map((s) => s.strategy.name).toList()}',
          source: 'SignInScreen',
        );
      } catch (e) {
        AppLogger.instance.log(
          'Could not read Clerk env',
          source: 'SignInScreen',
          level: LogLevel.warning,
          error: e,
        );
      }
    });
  }

  Future<void> _signInWithStrategy(clerk.Strategy strategy) async {
    final authState = ClerkAuth.of(context);
    if (authState.env.isEmpty) {
      setState(() {
        _error =
            'Clerk sign-in is unavailable for this build. Verify the '
            'production CLERK_PUBLISHABLE_KEY and the allowed app domain in '
            'the Clerk dashboard.';
      });
      AppLogger.instance.log(
        'Blocked sign-in because Clerk environment is empty',
        source: 'SignInScreen',
        level: LogLevel.warning,
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      AppLogger.instance.log(
        'Starting ssoSignIn with ${strategy.name}',
        source: 'SignInScreen',
      );
      await authState.ssoSignIn(context, strategy);
    } catch (e) {
      AppLogger.instance.log(
        'ssoSignIn failed',
        source: 'SignInScreen',
        level: LogLevel.error,
        error: e,
      );
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final clerkService = ref.watch(clerkServiceProvider);
    final authState = ClerkAuth.of(context);

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

                  Text(
                    'TubeFlow',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  Text(
                    'Watch videos. Take notes.\nStay in the flow.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Sign-in buttons
                  _SignInButtons(
                    loading: _loading,
                    onStrategy: _signInWithStrategy,
                  ),

                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.bug_report_outlined, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Diagnostics',
                                style: theme.textTheme.titleSmall,
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => _copyDiagnostics(
                                  authState: authState,
                                  clerkService: clerkService,
                                ),
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('Copy'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            _diagnosticLines(
                              authState: authState,
                              clerkService: clerkService,
                            ).join('\n'),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    InlineErrorCard(error: _error!, prefix: 'Sign-in error'),
                  ],

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

// ---------------------------------------------------------------------------
// Sign-in buttons — adapts to available Clerk env
// ---------------------------------------------------------------------------

class _SignInButtons extends StatelessWidget {
  const _SignInButtons({required this.loading, required this.onStrategy});

  final bool loading;
  final Future<void> Function(clerk.Strategy) onStrategy;

  static const _socialIcons = <String, IconData>{
    'google': Icons.g_mobiledata,
    'apple': Icons.apple,
    'github': Icons.code,
    'microsoft': Icons.window,
    'facebook': Icons.facebook,
  };

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: CircularProgressIndicator(),
      );
    }

    return ClerkAuthBuilder(
      builder: (context, authState) {
        final envAvailable = authState.env.isNotEmpty;

        if (envAvailable) {
          final social = authState.env.socialConnections;
          if (social.isNotEmpty) {
            return Column(
              children: [
                for (final connection in social) ...[
                  _SocialButton(
                    label:
                        connection.strategy.provider ??
                        connection.strategy.name,
                    icon:
                        _socialIcons[connection.strategy.provider] ??
                        Icons.login,
                    onPressed: () => onStrategy(connection.strategy),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          }

          final strategies = authState.env.strategies;
          if (strategies.isNotEmpty) {
            return Column(
              children: [
                for (final strategy in strategies) ...[
                  OutlinedButton(
                    onPressed: () => onStrategy(strategy),
                    child: Text(strategy.provider ?? strategy.name),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            );
          }
        }

        // Env not loaded or invalid — don't expose broken sign-in actions.
        final message = envAvailable
            ? 'No sign-in methods configured in Clerk.'
            : 'Clerk sign-in is unavailable. Check the publishable key '
                  'and the app domain configured in Clerk.';

        return InlineErrorCard(error: message, prefix: 'Sign-in unavailable');
      },
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        icon: Icon(icon, size: 24),
        label: Text('Continue with $label'),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
