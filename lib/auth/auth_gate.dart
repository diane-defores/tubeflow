import 'dart:async';

import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tubeflow_app/app/build_info.dart';
import 'package:tubeflow_app/app/router.dart';
import 'package:tubeflow_app/auth/auth_state.dart';
import 'package:tubeflow_app/auth/clerk_service.dart';
import 'package:tubeflow_app/auth/clerk_web_bridge.dart';
import 'package:tubeflow_app/utils/app_logger.dart';
import 'package:tubeflow_app/widgets/error_feedback.dart';

const _postAuthRouteParam = 'tf_redirect';
const _postOAuthRouteParam = 'tf_redirect';

String _normalizePostAuthRoute(String? route) {
  if (route == null || route.isEmpty) return Routes.videos;
  if (route.startsWith('/')) return route;
  return '/$route';
}

String _currentPostAuthRoute() {
  if (!kIsWeb) return Routes.videos;

  final fragment = Uri.base.fragment;
  if (fragment.isEmpty) return Routes.videos;

  final parsed = Uri.parse(fragment.startsWith('/') ? fragment : '/$fragment');
  final path = parsed.path.isEmpty ? Routes.videos : parsed.path;
  if (path == '/' || path == Routes.signIn) {
    return Routes.videos;
  }

  return Uri(
    path: path,
    queryParameters: parsed.queryParameters.isEmpty
        ? null
        : parsed.queryParameters,
  ).toString();
}

