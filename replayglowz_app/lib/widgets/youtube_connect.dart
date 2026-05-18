import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:replayglowz_app/app/router.dart';
import 'package:replayglowz_app/auth/auth_service.dart';
import 'package:replayglowz_app/providers/mutations.dart';
import 'package:replayglowz_app/providers/providers.dart';
import 'package:replayglowz_app/utils/app_logger.dart';
import 'package:replayglowz_app/widgets/error_feedback.dart';

part 'youtube_connect_ui_states.dart';

const _youtubeConnectOrigin = String.fromEnvironment(
  'REPLAYGLOWZ_APP_URL',
  defaultValue: '',
);

const _youtubeConnectPath = '/api/auth/youtube';
const _youtubeConnectedParam = 'youtube_connected';
const _youtubeErrorParam = 'youtube_error';
const _youtubeStatusCheckAttempts = 5;
const _youtubeStatusCheckTimeout = Duration(seconds: 3);
const _youtubeStatusCheckDelay = Duration(milliseconds: 700);

/// True when [youtubeConnectionProvider] reports `connected: true`.
bool _isYoutubeConnected(AsyncValue<Map<String, dynamic>?> async) {
  return _hasYoutubeAccess(async.asData?.value);
}

bool _hasYoutubeAccess(Map<String, dynamic>? status) {
  if (status == null) return false;
  return status['connected'] == true || status['hasTokens'] == true;
}

String _formatYoutubeDiagnostics(Map<String, dynamic>? status) {
  final logs = AppLogger.instance.entries
      .where(
        (entry) =>
            entry.source == 'YoutubeConnect' || entry.source == 'ConvexService',
      )
      .toList();

  final lines = <String>[
    'ReplayGlowz YouTube diagnostics',
    'Current URL: ${kIsWeb ? Uri.base.toString() : 'not-web'}',
    'Current host: ${kIsWeb ? Uri.base.host : 'not-web'}',
    'Current path: ${kIsWeb ? Uri.base.path : 'not-web'}',
    'Current fragment: ${kIsWeb ? Uri.base.fragment : 'not-web'}',
    'OAuth return_to: ${_currentYoutubeReturnTo()}',
    'YouTube connected: ${status?['connected'] == true ? 'yes' : 'no'}',
    'YouTube hasTokens: ${status?['hasTokens'] == true ? 'yes' : 'no'}',
    'YouTube channelId: ${status?['channelId'] ?? 'unknown'}',
    'YouTube channelTitle: ${status?['channelTitle'] ?? 'unknown'}',
    'YouTube lastSyncAt: ${status?['lastSyncAt'] ?? 'unknown'}',
    '',
    'Recent YouTube logs:',
    if (logs.isEmpty)
      '(no YoutubeConnect / ConvexService logs)'
    else
      ...logs.map((entry) => entry.format()),
  ];

  return lines.join('\n');
}

String _resolveYoutubeOrigin() {
  if (kIsWeb) {
    final origin = Uri.base.origin;
    if (origin.isNotEmpty) return origin;
  }
  return _youtubeConnectOrigin;
}

Uri? _fragmentUri(Uri uri) {
  final fragment = uri.fragment;
  if (fragment.isEmpty) return null;
  final normalized = fragment.startsWith('/') ? fragment : '/$fragment';
  return Uri.parse(normalized);
}

Map<String, String> _youtubeFlowParams(Uri uri) {
  final params = <String, String>{...uri.queryParameters};
  final fragment = _fragmentUri(uri);
  if (fragment != null) {
    params.addAll(fragment.queryParameters);
  }
  return params;
}

bool _hasYoutubeFlowParams(Uri uri) {
  final params = _youtubeFlowParams(uri);
  return params.containsKey(_youtubeConnectedParam) ||
      params.containsKey(_youtubeErrorParam);
}

String _normaliseReturnTo(String? route) {
  if (route == null || route.isEmpty) return '/#/playlists';
  if (route.startsWith('/#/')) return route;
  if (route.startsWith('#/')) return '/$route';
  if (route.startsWith('/')) return '/#$route';
  return '/#/$route';
}

