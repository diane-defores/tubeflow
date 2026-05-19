import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:replayglowz_app/app/router.dart';
import 'package:replayglowz_app/auth/auth_state.dart';
import 'package:replayglowz_app/auth/auth_service.dart';
import 'package:replayglowz_app/utils/app_logger.dart';
import 'package:replayglowz_app/widgets/error_feedback.dart';

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
                Text('ReplayGlowz', style: theme.textTheme.headlineMedium),
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
                  const SizedBox(height: 12),
                  const _AuthDebugPanel(),
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

class _AuthDebugPanel extends StatefulWidget {
  const _AuthDebugPanel();

  @override
  State<_AuthDebugPanel> createState() => _AuthDebugPanelState();
}

class _AuthDebugPanelState extends State<_AuthDebugPanel> {
  @override
  void initState() {
    super.initState();
    AppLogger.instance.addListener(_onLogsChanged);
  }

  @override
  void dispose() {
    AppLogger.instance.removeListener(_onLogsChanged);
    super.dispose();
  }

  void _onLogsChanged() {
    if (mounted) setState(() {});
  }

  String _logsText() {
    final entries = AppLogger.instance.entries
        .where((entry) => entry.source == 'AuthService')
        .toList()
        .reversed
        .take(8)
        .toList()
        .reversed;
    if (entries.isEmpty) {
      return 'No auth logs yet.';
    }
    return entries.map(_formatLogEntry).join('\n\n');
  }

  String _formatLogEntry(LogEntry entry) {
    final lines = <String>[
      '[${entry.timestamp.toIso8601String()}] '
          '${entry.level.name.toUpperCase()} ${entry.source}: ${entry.message}',
      if (entry.error != null) 'error: ${entry.error}',
      if (entry.stackTrace != null)
        'stack: ${entry.stackTrace.toString().split('\n').take(8).join('\n')}',
    ];
    return lines.join('\n');
  }

  Future<void> _copyLogs() async {
    await Clipboard.setData(ClipboardData(text: _logsText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Auth logs copied.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final logs = _logsText();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Auth diagnostics', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SelectableText(
            logs,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _copyLogs,
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy logs'),
            ),
          ),
        ],
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