String _resolvedPostAuthRoute() {
  if (!kIsWeb) return Routes.videos;
  return _normalizePostAuthRoute(Uri.base.queryParameters[_postAuthRouteParam]);
}

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
    final appAuthState = ref.watch(authStateProvider);
    final authState = ref.watch(clerkServiceProvider).authState;

    if (appAuthState is AuthLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (appAuthState is AuthAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go(_resolvedPostAuthRoute());
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (authState == null) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
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
        child: const AuthGate(child: SizedBox.shrink()),
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
      final clerkService = ref.read(clerkServiceProvider);
      if (notifier.isAuthenticated) {
        context.go(_resolvedPostAuthRoute());
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
          final authUser = AuthUser(
            id: user.id,
            email: user.emailAddresses?.firstOrNull?.identifier ?? '',
            displayName: '${user.firstName ?? ''} ${user.lastName ?? ''}'
                .trim(),
            imageUrl: user.imageUrl,
          );
          clerkService.markAuthenticatedUser(authUser).then((_) {
            if (context.mounted) {
              context.go(_resolvedPostAuthRoute());
            }
          });
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

      clerkService
          .markAuthenticatedUser(const AuthUser(id: 'clerk-user', email: ''))
          .then((_) {
            if (context.mounted) {
              context.go(_resolvedPostAuthRoute());
            }
          });
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

enum _EmailAuthMode { signIn, signUp }

class _SignInScreenState extends ConsumerState<_SignInScreen>
    with WidgetsBindingObserver {
  static const _pendingHostedSignInKey = 'pending_hosted_sign_in';

  bool _loading = false;
  String? _error;
  String? _notice;
  _EmailAuthMode _emailAuthMode = _EmailAuthMode.signIn;
  bool _awaitingEmailCodeVerification = false;
  String? _verificationEmail;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _verificationCodeController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  final _verificationCodeFocusNode = FocusNode();

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
      'CLERK_HOSTED_SIGN_IN_URL: ${clerkHostedSignInUrl().isNotEmpty ? clerkHostedSignInUrl() : '(missing)'}',
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
    WidgetsBinding.instance.addObserver(this);
    _logEnvState();
    unawaited(_clearLegacyHostedSignInState());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _verificationCodeController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _verificationCodeFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Clerk JS redirect callbacks are handled by ClerkService on page load.
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

  Future<void> _signInWithEmailPassword() async {
    final authState = ClerkAuth.of(context);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Enter both email and password.';
        _notice = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });

    try {
      AppLogger.instance.log(
        'Starting password sign-in fallback',
        source: 'SignInScreen',
      );
      await authState.attemptSignIn(
        strategy: clerk.Strategy.password,
        identifier: email,
        password: password,
      );
      TextInput.finishAutofillContext();
    } catch (e) {
      AppLogger.instance.log(
        'Password sign-in fallback failed',
        source: 'SignInScreen',
        level: LogLevel.error,
        error: e,
      );
      if (mounted) {
        setState(() {
          _error = '$e';
          _notice = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  bool _supportsDirectEmailSignUp(ClerkAuthState authState) {
    return authState.env.supportsEmailCode;
  }

  void _setEmailAuthMode(_EmailAuthMode mode) {
    setState(() {
      _emailAuthMode = mode;
      _awaitingEmailCodeVerification = false;
      _verificationEmail = null;
      _verificationCodeController.clear();
      _error = null;
      _notice = null;
    });
  }

  Future<void> _signUpWithEmailPassword() async {
    final authState = ClerkAuth.of(context);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final passwordConfirmation = _confirmPasswordController.text;

    if (email.isEmpty || password.isEmpty || passwordConfirmation.isEmpty) {
      setState(() {
        _error = 'Enter email, password, and password confirmation.';
        _notice = null;
      });
      return;
    }

    if (password != passwordConfirmation) {
      setState(() {
        _error = 'Passwords do not match.';
        _notice = null;
      });
      return;
    }

    if (!_supportsDirectEmailSignUp(authState)) {
      setState(() {
        _error =
            'This Clerk setup does not support direct email code sign-up here. Use the secure account portal instead.';
        _notice = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });

    try {
      AppLogger.instance.log(
        'Starting email sign-up flow',
        source: 'SignInScreen',
      );
      await authState.attemptSignUp(
        strategy: clerk.Strategy.emailCode,
        emailAddress: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );

      if (authState.isSignedIn || authState.user != null) {
        TextInput.finishAutofillContext();
      }

      if (authState.signUp?.unverified(clerk.Field.emailAddress) == true) {
        if (mounted) {
          setState(() {
            _awaitingEmailCodeVerification = true;
            _verificationEmail = email;
          });
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _verificationCodeFocusNode.requestFocus();
          }
        });
      }
    } catch (e) {
      AppLogger.instance.log(
        'Email sign-up failed',
        source: 'SignInScreen',
        level: LogLevel.error,
        error: e,
      );
      if (mounted) {
        setState(() {
          _error = '$e';
          _notice = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _verifyEmailSignUpCode() async {
    final authState = ClerkAuth.of(context);
    final code = _verificationCodeController.text.trim();

    if (code.isEmpty) {
      setState(() {
        _error = 'Enter the verification code sent by email.';
        _notice = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });

    try {
      AppLogger.instance.log(
        'Attempting email sign-up verification',
        source: 'SignInScreen',
      );
      await authState.attemptSignUp(
        strategy: clerk.Strategy.emailCode,
        code: code,
      );

      if (authState.isSignedIn || authState.user != null) {
        TextInput.finishAutofillContext();
      }

      if (mounted &&
          authState.signUp?.unverified(clerk.Field.emailAddress) != true) {
        setState(() {
          _awaitingEmailCodeVerification = false;
          _verificationEmail = null;
          _verificationCodeController.clear();
        });
      }
    } catch (e) {
      AppLogger.instance.log(
        'Email sign-up verification failed',
        source: 'SignInScreen',
        level: LogLevel.error,
        error: e,
      );
      if (mounted) {
        setState(() {
          _error = '$e';
          _notice = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _continueWithGoogleFallback() async {
    if (kIsWeb) {
      AppLogger.instance.log(
        'Starting Google sign-in through Clerk JS flow',
        source: 'SignInScreen',
      );
      await _startGoogleSignInWithClerkJs();
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });

    try {
      AppLogger.instance.log(
        'Starting Google fallback via fixed oauth strategy',
        source: 'SignInScreen',
      );
      await ClerkAuth.of(
        context,
      ).ssoSignIn(context, clerk.Strategy.oauthGoogle);
    } catch (e) {
      AppLogger.instance.log(
        'Google fallback sign-in failed',
        source: 'SignInScreen',
        level: LogLevel.error,
        error: e,
      );
      if (mounted) {
        setState(() {
          _error = '$e';
          _notice = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _startGoogleSignInWithClerkJs() async {
    final postAuthRoute = _currentPostAuthRoute();
    final origin = Uri.base.origin;
    final redirectUrl = Uri.parse(origin)
        .replace(
          path: '/sso-callback',
          queryParameters: {_postOAuthRouteParam: postAuthRoute},
        )
        .toString();
    final redirectUrlComplete = Uri.parse(
      origin,
    ).replace(fragment: postAuthRoute).toString();

    try {
      await _clearLegacyHostedSignInState();
      await clerkWebStartGoogleSignIn(
        redirectUrl: redirectUrl,
        redirectUrlComplete: redirectUrlComplete,
      );
    } catch (e) {
      AppLogger.instance.log(
        'Google Clerk JS redirect sign-in failed',
        source: 'SignInScreen',
        level: LogLevel.error,
        error: e,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
        _notice = null;
      });
    }
  }

  Future<void> _clearLegacyHostedSignInState() async {
    if (!kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_pendingHostedSignInKey) == true) {
      await prefs.remove(_pendingHostedSignInKey);
      AppLogger.instance.log(
        'Cleared stale hosted sign-in pending flag',
        source: 'SignInScreen',
      );
    }
  }

  Widget _buildSignInCard(
    ThemeData theme,
    ClerkAuthState authState, {
    required bool loading,
    bool compact = false,
  }) {
    final envEmpty = authState.env.isEmpty;
    final hasPassword = envEmpty || authState.env.hasPasswordStrategy;
    final hasGoogle =
        envEmpty ||
        authState.env.socialConnections.any(
          (connection) => connection.strategy.provider == 'google',
        );
    final isSignUpMode = _emailAuthMode == _EmailAuthMode.signUp;
    final description = envEmpty
        ? 'Clerk did not expose sign-in methods during the first render, so TubeFlow is using direct fallback actions instead.'
        : isSignUpMode
        ? 'Create your account with email here. Google and any other account recovery paths still open in the secure account portal.'
        : kIsWeb
        ? 'Email sign-in happens directly in TubeFlow. Google, sign-up, and recovery open in the secure account portal.'
        : 'TubeFlow uses direct email sign-in in the app and native Google sign-in when available.';
    final cardCrossAxisAlignment = compact
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    final cardTextAlign = compact ? TextAlign.center : TextAlign.start;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 20),
        child: Column(
          crossAxisAlignment: cardCrossAxisAlignment,
          children: [
            Align(
              alignment: compact ? Alignment.center : Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Secure access',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SizedBox(height: compact ? 12 : 16),
            if (hasPassword) ...[
              Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: SegmentedButton<_EmailAuthMode>(
                    segments: const [
                      ButtonSegment<_EmailAuthMode>(
                        value: _EmailAuthMode.signIn,
                        label: Text('Sign in'),
                      ),
                      ButtonSegment<_EmailAuthMode>(
                        value: _EmailAuthMode.signUp,
                        label: Text('Create account'),
                      ),
                    ],
                    selected: {_emailAuthMode},
                    onSelectionChanged: loading
                        ? null
                        : (selection) {
                            final mode = selection.first;
                            if (mode != _emailAuthMode) {
                              _setEmailAuthMode(mode);
                            }
                          },
                  ),
                ),
              ),
              SizedBox(height: compact ? 12 : 16),
            ],
            Text(
              envEmpty
                  ? (isSignUpMode ? 'Fallback sign-up' : 'Fallback sign-in')
                  : (isSignUpMode ? 'Create account' : 'Sign in'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: cardTextAlign,
            ),
            SizedBox(height: compact ? 6 : 8),
            Text(
              description,
              style: theme.textTheme.bodySmall,
              maxLines: compact ? 3 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
              textAlign: cardTextAlign,
            ),
            SizedBox(height: compact ? 12 : 16),
            if (loading) ...[
              const Center(child: CircularProgressIndicator()),
              SizedBox(height: compact ? 12 : 16),
            ],
            if (hasPassword) ...[
              AutofillGroup(
                child: Column(
                  children: [
                    TextField(
                      controller: _emailController,
                      focusNode: _emailFocusNode,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.none,
                      autocorrect: false,
                      enableSuggestions: false,
                      smartDashesType: SmartDashesType.disabled,
                      smartQuotesType: SmartQuotesType.disabled,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'you@example.com',
                      ),
                      onSubmitted: (_) {
                        _passwordFocusNode.requestFocus();
                      },
                    ),
                    SizedBox(height: compact ? 10 : 12),
                    TextField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      obscureText: true,
                      keyboardType: TextInputType.visiblePassword,
                      autofillHints: [
                        if (isSignUpMode)
                          AutofillHints.newPassword
                        else
                          AutofillHints.password,
                      ],
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      smartDashesType: SmartDashesType.disabled,
                      smartQuotesType: SmartQuotesType.disabled,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter your password',
                      ),
                      onSubmitted: (_) {
                        if (isSignUpMode) {
                          _confirmPasswordFocusNode.requestFocus();
                        } else {
                          _signInWithEmailPassword();
                        }
                      },
                    ),
                    if (isSignUpMode) ...[
                      SizedBox(height: compact ? 10 : 12),
                      TextField(
                        controller: _confirmPasswordController,
                        focusNode: _confirmPasswordFocusNode,
                        obscureText: true,
                        keyboardType: TextInputType.visiblePassword,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        smartDashesType: SmartDashesType.disabled,
                        smartQuotesType: SmartQuotesType.disabled,
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                          hintText: 'Repeat your password',
                        ),
                        onSubmitted: (_) => _signUpWithEmailPassword(),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: compact ? 12 : 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: loading
                      ? null
                      : isSignUpMode
                      ? _signUpWithEmailPassword
                      : _signInWithEmailPassword,
                  child: Text(
                    isSignUpMode
                        ? 'Create account with email'
                        : 'Sign in with email',
                  ),
                ),
              ),
              if (isSignUpMode && _awaitingEmailCodeVerification) ...[
                SizedBox(height: compact ? 10 : 12),
                Card(
                  margin: EdgeInsets.zero,
                  color: theme.colorScheme.primary.withValues(alpha: 0.06),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verify your email',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _verificationEmail == null
                              ? 'Enter the code sent by email to finish creating your account.'
                              : 'Enter the code sent to $_verificationEmail to finish creating your account.',
                          style: theme.textTheme.bodySmall,
                        ),
                        SizedBox(height: compact ? 10 : 12),
                        TextField(
                          controller: _verificationCodeController,
                          focusNode: _verificationCodeFocusNode,
                          keyboardType: TextInputType.number,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          textInputAction: TextInputAction.done,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(
                            labelText: 'Verification code',
                            hintText: '123456',
                          ),
                          onSubmitted: (_) => _verifyEmailSignUpCode(),
                        ),
                        SizedBox(height: compact ? 10 : 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: loading ? null : _verifyEmailSignUpCode,
                            child: const Text('Verify email code'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (hasGoogle) ...[
                SizedBox(height: compact ? 14 : 18),
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: theme.colorScheme.outline.withValues(alpha: 0.7),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or', style: theme.textTheme.labelSmall),
                    ),
                    Expanded(
                      child: Divider(
                        color: theme.colorScheme.outline.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 14 : 18),
              ] else
                SizedBox(height: compact ? 10 : 12),
            ],
            if (hasGoogle)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: loading ? null : _continueWithGoogleFallback,
                  icon: const Icon(Icons.login),
                  label: const Text(
                    kIsWeb ? 'Continue with Google' : 'Continue with Google',
                  ),
                ),
              ),
            if (hasGoogle && kIsWeb && !compact) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.45,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.open_in_new,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Google opens the secure TubeFlow account portal in this tab. Use it for Google sign-in, password recovery, or any extra sign-in methods.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final clerkService = ref.watch(clerkServiceProvider);
    final authState = ClerkAuth.of(context);
    final errorCard = _error != null
        ? InlineErrorCard(error: _error!, prefix: 'Sign-in error')
        : null;
    final noticeCard = _notice != null
        ? Card(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _notice!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodyMedium?.color,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        : null;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surface,
              colorScheme.surface,
              colorScheme.primary.withValues(alpha: 0.06),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -80,
              child: _AuthGlow(
                size: 280,
                color: colorScheme.primary.withValues(alpha: 0.10),
              ),
            ),
            Positioned(
              bottom: -140,
              right: -110,
              child: _AuthGlow(
                size: 320,
                color: colorScheme.secondary.withValues(alpha: 0.16),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 980;
                  final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
                  final isKeyboardOpen = keyboardInset > 0;
                  final isCompactMobile =
                      constraints.maxWidth < 768 ||
                      (constraints.maxWidth < 980 && isKeyboardOpen);

                  return Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isWide ? 40 : 20,
                        vertical: isCompactMobile
                            ? (isKeyboardOpen ? 8 : 12)
                            : (isWide ? 32 : 20),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: isCompactMobile
                            ? _buildCompactMobileLayout(
                                theme,
                                authState,
                                clerkService,
                                noticeCard: noticeCard,
                                errorCard: errorCard,
                                isKeyboardOpen: isKeyboardOpen,
                                keyboardInset: keyboardInset,
                              )
                            : SingleChildScrollView(
                                child: isWide
                                    ? Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                right: 28,
                                              ),
                                              child: _buildHeroPanel(theme),
                                            ),
                                          ),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 460,
                                            ),
                                            child: _buildAuthColumn(
                                              theme,
                                              authState,
                                              clerkService,
                                              noticeCard,
                                              errorCard,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildHeroPanel(theme, compact: true),
                                          const SizedBox(height: 24),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 460,
                                            ),
                                            child: _buildAuthColumn(
                                              theme,
                                              authState,
                                              clerkService,
                                              noticeCard,
                                              errorCard,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactMobileLayout(
    ThemeData theme,
    ClerkAuthState authState,
    ClerkService clerkService, {
    Widget? noticeCard,
    Widget? errorCard,
    bool isKeyboardOpen = false,
    double keyboardInset = 0,
  }) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeroPanel(theme, compact: true, mobileFit: true),
        const SizedBox(height: 12),
        _buildSignInCard(theme, authState, loading: _loading, compact: true),
        const SizedBox(height: 10),
        _buildCompactSupportRow(
          theme,
          authState,
          clerkService,
          noticeCard: noticeCard,
          errorCard: errorCard,
        ),
      ],
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: isKeyboardOpen ? keyboardInset : 0),
        child: isKeyboardOpen
            ? SingleChildScrollView(child: content)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [content],
              ),
      ),
    );
  }

  Widget _buildHeroPanel(
    ThemeData theme, {
    bool compact = false,
    bool mobileFit = false,
  }) {
    final colorScheme = theme.colorScheme;
    if (mobileFit) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.16),
                    colorScheme.primary.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                Icons.play_circle_filled_rounded,
                size: 38,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Built for focused video study',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'TubeFlow',
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 0.95,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Watch videos, capture key moments, and keep every note attached to the exact second that matters.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.45,
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.86,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _AuthFeaturePill(
                  icon: Icons.schedule,
                  label: 'Timestamped notes',
                  compact: true,
                ),
                _AuthFeaturePill(
                  icon: Icons.sync_rounded,
                  label: 'Resume anywhere',
                  compact: true,
                ),
                _AuthFeaturePill(
                  icon: Icons.lock_outline_rounded,
                  label: 'Secure Google sign-in',
                  compact: true,
                ),
                _AuthFeaturePill(
                  icon: Icons.playlist_play_rounded,
                  label: 'Playlist management',
                  compact: true,
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(compact ? 24 : 36),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 72 : 84,
            height: compact ? 72 : 84,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary.withValues(alpha: 0.16),
                  colorScheme.primary.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.play_circle_filled_rounded,
              size: compact ? 40 : 48,
              color: colorScheme.primary,
            ),
          ),
          SizedBox(height: compact ? 20 : 28),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Built for focused video study',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'TubeFlow',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 0.95,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Watch videos. Capture the important moments. Keep your notes attached to the exact second they matter.',
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.55,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.86),
            ),
          ),
          SizedBox(height: compact ? 20 : 28),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _AuthFeaturePill(
                icon: Icons.schedule,
                label: 'Timestamped notes',
              ),
              _AuthFeaturePill(
                icon: Icons.subtitles_outlined,
                label: 'Transcripts and playback',
              ),
              _AuthFeaturePill(
                icon: Icons.playlist_play_rounded,
                label: 'Playlists and study flow',
              ),
            ],
          ),
          SizedBox(height: compact ? 20 : 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.38,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What changes once you sign in',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _buildHeroPoint(theme, 'Resume your workspace across devices.'),
                const SizedBox(height: 10),
                _buildHeroPoint(
                  theme,
                  'Keep watch progress, notes, and preferences in sync.',
                ),
                const SizedBox(height: 10),
                _buildHeroPoint(
                  theme,
                  'Unlock Google sign-in and the rest of the account portal safely.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPoint(ThemeData theme, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.check_circle,
            size: 16,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthColumn(
    ThemeData theme,
    ClerkAuthState authState,
    ClerkService clerkService,
    Widget? noticeCard,
    Widget? errorCard,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSignInCard(theme, authState, loading: _loading),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go(Routes.feedback),
            icon: const Icon(Icons.feedback_outlined, size: 18),
            label: const Text('Send feedback without signing in'),
          ),
        ),
        if (noticeCard != null) ...[const SizedBox(height: 16), noticeCard],
        if (errorCard != null) ...[const SizedBox(height: 16), errorCard],
        const SizedBox(height: 16),
        _buildDiagnosticsCard(theme, authState, clerkService),
      ],
    );
  }

  Widget _buildCompactSupportRow(
    ThemeData theme,
    ClerkAuthState authState,
    ClerkService clerkService, {
    Widget? noticeCard,
    Widget? errorCard,
  }) {
    final hasMessages = noticeCard != null || errorCard != null;
    return Row(
      children: [
        if (hasMessages) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () =>
                  _showMessagesSheet(theme, noticeCard, errorCard),
              icon: const Icon(Icons.info_outline, size: 18),
              label: const Text('Status'),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.go(Routes.feedback),
            icon: const Icon(Icons.feedback_outlined, size: 18),
            label: const Text('Feedback'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showDiagnosticsSheet(
              theme,
              authState,
              clerkService,
            ),
            icon: const Icon(Icons.health_and_safety_outlined, size: 18),
            label: const Text('Diagnostics'),
          ),
        ),
      ],
    );
  }

  Future<void> _showMessagesSheet(
    ThemeData theme,
    Widget? noticeCard,
    Widget? errorCard,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sign-in status',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                if (noticeCard != null) noticeCard,
                if (noticeCard != null && errorCard != null)
                  const SizedBox(height: 12),
                if (errorCard != null) errorCard,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDiagnosticsCard(
    ThemeData theme,
    ClerkAuthState authState,
    ClerkService clerkService,
  ) {
    return Card(
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            'Technical diagnostics',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            'Build, env vars, and recent auth logs',
            style: theme.textTheme.bodySmall,
          ),
          trailing: TextButton.icon(
            onPressed: () => _copyDiagnostics(
              authState: authState,
              clerkService: clerkService,
            ),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy'),
          ),
          children: [
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
    );
  }

  Future<void> _showDiagnosticsSheet(
    ThemeData theme,
    ClerkAuthState authState,
    ClerkService clerkService,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Technical diagnostics',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
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
                Text(
                  'Build, env vars, and recent auth logs',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: SelectableText(
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
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AuthGlow extends StatelessWidget {
  const _AuthGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }
}

class _AuthFeaturePill extends StatelessWidget {
  const _AuthFeaturePill({
    required this.icon,
    required this.label,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.42,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 15 : 16, color: theme.colorScheme.primary),
          SizedBox(width: compact ? 6 : 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
