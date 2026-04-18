import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:tubeflow_app/providers/providers.dart';
import 'package:tubeflow_app/utils/app_logger.dart';

/// URL that starts the YouTube OAuth flow.
///
/// The Next.js web app (separate deployment) exposes `/api/auth/youtube`.
/// Pass its origin at build time via `--dart-define=TUBEFLOW_WEB_URL=...`.
/// When unset, the CTA shows an informative SnackBar instead of a broken link.
const _youtubeConnectOrigin = String.fromEnvironment(
  'TUBEFLOW_WEB_URL',
  defaultValue: '',
);

/// True when [youtubeConnectionProvider] reports `connected: true`.
bool _isYoutubeConnected(AsyncValue<Map<String, dynamic>?> async) {
  return async.asData?.value?['connected'] == true;
}

Future<void> _launchYoutubeConnect(BuildContext context) async {
  if (_youtubeConnectOrigin.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'YouTube connection must be initiated from the web app — '
          'TUBEFLOW_WEB_URL not configured for this build.',
        ),
      ),
    );
    return;
  }

  final uri = Uri.parse('$_youtubeConnectOrigin/api/auth/youtube');
  try {
    final launched = await launchUrl(uri, webOnlyWindowName: '_self');
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $uri')),
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
                Icons.play_circle_outline_rounded,
                size: 22,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Connectez YouTube pour importer vos playlists et vidéos.',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontSize: 13,
                  ),
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
                child: const Text('Connecter'),
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
              label: const Text('Actualiser'),
            ),
    );
  }
}

class _ConnectYoutubeEmptyState extends StatelessWidget {
  const _ConnectYoutubeEmptyState({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.smart_display_rounded,
                  size: 40,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Connectez YouTube',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Importez vos playlists et abonnements pour commencer à '
                'regarder et prendre des notes.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
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
                  label: const Text('Connecter YouTube'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
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
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
