part of 'youtube_connect.dart';

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
                        ? 'ReplayGlowz redirects this tab to Google, then brings you back automatically after YouTube authorisation.'
                        : 'Google opens in this tab, then returns to ReplayGlowz automatically.',
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
        const SnackBar(content: Text('ReplayGlowz is syncing your playlists.')),
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
        ? 'ReplayGlowz can now refresh your playlists and imported videos. Use this card to sync again or disconnect cleanly.'
        : 'Authorise Google once to import your playlists, watch queue, and future video syncs directly in ReplayGlowz.';

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
                        : 'ReplayGlowz can see saved YouTube tokens, but the account is not marked connected yet.',
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
                        ? 'ReplayGlowz sees saved tokens but not a confirmed connected state yet.'
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
                'ReplayGlowz needs Google access once to import your playlists and keep your video library in sync.',
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
                    ? 'ReplayGlowz redirects this tab to Google, then returns you to the same screen after YouTube authorisation.'
                    : 'Google opens in this tab, then returns to ReplayGlowz automatically.',
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
