import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:tubeflow_app/app/build_info.dart';
import 'package:tubeflow_app/app/router.dart';
import 'package:tubeflow_app/app/theme.dart';
import 'package:tubeflow_app/auth/auth_service.dart';
import 'package:tubeflow_app/auth/firebase_config.dart';
import 'package:tubeflow_app/convex/convex_client.dart';
import 'package:tubeflow_app/convex/convex_provider.dart';
import 'package:tubeflow_app/utils/app_logger.dart';
import 'package:tubeflow_app/widgets/error_feedback.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (sentryDsn.isEmpty) {
    await _runApp();
    return;
  }

  await SentryFlutter.init((options) {
    options.dsn = sentryDsn;
    options.environment = sentryEnvironmentLabel();
    options.release = sentryReleaseLabel();
    options.sendDefaultPii = false;
    options.attachScreenshot = false;
    options.debug = sentryDebug;
    options.diagnosticLevel = sentryDebug
        ? SentryLevel.debug
        : SentryLevel.warning;
    if (sentryTracesSampleRate > 0) {
      options.tracesSampleRate = sentryTracesSampleRate;
    }
  }, appRunner: _runApp);
}

Future<void> _runApp() async {
  _installErrorHandlers();
  await _configureSentryScope();

  AppLogger.instance.log(
    sentryDsn.isEmpty
        ? 'Sentry disabled — SENTRY_DSN is empty'
        : 'Sentry initialised (environment=${sentryEnvironmentLabel()}, release=${sentryReleaseLabel()}, tracesSampleRate=$sentryTracesSampleRate)',
    source: 'Sentry',
    level: sentryDsn.isEmpty ? LogLevel.warning : LogLevel.info,
    reportToSentry: false,
  );

  AppLogger.instance.log(
    'main() start — CONVEX_URL=${const bool.hasEnvironment('CONVEX_URL')} '
    'FIREBASE_PROJECT_ID=${firebaseProjectId.isNotEmpty} '
    'BUILD_COMMIT_SHA=$buildCommitSha '
    'BUILD_ENVIRONMENT=$buildEnvironment',
    source: 'main',
  );

  if (convexUrl.isNotEmpty) {
    try {
      await ConvexService.initialize(convexUrl);
      AppLogger.instance.log('ConvexService initialised', source: 'main');
    } catch (e, st) {
      AppLogger.instance.log(
        'ConvexService.initialize failed',
        source: 'main',
        level: LogLevel.error,
        error: e,
        stackTrace: st,
      );
    }
  } else {
    AppLogger.instance.log(
      'CONVEX_URL empty — skipping Convex init',
      source: 'main',
      level: LogLevel.warning,
    );
  }

  runApp(const ProviderScope(child: _AppBootstrap()));
}