String _currentYoutubeReturnTo({String? preferredRoute}) {
  if (preferredRoute != null && preferredRoute.isNotEmpty) {
    return _normaliseReturnTo(preferredRoute);
  }
  if (!kIsWeb) return '/#/playlists';
  final fragment = Uri.base.fragment;
  if (fragment.isEmpty) return '/#/playlists';
  return _normaliseReturnTo(fragment);
}

String _currentRouterRoute({String? preferredRoute}) {
  if (preferredRoute != null && preferredRoute.isNotEmpty) {
    return preferredRoute.startsWith('/') ? preferredRoute : '/$preferredRoute';
  }
  if (!kIsWeb) return Routes.playlists;
  final fragment = _fragmentUri(Uri.base);
  if (fragment == null) return Routes.playlists;
  return Uri(
    path: fragment.path.isEmpty ? Routes.playlists : fragment.path,
    queryParameters: fragment.queryParameters.isEmpty
        ? null
        : fragment.queryParameters,
  ).toString();
}

String _cleanYoutubeFlowRoute(Uri uri) {
  final fragment = _fragmentUri(uri);
  if (fragment == null) return Routes.playlists;

  final remaining = Map<String, String>.from(fragment.queryParameters)
    ..remove(_youtubeConnectedParam)
    ..remove(_youtubeErrorParam);

  final path = fragment.path.isEmpty ? Routes.playlists : fragment.path;
  final cleaned = Uri(
    path: path,
    queryParameters: remaining.isEmpty ? null : remaining,
  );
  return cleaned.toString();
}

ProviderContainer _providerContainer(BuildContext context) {
  return ProviderScope.containerOf(context, listen: false);
}

void _invalidateYoutubeData(ProviderContainer container) {
  container.invalidate(youtubeConnectionProvider);
  container.invalidate(currentUserProvider);
  container.invalidate(preferencesDataProvider);
  container.invalidate(playlistsProvider);
  container.invalidate(videosProvider(const VideosArgs()));
}

Future<bool> _waitForYoutubeConnectionStatus(
  ProviderContainer container,
) async {
  for (var attempt = 0; attempt < _youtubeStatusCheckAttempts; attempt++) {
    _invalidateYoutubeData(container);
    try {
      final status = await container
          .read(youtubeConnectionProvider.future)
          .timeout(_youtubeStatusCheckTimeout);
      if (_hasYoutubeAccess(status)) {
        return true;
      }
    } catch (_) {
      // Retry below.
    }

    if (attempt < _youtubeStatusCheckAttempts - 1) {
      await Future<void>.delayed(_youtubeStatusCheckDelay);
    }
  }
  return false;
}

