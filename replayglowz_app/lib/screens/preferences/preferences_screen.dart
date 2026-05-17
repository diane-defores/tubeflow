import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:replayglowz_app/app/build_info.dart';
import 'package:replayglowz_app/app/router.dart';
import 'package:replayglowz_app/auth/auth_state.dart';
import 'package:replayglowz_app/auth/auth_service.dart';
import 'package:replayglowz_app/auth/firebase_config.dart';
import 'package:replayglowz_app/models/models.dart';
import 'package:replayglowz_app/providers/mutations.dart';
import 'package:replayglowz_app/providers/providers.dart';
import 'package:replayglowz_app/utils/app_logger.dart';
import 'package:replayglowz_app/widgets/error_feedback.dart';
import 'package:replayglowz_app/widgets/settings/settings_rows.dart';
import 'package:replayglowz_app/widgets/youtube_connect.dart';

/// Preferences screen with grouped settings sections.
///
/// Convex queries/mutations used:
/// - `users.ensureUser` — create the Convex user/settings/subscription if needed
/// - `settings.getSettings` — load current user settings
/// - `subscriptions.getSubscription` — check subscription tier / quota
/// - `users.getCurrentUser` — fetch user profile info
/// - `settings.updateAllSettings` — persist settings changes
class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  Future<void> _persistSettings(Map<String, dynamic> patch) async {
    try {
      await updateSettings(ref, patch);
      ref.invalidate(preferencesDataProvider);
      ref.invalidate(settingsProvider);
      ref.invalidate(subscriptionProvider);
      ref.invalidate(currentUserProvider);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, error: e, prefix: 'Failed to save setting');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final preferencesAsync = ref.watch(preferencesDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Preferences')),
      body: ListView(
        children: [
          const SettingsSection(title: 'Account'),
          _AccountTile(authState: authState),
          const _DiagnosticsCard(),
          const _LogsCard(),
          const Divider(),
          ..._buildConvexSections(context, authState, preferencesAsync),
        ],
      ),
    );
  }

  List<Widget> _buildConvexSections(
    BuildContext context,
    AuthState authState,
    AsyncValue<PreferencesData?> preferencesAsync,
  ) {
    if (authState is! AuthAuthenticated) {
      return [
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Sign in to manage playback, notifications and transcript '
            'preferences.',
            textAlign: TextAlign.center,
          ),
        ),
      ];
    }

    return [
      preferencesAsync.when(
        data: (data) => data == null
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No preferences available for this account yet.',
                  textAlign: TextAlign.center,
                ),
              )
            : _buildSettingsBody(context, data),
        loading: () => _buildShimmerLoading(),
        error: (error, stack) => ErrorStateView(
          error: error,
          prefix: 'Failed to load preferences',
          onRetry: () => ref.invalidate(preferencesDataProvider),
        ),
      ),
    ];
  }

  Widget _buildShimmerLoading() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Loading preferences',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                'ReplayGlowz is fetching your settings, subscription, and profile data from Convex.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsBody(BuildContext context, PreferencesData data) {
    final settings = data.settings;
    final subscription = data.subscription;
    final user = data.user;
    final themeMode = settings.theme;
    final notifications = settings.notifications;
    final playback = settings.playback;
    final notes = settings.notes;
    final transcriptLanguage = settings.transcripts.defaultLanguage;
    final feedbackIsAdmin = ref.watch(feedbackIsAdminProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.workspace_premium),
          title: const Text('Subscription'),
          subtitle: Text(
            '${subscription.plan.name.toUpperCase()} plan'
            ' - ${subscription.status.name}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {},
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Videos: ${SubscriptionFeatures.isUnlimited(subscription.features.maxVideos) ? 'Unlimited' : subscription.features.maxVideos}'
                  '  |  Playlists: ${SubscriptionFeatures.isUnlimited(subscription.features.maxPlaylists) ? 'Unlimited' : subscription.features.maxPlaylists}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const Divider(),

        const SettingsSection(title: 'Appearance'),
        SettingsChoiceTile(
          icon: Icons.palette_outlined,
          title: 'Theme',
          value: themeMode.name,
          onTap: () => showSettingsChoiceDialog(
            context,
            title: 'Theme',
            options: const ['light', 'dark', 'system'],
            currentValue: themeMode.name,
            onSelected: (value) => _persistSettings({'theme': value}),
          ),
        ),
        SettingsChoiceTile(
          icon: Icons.language,
          title: 'Language',
          value: settings.language ?? 'en',
          onTap: () => showSettingsChoiceDialog(
            context,
            title: 'Language',
            options: const ['en', 'fr', 'es', 'de', 'pt'],
            currentValue: settings.language ?? 'en',
            onSelected: (value) => _persistSettings({'language': value}),
          ),
        ),
        const Divider(),

        const SettingsSection(title: 'Account'),
        const YoutubeConnectionSettingsCard(),
        if (user != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Connected as ${user.displayName}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        const Divider(),

        const SettingsSection(title: 'Notifications'),
        SettingsSwitchTile(
          icon: Icons.alternate_email,
          title: 'Email notifications',
          subtitle: 'Receive updates by email',
          value: notifications.email,
          onChanged: (value) => _persistSettings({
            'notifications': notifications.copyWith(email: value).toJson(),
          }),
        ),
        SettingsSwitchTile(
          icon: Icons.notifications,
          title: 'Push notifications',
          subtitle: 'Master notification toggle',
          value: notifications.push,
          onChanged: (value) => _persistSettings({
            'notifications': notifications.copyWith(push: value).toJson(),
          }),
        ),
        SettingsSwitchTile(
          icon: Icons.comment_outlined,
          title: 'New comments',
          subtitle: 'Notify about comment activity',
          value: notifications.newComments,
          onChanged: (value) => _persistSettings({
            'notifications': notifications
                .copyWith(newComments: value)
                .toJson(),
          }),
        ),
        SettingsSwitchTile(
          icon: Icons.thumb_up_alt_outlined,
          title: 'New likes',
          subtitle: 'Notify when notes get likes',
          value: notifications.newLikes,
          onChanged: (value) => _persistSettings({
            'notifications': notifications.copyWith(newLikes: value).toJson(),
          }),
        ),
        SettingsSwitchTile(
          icon: Icons.video_library_outlined,
          title: 'New video alerts',
          subtitle: 'Notify when subscribed channels upload',
          value: notifications.newVideos,
          onChanged: (value) => _persistSettings({
            'notifications': notifications.copyWith(newVideos: value).toJson(),
          }),
        ),
        SettingsChoiceTile(
          icon: Icons.schedule,
          title: 'Feed check interval',
          value: _intervalLabel(notifications.feedRefreshIntervalMinutes),
          onTap: () => showSettingsChoiceDialog(
            context,
            title: 'Feed check interval',
            options: const [
              'Off',
              'Every 30 minutes',
              'Every hour',
              'Every 2 hours',
              'Every 6 hours',
              'Daily',
            ],
            currentValue: _intervalLabel(
              notifications.feedRefreshIntervalMinutes,
            ),
            onSelected: (value) => _persistSettings({
              'notifications': notifications
                  .copyWith(
                    feedRefreshIntervalMinutes: _intervalFromLabel(value),
                  )
                  .toJson(),
            }),
          ),
        ),
        const Divider(),

        const SettingsSection(title: 'Playback'),
        SettingsSwitchTile(
          icon: Icons.play_circle,
          title: 'Autoplay',
          subtitle: 'Play next video automatically',
          value: playback.autoplay,
          onChanged: (value) => _persistSettings({
            'playback': playback.copyWith(autoplay: value).toJson(),
          }),
        ),
        SettingsChoiceTile(
          icon: Icons.hd_outlined,
          title: 'Default quality',
          value: playback.defaultQuality ?? 'auto',
          onTap: () => showSettingsChoiceDialog(
            context,
            title: 'Default quality',
            options: const ['auto', '1080p', '720p', '480p', '360p'],
            currentValue: playback.defaultQuality ?? 'auto',
            onSelected: (value) => _persistSettings({
              'playback': playback.copyWith(defaultQuality: value).toJson(),
            }),
          ),
        ),
        SettingsChoiceTile(
          icon: Icons.speed,
          title: 'Default speed',
          value: '${playback.defaultSpeed ?? 1.0}x',
          onTap: () => showSettingsChoiceDialog(
            context,
            title: 'Default speed',
            options: const ['0.5', '0.75', '1', '1.25', '1.5', '1.75', '2'],
            currentValue: '${playback.defaultSpeed ?? 1.0}'.replaceAll(
              '.0',
              '',
            ),
            onSelected: (value) => _persistSettings({
              'playback': playback
                  .copyWith(defaultSpeed: double.tryParse(value) ?? 1.0)
                  .toJson(),
            }),
          ),
        ),
        SettingsSwitchTile(
          icon: Icons.closed_caption_disabled_outlined,
          title: 'Captions enabled',
          subtitle: 'Show captions by default',
          value: playback.captionsEnabled ?? false,
          onChanged: (value) => _persistSettings({
            'playback': playback.copyWith(captionsEnabled: value).toJson(),
          }),
        ),
        const Divider(),

        const SettingsSection(title: 'Notes'),
        SettingsSwitchTile(
          icon: Icons.pause_circle,
          title: 'Auto timestamp',
          subtitle: 'Create note prompt when pausing video',
          value: notes.defaultTimestamped,
          onChanged: (value) => _persistSettings({
            'notes': notes.copyWith(defaultTimestamped: value).toJson(),
          }),
        ),
        SettingsChoiceTile(
          icon: Icons.sort,
          title: 'Sort order',
          value: (notes.sortOrder ?? NoteSortOrder.asc).name,
          onTap: () => showSettingsChoiceDialog(
            context,
            title: 'Sort order',
            options: const ['asc', 'desc'],
            currentValue: (notes.sortOrder ?? NoteSortOrder.asc).name,
            onSelected: (value) => _persistSettings({
              'notes': notes
                  .copyWith(sortOrder: NoteSortOrder.fromJson(value))
                  .toJson(),
            }),
          ),
        ),
        const Divider(),

        const SettingsSection(title: 'Transcripts'),
        SettingsChoiceTile(
          icon: Icons.translate,
          title: 'Transcript Language',
          value: transcriptLanguage ?? 'Auto-detect',
          onTap: () => showSettingsChoiceDialog(
            context,
            title: 'Transcript Language',
            options: ['Auto-detect', 'English', 'French', 'Spanish', 'German'],
            currentValue: transcriptLanguage ?? 'Auto-detect',
            onSelected: (value) => _persistSettings({
              'transcripts': {
                ...settings.transcripts.toJson(),
                'defaultLanguage': value == 'Auto-detect'
                    ? null
                    : value.toLowerCase(),
              },
            }),
          ),
        ),
        const Divider(),

        const SettingsSection(title: 'Support'),
        ListTile(
          leading: const Icon(Icons.feedback_outlined),
          title: const Text('Send feedback'),
          subtitle: const Text('Report issues or tell us what to improve'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(Routes.feedback),
        ),
        feedbackIsAdmin.when(
          data: (isAdmin) => isAdmin
              ? ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text('Feedback admin'),
                  subtitle: const Text(
                    'Review incoming text and audio feedback',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(Routes.feedbackAdmin),
                )
              : const SizedBox.shrink(),
          loading: () => const ListTile(
            leading: Icon(Icons.admin_panel_settings_outlined),
            title: Text('Checking admin access…'),
          ),
          error: (error, stackTrace) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 32),

        // App info
        Center(
          child: Text(
            'ReplayGlowz v1.0.0',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: Colors.grey),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _intervalLabel(int minutes) {
    switch (minutes) {
      case 0:
        return 'Off';
      case 30:
        return 'Every 30 minutes';
      case 60:
        return 'Every hour';
      case 120:
        return 'Every 2 hours';
      case 360:
        return 'Every 6 hours';
      case 1440:
        return 'Daily';
      default:
        return 'Every $minutes min';
    }
  }

  int _intervalFromLabel(String label) {
    switch (label) {
      case 'Off':
        return 0;
      case 'Every 30 minutes':
        return 30;
      case 'Every hour':
        return 60;
      case 'Every 2 hours':
        return 120;
      case 'Every 6 hours':
        return 360;
      case 'Daily':
        return 1440;
      default:
        return 60;
    }
  }
}

// ---------------------------------------------------------------------------
// Account tile — reads auth state directly, no Convex dependency
// ---------------------------------------------------------------------------

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.authState});

  final AuthState authState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (authState) {
      case AuthLoading():
        return const ListTile(
          leading: CircleAvatar(child: Icon(Icons.person)),
          title: Text('Checking session…'),
        );
      case AuthAuthenticated(:final user):
        return Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundImage: user.imageUrl != null
                    ? NetworkImage(user.imageUrl!)
                    : null,
                child: user.imageUrl == null ? const Icon(Icons.person) : null,
              ),
              title: Text(user.label),
              subtitle: user.email.isNotEmpty ? Text(user.email) : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Sign out'),
                  onPressed: () async {
                    await ref.read(authServiceProvider).signOut();
                    if (context.mounted) context.go(Routes.signIn);
                  },
                ),
              ),
            ),
          ],
        );
      case AuthUnauthenticated(:final error):
        return Column(
          children: [
            const ListTile(
              leading: CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text('Not signed in'),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: InlineErrorCard(
                  error: error,
                  prefix: 'Authentication error',
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('Sign in'),
                  onPressed: () => context.go(Routes.signIn),
                ),
              ),
            ),
          ],
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Diagnostics card — env vars + service status
// ---------------------------------------------------------------------------