void _installErrorHandlers() {
  final previousFlutterError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.instance.log(
      details.summary.toString(),
      source: 'FlutterError',
      level: LogLevel.error,
      error: details.exception,
      stackTrace: details.stack,
      reportToSentry: false,
    );
    if (previousFlutterError != null) {
      previousFlutterError(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  final previousPlatformError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.instance.log(
      'Uncaught platform error',
      source: 'PlatformDispatcher',
      level: LogLevel.error,
      error: error,
      stackTrace: stack,
      reportToSentry: false,
    );
    return previousPlatformError?.call(error, stack) ?? true;
  };
}

Future<void> _configureSentryScope() async {
  if (sentryDsn.isEmpty) return;

  await Sentry.configureScope((scope) async {
    await scope.setTag('build_commit', buildCommitSha);
    await scope.setTag('build_environment', buildEnvironment);
    await scope.setTag('build_mode', buildModeLabel());
    await scope.setContexts('replayglowz_build', {
      'commit': buildCommitSha,
      'environment': buildEnvironment,
      'timestamp': buildTimestamp,
      'mode': buildModeLabel(),
      'app_url_host': hostForUrl(replayGlowzAppUrl),
      'firebase_project_id': firebaseProjectId,
      'sentry_traces_sample_rate': sentryTracesSampleRate,
    });
    if (kIsWeb) {
      await scope.setTag('current_host', Uri.base.host);
      await scope.setContexts('replayglowz_web', {
        'origin': Uri.base.origin,
        'path': Uri.base.path,
        'fragment_path': Uri.base.fragment,
      });
    }
  });
}

// ---------------------------------------------------------------------------
// Bootstrap widget
// ---------------------------------------------------------------------------

/// Eagerly initialises Firebase Auth and wires the Convex auth token before building
/// the main application widget.
///
/// This is a separate [ConsumerStatefulWidget] so that the auth service is
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

  bool get _hasConvexConfig => convexUrl.isNotEmpty;

  bool get _hasFirebaseConfig => hasFirebaseConfig;

  @override
  void initState() {
    super.initState();
    // Defer to the first frame so Riverpod providers are accessible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    AppLogger.instance.log(
      'bootstrap() start — hasConvex=$_hasConvexConfig hasFirebase=$_hasFirebaseConfig',
      source: 'bootstrap',
    );
    try {
      if (_hasConvexConfig && _hasFirebaseConfig) {
        final auth = ref.read(authServiceProvider);
        await auth.ready;
        AppLogger.instance.log(
          'Firebase Auth ready (isInitialised=${auth.isInitialised})',
          source: 'bootstrap',
        );
        final convex = ref.read(convexServiceProvider);
        await convex.setAuth(() => auth.getConvexToken());
        AppLogger.instance.log('Convex auth wired', source: 'bootstrap');
        if (auth.isAuthenticated) {
          final convexAuthReady = await auth.waitForConvexTokenReady();
          AppLogger.instance.log(
            convexAuthReady
                ? 'Convex auth ready for ${auth.currentUser?.uid ?? 'signed-in user'}'
                : 'Convex auth not fully ready yet; guarded providers will use '
                      'local fallbacks until Firebase token minting catches up',
            source: 'bootstrap',
            level: convexAuthReady ? LogLevel.info : LogLevel.warning,
          );
        }
      } else {
        AppLogger.instance.log(
          'Skipping Firebase/Convex wiring — missing env vars',
          source: 'bootstrap',
          level: LogLevel.warning,
        );
      }
    } catch (e, st) {
      AppLogger.instance.log(
        'Bootstrap failed',
        source: 'bootstrap',
        level: LogLevel.error,
        error: e,
        stackTrace: st,
      );
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
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
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
          hasFirebaseConfig: _hasFirebaseConfig,
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
    required this.hasFirebaseConfig,
    this.bootstrapError,
  });

  final bool hasConvexConfig;
  final bool hasFirebaseConfig;
  final String? bootstrapError;

  Future<void> _copyDiagnostics(BuildContext context) async {
    final lines = <String>[
      'ReplayGlowz bootstrap diagnostics',
      'Build commit: $buildCommitSha',
      'Build environment: $buildEnvironment',
      'Build timestamp: $buildTimestamp',
      'Build mode: ${buildModeLabel()}',
      'Current URL: ${kIsWeb ? Uri.base.toString() : 'not-web'}',
      'Current host: ${kIsWeb ? Uri.base.host : 'not-web'}',
      'CONVEX_URL: ${convexUrl.isNotEmpty ? convexUrl : '(missing)'}',
      'FIREBASE_PROJECT_ID: ${firebaseProjectId.isNotEmpty ? firebaseProjectId : '(missing)'}',
      'FIREBASE_APP_ID: ${firebaseAppId.isNotEmpty ? maskValue(firebaseAppId) : '(missing)'}',
      'REPLAYGLOWZ_APP_URL: ${replayGlowzAppUrl.isNotEmpty ? replayGlowzAppUrl : '(missing)'}',
      'REPLAYGLOWZ_APP_URL host match: ${hostMatchLabel(replayGlowzAppUrl)}',
      'SENTRY: ${sentryStatusLabel()}',
      'Bootstrap error: ${bootstrapError ?? 'none'}',
      '',
      'Recent logs:',
      AppLogger.instance.formatAll(),
    ];

    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bootstrap diagnostics copied.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final missing = <String>[
      if (!hasConvexConfig) 'CONVEX_URL',
      if (!hasFirebaseConfig) 'FIREBASE_*',
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
                          'ReplayGlowz configuration required',
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
                    const SizedBox(height: 16),
                    SelectableText(
                      'Build commit: $buildCommitSha\n'
                      'Build environment: $buildEnvironment\n'
                      'Build timestamp: $buildTimestamp\n'
                      'Build mode: ${buildModeLabel()}\n'
                      'Current URL: ${kIsWeb ? Uri.base.toString() : 'not-web'}\n'
                      'CONVEX_URL: ${convexUrl.isNotEmpty ? convexUrl : '(missing)'}\n'
                      'FIREBASE_PROJECT_ID: ${firebaseProjectId.isNotEmpty ? firebaseProjectId : '(missing)'}\n'
                      'FIREBASE_APP_ID: ${firebaseAppId.isNotEmpty ? maskValue(firebaseAppId) : '(missing)'}\n'
                      'REPLAYGLOWZ_APP_URL: ${replayGlowzAppUrl.isNotEmpty ? replayGlowzAppUrl : '(missing)'}\n'
                      'REPLAYGLOWZ_APP_URL host match: ${hostMatchLabel(replayGlowzAppUrl)}\n'
                      'SENTRY: ${sentryStatusLabel()}',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _copyDiagnostics(context),
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy diagnostics'),
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
      title: 'ReplayGlowz',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
