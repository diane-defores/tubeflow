import 'dart:developer' as developer;

import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tubeflow_app/app/router.dart';
import 'package:tubeflow_app/app/theme.dart';
import 'package:tubeflow_app/auth/clerk_service.dart';
import 'package:tubeflow_app/convex/convex_client.dart';
import 'package:tubeflow_app/convex/convex_provider.dart';
import 'package:tubeflow_app/widgets/error_feedback.dart';

/// Clerk publishable key injected at build time via `--dart-define`.
const _clerkPublishableKey = String.fromEnvironment(
  'CLERK_PUBLISHABLE_KEY',
  defaultValue: '',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const convexUrl = String.fromEnvironment('CONVEX_URL');
  if (convexUrl.isNotEmpty) {
    await ConvexService.initialize(convexUrl);
  }

  runApp(
    const ProviderScope(
      child: _AppBootstrap(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Bootstrap widget
// ---------------------------------------------------------------------------

/// Eagerly initialises Clerk and wires the Convex auth token before building
/// the main application widget.
///
/// This is a separate [ConsumerStatefulWidget] so that the [ClerkService] is
/// created (and begins restoring a persisted session) on the very first frame,
/// and the Convex client gets its token provider as soon as both services
/// exist.
class _AppBootstrap extends ConsumerStatefulWidget {
  const _AppBootstrap();

  @override
  ConsumerState<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<_AppBootstrap> {
  bool _initialised = false;
  String? _bootstrapError;

  bool get _hasConvexConfig =>
      const String.fromEnvironment('CONVEX_URL').isNotEmpty;

  bool get _hasClerkConfig => _clerkPublishableKey.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Defer to the first frame so Riverpod providers are accessible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    try {
      if (_hasConvexConfig && _hasClerkConfig) {
        final clerk = ref.read(clerkServiceProvider);
        await clerk.ready;
        final convex = ref.read(convexServiceProvider);
        await convex.setAuth(() => clerk.getConvexToken());
      }
    } catch (e, st) {
      developer.log('Bootstrap failed', error: e, stackTrace: st);
      _bootstrapError = '$e';
    }

    if (mounted) {
      setState(() => _initialised = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialised) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_bootstrapError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        home: _ConfigFallbackScreen(
          hasConvexConfig: _hasConvexConfig,
          hasClerkConfig: _hasClerkConfig,
          bootstrapError: _bootstrapError,
        ),
      );
    }

    return const TubeFlowApp();
  }
}

class _ConfigFallbackScreen extends StatelessWidget {
  const _ConfigFallbackScreen({
    required this.hasConvexConfig,
    required this.hasClerkConfig,
    this.bootstrapError,
  });

  final bool hasConvexConfig;
  final bool hasClerkConfig;
  final String? bootstrapError;

  @override
  Widget build(BuildContext context) {
    final missing = <String>[
      if (!hasConvexConfig) 'CONVEX_URL',
      if (!hasClerkConfig) 'CLERK_PUBLISHABLE_KEY',
    ];

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.settings_rounded, size: 28),
                        SizedBox(width: 12),
                        Text(
                          'TubeFlow configuration required',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      missing.isEmpty
                          ? 'The app started, but bootstrap failed.'
                          : 'This build succeeded, but the app is running in '
                              'fallback mode because required environment '
                              'variables are missing.',
                    ),
                    if (missing.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Missing variables: ${missing.join(', ')}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const SelectableText(
                      'Set these at build time with --dart-define or in Vercel '
                      'project environment variables.',
                    ),
                    if (bootstrapError != null) ...[
                      const SizedBox(height: 16),
                      SelectableText(
                        'Bootstrap error: $bootstrapError',
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => copyErrorToClipboard(
                          context,
                          bootstrapError!,
                          prefix: 'Bootstrap error',
                        ),
                        icon: const Icon(Icons.copy, size: 16),
                        label: Text(
                          Localizations.localeOf(context).languageCode == 'fr'
                              ? 'Copier'
                              : 'Copy',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Root application widget
// ---------------------------------------------------------------------------

/// Root application widget.
///
/// Wraps the entire app in [MaterialApp.router] with GoRouter navigation,
/// Riverpod state management, and light/dark/system theme support.
///
/// Auth state changes from [authStateProvider] trigger router redirects so
/// the user is automatically sent to the sign-in screen when unauthenticated
/// and back to the main app when authenticated.
class TubeFlowApp extends ConsumerWidget {
  const TubeFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'TubeFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