Future<void> _launchYoutubeConnect(
  BuildContext context, {
  String? returnTo,
}) async {
  final origin = _resolveYoutubeOrigin();
  if (origin.isEmpty) {
    showErrorSnackBar(
      context,
      error:
          'ReplayGlowz could not determine the YouTube OAuth origin for this build.',
      prefix: 'YouTube connect unavailable',
    );
    return;
  }

  try {
    final container = _providerContainer(context);
    final auth = container.read(authServiceProvider);
    final firebaseIdToken = await auth.getConvexToken(forceRefresh: true);
    if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
      if (!context.mounted) return;
      final routeAfterSignIn = _currentRouterRoute(preferredRoute: returnTo);
      AppLogger.instance.log(
        'Cannot start YouTube OAuth because Firebase Auth has no active token; routing to sign-in',
        source: 'YoutubeConnect',
        level: LogLevel.warning,
      );
      context.go(
        Uri(
          path: Routes.signIn,
          queryParameters: {'tf_redirect': routeAfterSignIn},
        ).toString(),
      );
      return;
    }

    final target = Uri.parse(origin)
        .resolve(_youtubeConnectPath)
        .replace(
          queryParameters: {
            'return_to': _currentYoutubeReturnTo(preferredRoute: returnTo),
          },
        );

    final response = await http.get(
      target,
      headers: {'Authorization': 'Bearer $firebaseIdToken'},
    );
    if (response.statusCode != 200) {
      throw StateError(
        'YouTube OAuth start failed (${response.statusCode}): ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final authUrl = body['authUrl'] as String?;
    if (authUrl == null || authUrl.isEmpty) {
      throw StateError('YouTube OAuth start returned no authUrl.');
    }

    AppLogger.instance.log(
      'Redirecting to YouTube OAuth',
      source: 'YoutubeConnect',
    );

    final launched = await launchUrl(
      Uri.parse(authUrl),
      webOnlyWindowName: '_self',
    );
    if (!launched && context.mounted) {
      showErrorSnackBar(
        context,
        error: 'Could not open $target',
        prefix: 'YouTube connect failed',
      );
    }
  } catch (e, st) {
    AppLogger.instance.log(
      'launchYoutubeConnect failed',
      source: 'YoutubeConnect',
      level: LogLevel.error,
      error: e,
      stackTrace: st,
    );
    if (!context.mounted) return;
    showErrorSnackBar(context, error: e, prefix: 'YouTube connect failed');
  }
}

Future<void> startYoutubeConnectFlow(BuildContext context, {String? returnTo}) {
  return _launchYoutubeConnect(context, returnTo: returnTo);
}

// ---------------------------------------------------------------------------
// OAuth feedback banner
// ---------------------------------------------------------------------------

/// Feedback banner shown after the YouTube OAuth callback returns to the app.
///
/// It consumes `youtube_connected` / `youtube_error` from the hash route,
/// refreshes Convex-backed providers, and kicks off an initial playlist sync
/// when the connection succeeds.
class YoutubeOAuthFeedbackBanner extends ConsumerStatefulWidget {
  const YoutubeOAuthFeedbackBanner({super.key});

  @override
  ConsumerState<YoutubeOAuthFeedbackBanner> createState() =>
      _YoutubeOAuthFeedbackBannerState();
}

class _YoutubeOAuthFeedbackBannerState
    extends ConsumerState<YoutubeOAuthFeedbackBanner> {
  bool _started = false;
  bool _dismissed = false;
  bool _syncing = false;
  bool _syncComplete = false;
  bool _connectionConfirmed = false;
  Object? _syncError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startHandlingIfNeeded();
  }

  void _startHandlingIfNeeded() {
    if (_started || _dismissed || !_hasYoutubeFlowParams(Uri.base)) return;

    final params = _youtubeFlowParams(Uri.base);
    if (params[_youtubeConnectedParam] != 'true') {
      _started = true;
      final error = params[_youtubeErrorParam];
      if (error != null && error.isNotEmpty) {
        AppLogger.instance.log(
          'Handling failed YouTube OAuth redirect return: $error',
          source: 'YoutubeConnect',
          level: LogLevel.warning,
        );
      }
      return;
    }

    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runPostConnectSync();
    });
  }

  Future<void> _runPostConnectSync() async {
    if (!mounted) return;
    final container = _providerContainer(context);

    setState(() {
      _syncing = true;
      _syncComplete = false;
      _connectionConfirmed = false;
      _syncError = null;
    });

    AppLogger.instance.log(
      'Handling successful YouTube OAuth redirect return',
      source: 'YoutubeConnect',
    );

    try {
      final connected = await _waitForYoutubeConnectionStatus(container);
      if (!connected) {
        AppLogger.instance.log(
          'YouTube OAuth redirect returned success, but Convex status is still propagating after retries',
          source: 'YoutubeConnect',
          level: LogLevel.warning,
        );
      }

      await syncAllPlaylistsWithContainer(container);
      _invalidateYoutubeData(container);

      if (!mounted) return;
      setState(() {
        _syncComplete = true;
        _connectionConfirmed = connected;
      });
    } catch (e, st) {
      AppLogger.instance.log(
        'Initial post-connect YouTube sync failed',
        source: 'YoutubeConnect',
        level: LogLevel.warning,
        error: e,
        stackTrace: st,
      );

      if (!mounted) return;
      setState(() {
        _syncError = e;
      });
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
        });
      }
    }
  }

  void _dismissBanner() {
    setState(() {
      _dismissed = true;
    });

    final cleanedRoute = _cleanYoutubeFlowRoute(Uri.base);
    if (!mounted) return;
    context.go(cleanedRoute);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final params = _youtubeFlowParams(Uri.base);
    final isConnectedReturn = params[_youtubeConnectedParam] == 'true';
    final oauthError = params[_youtubeErrorParam];

    if (!isConnectedReturn && (oauthError == null || oauthError.isEmpty)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isError = oauthError != null && oauthError.isNotEmpty;
    final hasConnectionDelay =
        !isError &&
        _syncError == null &&
        _syncComplete &&
        !_connectionConfirmed;
    final hasSyncIssue = !isError && (_syncError != null || hasConnectionDelay);

    final title = isError
        ? 'YouTube connection failed'
        : hasSyncIssue
        ? 'YouTube connected, but setup needs attention'
        : 'YouTube connected';

    final description = isError
        ? oauthError
        : _syncError != null
        ? 'ReplayGlowz finished server-side authorisation, but the first refresh did not complete. You can retry from here or from Playlists.'
        : hasConnectionDelay
        ? 'Google authorisation completed, but ReplayGlowz still cannot confirm the saved connection in Convex. Retry sync in a moment or from Preferences.'
        : _syncing
        ? 'ReplayGlowz is confirming the server-completed YouTube connection and starting your first playlist sync.'
        : _syncComplete
        ? 'Your YouTube account is linked. ReplayGlowz has started refreshing your playlists.'
        : 'Your YouTube account is linked. ReplayGlowz is ready to import your playlists.';

    final surfaceColor = isError
        ? colorScheme.errorContainer
        : hasSyncIssue
        ? colorScheme.tertiaryContainer
        : colorScheme.primaryContainer;
    final foregroundColor = isError
        ? colorScheme.onErrorContainer
        : hasSyncIssue
        ? colorScheme.onTertiaryContainer
        : colorScheme.onPrimaryContainer;

    return Material(
      color: surfaceColor,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isError
                        ? Icons.error_outline_rounded
                        : hasSyncIssue
                        ? Icons.sync_problem_rounded
                        : Icons.check_circle_outline_rounded,
                    color: foregroundColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: foregroundColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: foregroundColor.withValues(alpha: 0.88),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _dismissBanner,
                    icon: Icon(Icons.close_rounded, color: foregroundColor),
                    tooltip: 'Dismiss',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (_syncing)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: foregroundColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Syncing playlists',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: foregroundColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  FilledButton.tonalIcon(
                    onPressed: () => context.go(Routes.playlists),
                    icon: const Icon(Icons.queue_music_rounded),
                    label: const Text('Open playlists'),
                  ),
                  if (isError)
                    OutlinedButton.icon(
                      onPressed: () => _launchYoutubeConnect(context),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry connection'),
                    ),
                  if (hasSyncIssue)
                    OutlinedButton.icon(
                      onPressed: _syncing ? null : _runPostConnectSync,
                      icon: const Icon(Icons.sync_rounded),
                      label: const Text('Retry sync'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Persistent banner (used in AppShell)
// ---------------------------------------------------------------------------

/// Slim banner shown above navigation when the user is signed in but
/// has not yet connected YouTube. Hides itself when already connected or when
/// the connection status is still loading.
class YoutubeConnectBanner extends ConsumerWidget {
  const YoutubeConnectBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(youtubeConnectionProvider);

    if (async.asData == null) return const SizedBox.shrink();
    if (_isYoutubeConnected(async)) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.primaryContainer,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.smart_display_rounded,
                size: 22,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connect YouTube to unlock your library',
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ReplayGlowz will import your playlists and refresh them after you return from Google.',
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.82,
                        ),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _launchYoutubeConnect(context),
                child: const Text('Connect'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
