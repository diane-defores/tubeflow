import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:tubeflow_app/auth/auth_state.dart';
import 'package:tubeflow_app/auth/clerk_service.dart';

// ---------------------------------------------------------------------------
// AuthGate
// ---------------------------------------------------------------------------

/// A widget that gates access behind authentication.
///
/// Renders [child] when the user is authenticated. Otherwise, shows a polished
/// sign-in screen with Google and Apple buttons, loading indicators, error
/// handling with retry, and Terms & Privacy links.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, required this.child});

  /// The widget to display when the user is authenticated.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return switch (authState) {
      AuthAuthenticated() => child,
      AuthLoading() => const _SignInScreen(isLoading: true),
      AuthUnauthenticated(:final error) => _SignInScreen(
          isLoading: false,
          errorMessage: error,
        ),
    };
  }
}

// ---------------------------------------------------------------------------
// Sign-in screen
// ---------------------------------------------------------------------------

class _SignInScreen extends ConsumerWidget {
  const _SignInScreen({
    required this.isLoading,
    this.errorMessage,
  });

  final bool isLoading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

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

                  // --- Error banner ---
                  if (errorMessage != null) ...[
                    _ErrorBanner(message: errorMessage!),
                    const SizedBox(height: 20),
                  ],

                  // --- Loading indicator ---
                  if (isLoading) ...[
                    const _LoadingIndicator(),
                    const SizedBox(height: 32),
                  ],

                  // --- Google sign-in (primary) ---
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () => _signInWithGoogle(ref),
                      icon: const _GoogleIcon(),
                      label: const Text('Continue with Google'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        disabledBackgroundColor:
                            colorScheme.primary.withValues(alpha: 0.5),
                        disabledForegroundColor:
                            colorScheme.onPrimary.withValues(alpha: 0.7),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // --- Apple sign-in (secondary) ---
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () => _signInWithApple(ref),
                      icon: Icon(
                        Icons.apple_rounded,
                        size: 22,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      label: Text(
                        'Continue with Apple',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: colorScheme.outline,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // --- Terms & Privacy ---
                  const _TermsAndPrivacy(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _signInWithGoogle(WidgetRef ref) {
    ref.read(clerkServiceProvider).signInWithGoogle();
  }

  void _signInWithApple(WidgetRef ref) {
    ref.read(clerkServiceProvider).signInWithApple();
  }
}

// ---------------------------------------------------------------------------
// Error banner
// ---------------------------------------------------------------------------

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: colorScheme.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading indicator
// ---------------------------------------------------------------------------

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Signing you in...',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Google icon (inline SVG-like icon)
// ---------------------------------------------------------------------------

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    // Use a simple "G" text stand-in rather than bundling an SVG asset.
    // Replace with an actual Google logo asset in production.
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontWeight: FontWeight.w700,
          fontSize: 13,
          height: 1,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Terms & Privacy
// ---------------------------------------------------------------------------

class _TermsAndPrivacy extends StatelessWidget {
  const _TermsAndPrivacy();

  // Replace these with real URLs for your app.
  static const _termsUrl = 'https://tubeflow.app/terms';
  static const _privacyUrl = 'https://tubeflow.app/privacy';

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    final linkColor = Theme.of(context).colorScheme.primary;

    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        Text('By continuing you agree to our ', style: style),
        _InlineLink(
          text: 'Terms of Service',
          url: _termsUrl,
          style: style?.copyWith(
            color: linkColor,
            decoration: TextDecoration.underline,
            decorationColor: linkColor,
          ),
        ),
        Text(' and ', style: style),
        _InlineLink(
          text: 'Privacy Policy',
          url: _privacyUrl,
          style: style?.copyWith(
            color: linkColor,
            decoration: TextDecoration.underline,
            decorationColor: linkColor,
          ),
        ),
        Text('.', style: style),
      ],
    );
  }
}

class _InlineLink extends StatelessWidget {
  const _InlineLink({
    required this.text,
    required this.url,
    this.style,
  });

  final String text;
  final String url;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      ),
      child: Text(text, style: style),
    );
  }
}