class _DiagnosticsCard extends ConsumerWidget {
  const _DiagnosticsCard();

  Future<void> _copyDiagnostics(
    BuildContext context,
    AuthService auth,
    AuthState authState,
  ) async {
    final lines = _buildLines(auth, authState);
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Diagnostics copied.')));
  }

  List<String> _buildLines(AuthService auth, AuthState authState) {
    String authLabel;
    switch (authState) {
      case AuthLoading():
        authLabel = 'Loading';
      case AuthAuthenticated():
        authLabel = 'Authenticated';
      case AuthUnauthenticated():
        authLabel = 'Unauthenticated';
    }

    return [
      'ReplayGlowz preferences diagnostics',
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
      'Firebase Auth initialised: ${auth.isInitialised ? 'yes' : 'no'}',
      'Auth state: $authLabel',
      'Current user: ${auth.currentUser?.uid ?? 'none'}',
      '',
      'Recent logs:',
      AppLogger.instance.formatAll(),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authServiceProvider);
    final authState = ref.watch(authStateProvider);

    String authLabel;
    switch (authState) {
      case AuthLoading():
        authLabel = 'Loading';
      case AuthAuthenticated():
        authLabel = 'Authenticated';
      case AuthUnauthenticated():
        authLabel = 'Unauthenticated';
    }

    final rows = <({String key, String value, bool ok})>[
      (
        key: 'CONVEX_URL',
        value: convexUrl.isNotEmpty ? convexUrl : '(missing)',
        ok: convexUrl.isNotEmpty,
      ),
      (
        key: 'FIREBASE_PROJECT_ID',
        value: firebaseProjectId.isNotEmpty ? firebaseProjectId : '(missing)',
        ok: firebaseProjectId.isNotEmpty,
      ),
      (
        key: 'FIREBASE_APP_ID',
        value: firebaseAppId.isNotEmpty
            ? maskValue(firebaseAppId)
            : '(missing)',
        ok: firebaseAppId.isNotEmpty,
      ),
      (
        key: 'BUILD_COMMIT_SHA',
        value: buildCommitSha,
        ok: buildCommitSha != 'unknown',
      ),
      (
        key: 'BUILD_ENVIRONMENT',
        value: buildEnvironment,
        ok: buildEnvironment != 'unknown',
      ),
      (
        key: 'REPLAYGLOWZ_APP_URL',
        value: replayGlowzAppUrl.isNotEmpty ? replayGlowzAppUrl : '(missing)',
        ok: replayGlowzAppUrl.isNotEmpty,
      ),
      (
        key: 'APP_URL host match',
        value: hostMatchLabel(replayGlowzAppUrl),
        ok:
            hostMatchLabel(replayGlowzAppUrl) == 'yes' ||
            hostMatchLabel(replayGlowzAppUrl) == 'not-web',
      ),
      (
        key: 'Firebase Auth initialised',
        value: auth.isInitialised ? 'yes' : 'no',
        ok: auth.isInitialised,
      ),
      (key: 'Auth state', value: authLabel, ok: authState is AuthAuthenticated),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Diagnostics',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _copyDiagnostics(context, auth, authState),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        r.ok ? Icons.check_circle : Icons.error,
                        size: 16,
                        color: r.ok ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 160,
                        child: Text(
                          r.key,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          r.value,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
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
// Logs card — in-memory AppLogger view with Copy + Clear
// ---------------------------------------------------------------------------

class _LogsCard extends StatefulWidget {
  const _LogsCard();

  @override
  State<_LogsCard> createState() => _LogsCardState();
}

class _LogsCardState extends State<_LogsCard> {
  @override
  void initState() {
    super.initState();
    AppLogger.instance.addListener(_onLogs);
  }

  @override
  void dispose() {
    AppLogger.instance.removeListener(_onLogs);
    super.dispose();
  }

  void _onLogs() {
    if (mounted) setState(() {});
  }

  Future<void> _copyAll() async {
    await Clipboard.setData(
      ClipboardData(text: AppLogger.instance.formatAll()),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Logs copied')));
  }

  @override
  Widget build(BuildContext context) {
    final entries = AppLogger.instance.entries.reversed.toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Card(
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
                    'Logs (${entries.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Copy all',
                    onPressed: entries.isEmpty ? null : _copyAll,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    tooltip: 'Clear',
                    onPressed: entries.isEmpty
                        ? null
                        : () => AppLogger.instance.clear(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '(no logs yet)',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: Scrollbar(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: entries.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 8),
                      itemBuilder: (context, i) {
                        final e = entries[i];
                        final color = switch (e.level) {
                          LogLevel.error => Colors.red,
                          LogLevel.warning => Colors.orange,
                          LogLevel.info => null,
                        };
                        return SelectableText(
                          e.format(),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: color,
                          ),
                        );
                      },
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
