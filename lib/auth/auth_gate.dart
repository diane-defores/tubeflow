import 'dart:async';

import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:tubeflow_app/app/build_info.dart';
import 'package:tubeflow_app/app/router.dart';
import 'package:tubeflow_app/auth/auth_state.dart';
import 'package:tubeflow_app/auth/clerk_service.dart';
import 'package:tubeflow_app/auth/clerk_web_bridge.dart';
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

enum _EmailAuthMode { signIn, signUp }

class _SignInScreenState extends ConsumerState<_SignInScreen>
    with WidgetsBindingObserver {
  static const _pendingHostedSignInKey = 'pending_hosted_sign_in';
  static const _hostedSignInPollAttempts = 6;
  static const _clerkSyncedParam = '__clerk_synced';

  bool _loading = false;
  String? _error;
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
  Timer? _hostedRefreshTimer;
  bool _hostedResumeStarted = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resumeHostedSignInIfNeeded();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hostedRefreshTimer?.cancel();
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
    if (state == AppLifecycleState.resumed) {
      _resumeHostedSignInIfNeeded();
    }
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
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
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
        setState(() => _error = '$e');
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
      });
      return;
    }

    if (password != passwordConfirmation) {
      setState(() {
        _error = 'Passwords do not match.';
      });
      return;
    }

    if (!_supportsDirectEmailSignUp(authState)) {
      setState(() {
        _error =
            'This Clerk setup does not support direct email code sign-up here. Use the secure account portal instead.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
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
        setState(() => _error = '$e');
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
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
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

      if (mounted && authState.signUp?.unverified(clerk.Field.emailAddress) != true) {
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
        setState(() => _error = '$e');
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
        'Google fallback on web is routed to hosted Clerk sign-in because clerk_flutter uses the native sign-in endpoint for OAuth.',
        source: 'SignInScreen',
      );
      await _openHostedSignIn();
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
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
        setState(() => _error = '$e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openHostedSignIn() async {
    final hostedUrl = clerkHostedSignInUrl();
    if (hostedUrl.isEmpty) {
      setState(() {
        _error = 'Clerk hosted sign-in URL is missing for this build.';
      });
      return;
    }

    final redirectTarget = kIsWeb
        ? Uri.base
              .replace(
                queryParameters: {
                  ...Uri.base.queryParameters,
                  _clerkSyncedParam: 'false',
                },
              )
              .toString()
        : tubeFlowAppUrl;
    final bridgeUrl = kIsWeb
        ? await clerkWebBuildSignInUrl(redirectTarget)
        : null;
    final uri = Uri.parse(
      bridgeUrl ??
          Uri.parse(hostedUrl)
              .replace(queryParameters: {'redirect_url': redirectTarget})
              .toString(),
    );

    try {
      await _setPendingHostedSignIn(true);
      AppLogger.instance.log(
        'Opening hosted Clerk sign-in: $uri (redirect_url=$redirectTarget)',
        source: 'SignInScreen',
      );
      final launched = await launchUrl(uri, webOnlyWindowName: '_self');
      if (!launched && mounted) {
        setState(() {
          _error = 'Could not open hosted sign-in page.';
        });
      }
    } catch (e) {
      AppLogger.instance.log(
        'Opening hosted Clerk sign-in failed',
        source: 'SignInScreen',
        level: LogLevel.error,
        error: e,
      );
      if (mounted) {
        setState(() => _error = '$e');
      }
    }
  }

  Future<void> _resumeHostedSignInIfNeeded() async {
    if (!kIsWeb) return;
    if (_hostedResumeStarted) return;

    final pending = await _isPendingHostedSignIn();
    if (!pending || !mounted) return;

    _hostedResumeStarted = true;
    await _setPendingHostedSignIn(false);

    AppLogger.instance.log(
      'Detected pending hosted sign-in return; polling Clerk client state',
      source: 'SignInScreen',
      level: LogLevel.warning,
    );

    _hostedRefreshTimer?.cancel();
    setState(() {
      _loading = true;
      _error = null;
    });

    var attempts = 0;
    _hostedRefreshTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      attempts += 1;
      final resolved = await _attemptHostedSignInResume();
      if (resolved) {
        timer.cancel();
        _hostedRefreshTimer = null;
        return;
      }

      if (attempts >= _hostedSignInPollAttempts) {
        timer.cancel();
        _hostedRefreshTimer = null;
        if (mounted) {
          setState(() {
            _loading = false;
            _error =
                'Google sign-in completed on Clerk, but TubeFlow could not see the session after returning. Retry once, then share diagnostics if it persists.';
          });
        }
        AppLogger.instance.log(
          'Hosted sign-in return did not produce an active Clerk session after polling',
          source: 'SignInScreen',
          level: LogLevel.error,
        );
      }
    });
  }

  Future<bool> _attemptHostedSignInResume() async {
    if (!mounted) return false;

    final authState = ClerkAuth.of(context);
    try {
      if (kIsWeb) {
        final signedIn = await clerkWebIsSignedIn();
        AppLogger.instance.log(
          'Hosted sign-in poll result via Clerk JS bridge: isSignedIn=$signedIn',
          source: 'SignInScreen',
        );

        if (!signedIn) {
          return false;
        }

        final clerkService = ref.read(clerkServiceProvider);
        await clerkService.ready;
        await _setPendingHostedSignIn(false);
        if (mounted) {
          setState(() {
            _loading = false;
            _error = null;
          });
          context.go(Routes.videos);
        }
        return true;
      }

      await authState.refreshClient();
      if (authState.env.isEmpty) {
        await authState.refreshEnvironment();
      }

      final signedIn = authState.isSignedIn;
      AppLogger.instance.log(
        'Hosted sign-in poll result: isSignedIn=$signedIn envEmpty=${authState.env.isEmpty} clientEmpty=${authState.client.isEmpty}',
        source: 'SignInScreen',
      );

      if (!signedIn) {
        return false;
      }

      await _setPendingHostedSignIn(false);
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
        });
        context.go(Routes.videos);
      }
      return true;
    } catch (e) {
      AppLogger.instance.log(
        'Hosted sign-in poll failed',
        source: 'SignInScreen',
        level: LogLevel.error,
        error: e,
      );
      return false;
    }
  }

  Future<bool> _isPendingHostedSignIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pendingHostedSignInKey) ?? false;
  }

  Future<void> _setPendingHostedSignIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingHostedSignInKey, value);
  }

  Widget _buildSignInCard(
    ThemeData theme,
    ClerkAuthState authState, {
    required bool loading,
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
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
            const SizedBox(height: 16),
            if (hasPassword) ...[
              SegmentedButton<_EmailAuthMode>(
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
              const SizedBox(height: 16),
            ],
            Text(
              envEmpty
                  ? (isSignUpMode ? 'Fallback sign-up' : 'Fallback sign-in')
                  : (isSignUpMode ? 'Create account' : 'Sign in'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (loading) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
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
                    const SizedBox(height: 12),
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
                      const SizedBox(height: 12),
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: loading
                      ? null
                      : isSignUpMode
                      ? _signUpWithEmailPassword
                      : _signInWithEmailPassword,
                  child: Text(
                    isSignUpMode ? 'Create account with email' : 'Sign in with email',
                  ),
                ),
              ),
              if (isSignUpMode && _awaitingEmailCodeVerification) ...[
                const SizedBox(height: 12),
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
                        const SizedBox(height: 12),
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
                        const SizedBox(height: 12),
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
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: theme.colorScheme.outline.withValues(alpha: 0.7),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: theme.colorScheme.outline.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ] else
                const SizedBox(height: 12),
            ],
            if (hasGoogle)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: loading ? null : _continueWithGoogleFallback,
                  icon: const Icon(Icons.login),
                  label: Text(
                    kIsWeb
                        ? 'Continue with Google'
                        : 'Continue with Google',
                  ),
                ),
              ),
            if (hasGoogle && kIsWeb) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.45),
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
                  _buildSignInCard(theme, authState, loading: _loading),

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
