import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:tubeflow_app/app/router.dart';
import 'package:tubeflow_app/auth/clerk_web_bridge.dart';
import 'package:tubeflow_app/providers/mutations.dart';
import 'package:tubeflow_app/providers/providers.dart';
import 'package:tubeflow_app/utils/app_logger.dart';
import 'package:tubeflow_app/widgets/error_feedback.dart';

/// Legacy build-time origin fallback kept for compatibility with older
/// deployments. On the web we prefer the current browser origin, because the
/// Vercel YouTube OAuth functions now live alongside the Flutter bundle.
const _legacyYoutubeConnectOrigin = String.fromEnvironment(
  'TUBEFLOW_WEB_URL',
  defaultValue: '',
);

const _youtubeConnectOrigin = String.fromEnvironment(
  'TUBEFLOW_APP_URL',
  defaultValue: _legacyYoutubeConnectOrigin,
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
    'TubeFlow YouTube diagnostics',
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
          'TubeFlow could not determine the YouTube OAuth origin for this build.',
      prefix: 'YouTube connect unavailable',
    );
    return;
  }

  try {
    if (kIsWeb) {
      final prepared = await clerkWebPrepareSessionCookie();
      if (!prepared) {
        if (!context.mounted) return;
        showErrorSnackBar(
          context,
          error:
              'TubeFlow could not prepare your Clerk session for YouTube. Sign in again, then retry.',
          prefix: 'YouTube connect failed',
        );
        return;
      }
    }

    final target = Uri.parse(origin)
        .resolve(_youtubeConnectPath)
        .replace(
          queryParameters: {
            'return_to': _currentYoutubeReturnTo(preferredRoute: returnTo),
          },
        );

    AppLogger.instance.log(
      'Redirecting to YouTube OAuth: $target',
      source: 'YoutubeConnect',
    );

    final launched = await launchUrl(target, webOnlyWindowName: '_self');
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

class YoutubeConnectionLoadingState extends StatelessWidget {
  const YoutubeConnectionLoadingState({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(
                        alpha: 0.82,
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class YoutubeConnectRequiredState extends ConsumerWidget {
  const YoutubeConnectRequiredState({
    super.key,
    required this.title,
    required this.description,
    this.returnTo,
    this.ctaLabel = 'Connect YouTube',
  });

  final String title;
  final String description;
  final String? returnTo;
  final String ctaLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.smart_display_rounded,
                      size: 40,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () =>
                          startYoutubeConnectFlow(context, returnTo: returnTo),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(ctaLabel),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    kIsWeb
                        ? 'TubeFlow redirects this tab to Google, then brings you back automatically after YouTube authorisation.'
                        : 'Google opens in this tab, then returns to TubeFlow automatically.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(
                        alpha: 0.74,
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ),
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
        ? 'TubeFlow finished server-side authorisation, but the first refresh did not complete. You can retry from here or from Playlists.'
        : hasConnectionDelay
        ? 'Google authorisation completed, but TubeFlow still cannot confirm the saved connection in Convex. Retry sync in a moment or from Preferences.'
        : _syncing
        ? 'TubeFlow is confirming the server-completed YouTube connection and starting your first playlist sync.'
        : _syncComplete
        ? 'Your YouTube account is linked. TubeFlow has started refreshing your playlists.'
        : 'Your YouTube account is linked. TubeFlow is ready to import your playlists.';

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

/// Slim banner shown above navigation when the user is signed into Clerk but
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
                      'TubeFlow will import your playlists and refresh them after you return from Google.',
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

// ---------------------------------------------------------------------------
// Preferences management card
// ---------------------------------------------------------------------------

class YoutubeConnectionSettingsCard extends ConsumerStatefulWidget {
  const YoutubeConnectionSettingsCard({
    super.key,
    this.returnTo = Routes.preferences,
  });

  final String returnTo;

  @override
  ConsumerState<YoutubeConnectionSettingsCard> createState() =>
      _YoutubeConnectionSettingsCardState();
}

class _YoutubeConnectionSettingsCardState
    extends ConsumerState<YoutubeConnectionSettingsCard> {
  bool _busy = false;
  Object? _inlineError;

  Future<void> _copyDiagnostics(Map<String, dynamic>? status) async {
    await Clipboard.setData(
      ClipboardData(text: _formatYoutubeDiagnostics(status)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('YouTube diagnostics copied.')),
    );
  }

  Future<void> _runAction(Future<void> Function() action) async {
    final container = _providerContainer(context);
    setState(() {
      _busy = true;
      _inlineError = null;
    });

    try {
      await action();
      _invalidateYoutubeData(container);
      if (!mounted) return;
    } catch (e, st) {
      AppLogger.instance.log(
        'YouTube settings action failed',
        source: 'YoutubeConnect',
        level: LogLevel.warning,
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      setState(() {
        _inlineError = e;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _connect() async {
    await _launchYoutubeConnect(context, returnTo: widget.returnTo);
  }

  Future<void> _disconnect() async {
    await _runAction(() async {
      await disconnectYoutube(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('YouTube disconnected.')));
    });
  }

  Future<void> _syncNow() async {
    await _runAction(() async {
      await syncAllPlaylists(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('TubeFlow is syncing your playlists.')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusAsync = ref.watch(youtubeConnectionProvider);

    final status = statusAsync.asData?.value;
    final connected = status?['connected'] == true;
    final hasTokens = status?['hasTokens'] == true;
    final diagnosticsText = _formatYoutubeDiagnostics(status);

    final accentColor = connected ? colorScheme.primary : Colors.red.shade600;
    final icon = connected
        ? Icons.check_circle_rounded
        : Icons.smart_display_rounded;
    final title = connected ? 'YouTube connected' : 'Connect your YouTube';
    final description = connected
        ? 'TubeFlow can now refresh your playlists and imported videos. Use this card to sync again or disconnect cleanly.'
        : 'Authorise Google once to import your playlists, watch queue, and future video syncs directly in TubeFlow.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: accentColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withValues(
                              alpha: 0.82,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (statusAsync.isLoading && status == null)
                const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('Checking YouTube connection...'),
                  ],
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (!connected)
                      FilledButton.icon(
                        onPressed: _busy ? null : _connect,
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.open_in_new_rounded),
                        label: const Text('Connect YouTube'),
                      ),
                    if (connected) ...[
                      FilledButton.icon(
                        onPressed: _busy ? null : _syncNow,
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.sync_rounded),
                        label: const Text('Sync now'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => context.go(Routes.playlists),
                        icon: const Icon(Icons.queue_music_rounded),
                        label: const Text('Open playlists'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _disconnect,
                        icon: const Icon(Icons.link_off_rounded),
                        label: const Text('Disconnect'),
                      ),
                    ],
                  ],
                ),
              if (connected || hasTokens) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    connected
                        ? 'Google authorisation is active for this account.'
                        : 'TubeFlow can see saved YouTube tokens, but the account is not marked connected yet.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
              if (_inlineError != null) ...[
                const SizedBox(height: 12),
                InlineErrorCard(
                  error: _inlineError!,
                  prefix: 'YouTube action failed',
                ),
              ],
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  leading: const Icon(Icons.bug_report_outlined, size: 20),
                  title: const Text('YouTube diagnostics'),
                  subtitle: Text(
                    connected
                        ? 'Connection confirmed. Copy recent sync logs if something still looks wrong.'
                        : hasTokens
                        ? 'TubeFlow sees saved tokens but not a confirmed connected state yet.'
                        : 'Copy this if YouTube connect stalls or comes back incomplete.',
                    style: theme.textTheme.bodySmall,
                  ),
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: SelectableText(
                        diagnosticsText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => _copyDiagnostics(status),
                        icon: const Icon(Icons.copy_all_rounded),
                        label: const Text('Copy diagnostics'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state (used in Videos / Browse / Playlists)
// ---------------------------------------------------------------------------

/// Centered empty state that branches on whether YouTube is connected.
///
/// - Not connected → "Connect YouTube" CTA.
/// - Connected but list empty → [fallbackTitle] / [fallbackDescription] with
///   an optional [onRefresh] action.
class YoutubeAwareEmptyState extends ConsumerWidget {
  const YoutubeAwareEmptyState({
    super.key,
    required this.fallbackIcon,
    required this.fallbackTitle,
    required this.fallbackDescription,
    this.onRefresh,
  });

  final IconData fallbackIcon;
  final String fallbackTitle;
  final String fallbackDescription;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(youtubeConnectionProvider);
    final connected = _isYoutubeConnected(async);

    if (!connected) {
      return _ConnectYoutubeEmptyState(
        loading: async.isLoading && async.asData == null,
      );
    }

    return _SimpleEmptyState(
      icon: fallbackIcon,
      title: fallbackTitle,
      description: fallbackDescription,
      action: onRefresh == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
    );
  }
}

class _ConnectYoutubeEmptyState extends ConsumerWidget {
  const _ConnectYoutubeEmptyState({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.smart_display_rounded,
                  size: 42,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Connect YouTube before you start',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'TubeFlow needs Google access once to import your playlists and keep your video library in sync.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: loading
                      ? null
                      : () => _launchYoutubeConnect(context),
                  icon: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(
                    loading ? 'Checking status...' : 'Connect YouTube',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                kIsWeb
                    ? 'TubeFlow redirects this tab to Google, then returns you to the same screen after YouTube authorisation.'
                    : 'Google opens in this tab, then returns to TubeFlow automatically.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(
                    alpha: 0.74,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimpleEmptyState extends StatelessWidget {
  const _SimpleEmptyState({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
