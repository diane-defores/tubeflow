import 'dart:developer' as developer;

import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tubeflow_app/app/router.dart';
import 'package:tubeflow_app/app/theme.dart';
import 'package:tubeflow_app/auth/clerk_service.dart';
import 'package:tubeflow_app/convex/convex_client.dart';
import 'package:tubeflow_app/convex/convex_provider.dart';

/// Clerk publishable key injected at build time via `--dart-define`.
const _clerkPublishableKey = String.fromEnvironment(
  'CLERK_PUBLISHABLE_KEY',
  defaultValue: '',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const convexUrl = String.fromEnvironment(
    'CONVEX_URL',
    defaultValue: 'https://your-deployment.convex.cloud',
  );
  await ConvexService.initialize(convexUrl);

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

  @override
  void initState() {
    super.initState();
    // Defer to the first frame so Riverpod providers are accessible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  void _bootstrap() {
    try {
      // 1. Eagerly read the ClerkService so it initialises and starts
      //    listening for session changes.
      final clerk = ref.read(clerkServiceProvider);

      // 2. Wire the Convex client to use Clerk tokens for auth.
      final convex = ref.read(convexServiceProvider);
      convex.setAuth(() => clerk.getConvexToken());
    } catch (e, st) {
      developer.log('Bootstrap failed', error: e, stackTrace: st);
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

    return ClerkAuth(
      config: ClerkAuthConfig(publishableKey: _clerkPublishableKey),
      child: const ClerkErrorListener(
        child: TubeFlowApp(),
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
