import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import 'package:tubeflow_app/app/router.dart';
import 'package:tubeflow_app/auth/auth_state.dart';
import 'package:tubeflow_app/auth/clerk_service.dart';
import 'package:tubeflow_app/models/models.dart';
import 'package:tubeflow_app/providers/mutations.dart';
import 'package:tubeflow_app/providers/providers.dart';
import 'package:tubeflow_app/utils/app_logger.dart';
import 'package:tubeflow_app/widgets/error_feedback.dart';

const _legacyClerkPublishableKey = String.fromEnvironment(
  'NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY',
  defaultValue: '',
);
const _clerkPublishableKey = String.fromEnvironment(
  'CLERK_PUBLISHABLE_KEY',
  defaultValue: _legacyClerkPublishableKey,
);
const _convexUrl = String.fromEnvironment('CONVEX_URL', defaultValue: '');

/// Preferences screen with grouped settings sections.
///
/// Convex queries/mutations used:
/// - `settings.getSettings` — load current user settings
/// - `settings.updateSettings` — persist setting changes
/// - `subscriptions.getSubscription` — check subscription tier / quota
/// - `users.getUser` — fetch user profile info
class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  /// Persist a partial settings update to Convex.
  Future<void> _updateSettings(Map<String, dynamic> patch) async {
    try {
      await updateSettings(ref, patch);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, error: e, prefix: 'Failed to save setting');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final subscriptionAsync = ref.watch(subscriptionProvider);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preferences'),
      ),
      body: ListView(
        children: [
          _buildSectionHeader(context, 'Account'),
          _AccountTile(authState: authState),
          const _DiagnosticsCard(),
          const _LogsCard(),
          const Divider(),
          ..._buildConvexSections(
            context,
            authState,
            settingsAsync,
            subscriptionAsync,
            userAsync,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildConvexSections(
    BuildContext context,
    AuthState authState,
    AsyncValue<UserSettings?> settingsAsync,
    AsyncValue<UserSubscription?> subscriptionAsync,
    AsyncValue<TubeFlowUser?> userAsync,
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
      settingsAsync.when(
        data: (settings) => _buildSettingsBody(
          context,
          settings,
          subscriptionAsync,
          userAsync,
        ),
        loading: () => _buildShimmerLoading(),
        error: (error, stack) => ErrorStateView(
          error: error,
          prefix: 'Failed to load settings',
          onRetry: () => ref.invalidate(settingsProvider),
        ),
      ),
    ];
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          8,
          (index) => ListTile(
            leading: Container(width: 24, height: 24, color: Colors.white),
            title: Container(height: 14, width: 140, color: Colors.white),
            subtitle: Container(height: 10, width: 100, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsBody(
    BuildContext context,
    UserSettings? settings,
    AsyncValue<UserSubscription?> subscriptionAsync,
    AsyncValue<TubeFlowUser?> userAsync,
  ) {
    // Use defaults when settings are null (new user).
    final darkMode = settings?.theme == AppThemeMode.dark;
    final autoPlay = settings?.playback.autoplay ?? true;
    final playbackSpeed = settings?.playback.defaultSpeed ?? 1.0;
    final timestampOnPause = settings?.notes.defaultTimestamped ?? false;
    final notificationsEnabled = settings?.notifications.push ?? true;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        subscriptionAsync.when(
          data: (subscription) => ListTile(
            leading: const Icon(Icons.workspace_premium),
            title: const Text('Subscription'),
            subtitle: Text(subscription != null
                ? '${subscription.plan.name.toUpperCase()} plan - ${subscription.status.name}'
                : 'Free tier'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: navigate to subscription management
            },
          ),
          loading: () => const ListTile(
            leading: Icon(Icons.workspace_premium),
            title: Text('Subscription'),
            subtitle: Text('Loading...'),
          ),
          error: (_, __) => const ListTile(
            leading: Icon(Icons.workspace_premium),
            title: Text('Subscription'),
            subtitle: Text('Could not load'),
          ),
        ),
        const Divider(),

        // Appearance section
        _buildSectionHeader(context, 'Appearance'),
        SwitchListTile(
          secondary: const Icon(Icons.dark_mode),
          title: const Text('Dark Mode'),
          subtitle: const Text('Use dark theme'),
          value: darkMode,
          onChanged: (value) {
            _updateSettings({
              'theme': value ? 'dark' : 'light',
            });
          },
        ),
        const Divider(),

        // Playback section
        _buildSectionHeader(context, 'Playback'),
        SwitchListTile(
          secondary: const Icon(Icons.play_circle),
          title: const Text('Auto-Play'),
          subtitle: const Text('Play next video automatically'),
          value: autoPlay,
          onChanged: (value) {
            _updateSettings({
              'playback': {'autoplay': value},
            });
          },
        ),
        ListTile(
          leading: const Icon(Icons.speed),
          title: const Text('Playback Speed'),
          subtitle: Text('${playbackSpeed}x'),
          trailing: SizedBox(
            width: 160,
            child: Slider(
              value: playbackSpeed,
              min: 0.5,
              max: 2.0,
              divisions: 6,
              label: '${playbackSpeed}x',
              onChanged: (value) {
                _updateSettings({
                  'playback': {'defaultSpeed': value},
                });
              },
            ),
          ),
        ),
        const Divider(),

        // Notes section
        _buildSectionHeader(context, 'Notes'),
        SwitchListTile(
          secondary: const Icon(Icons.pause_circle),
          title: const Text('Timestamp on Pause'),
          subtitle: const Text('Create note prompt when pausing video'),
          value: timestampOnPause,
          onChanged: (value) {
            _updateSettings({
              'notes': {'defaultTimestamped': value},
            });
          },
        ),
        const Divider(),

        // Notifications section
        _buildSectionHeader(context, 'Notifications'),
        SwitchListTile(
          secondary: const Icon(Icons.notifications),
          title: const Text('Enable Notifications'),
          subtitle: const Text('Master notification toggle'),
          value: notificationsEnabled,
          onChanged: (value) {
            _updateSettings({
              'notifications': {'push': value},
            });
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.fiber_new),
          title: const Text('New Video Alerts'),
          subtitle: const Text('Notify when subscribed channels upload'),
          value: settings?.notifications.newVideos ?? true,
          onChanged: notificationsEnabled
              ? (value) {
                  _updateSettings({
                    'notifications': {'newVideos': value},
                  });
                }
              : null,
        ),
        ListTile(
          leading: const Icon(Icons.schedule),
          title: const Text('Check Interval'),
          subtitle: Text(_intervalLabel(
              settings?.notifications.feedRefreshIntervalMinutes ?? 60)),
          enabled: notificationsEnabled &&
              (settings?.notifications.newVideos ?? true),
          trailing: const Icon(Icons.chevron_right),
          onTap: (notificationsEnabled &&
                  (settings?.notifications.newVideos ?? true))
              ? () => _showChoiceDialog(
                    title: 'Check Interval',
                    options: [
                      'Off',
                      'Every 30 minutes',
                      'Every hour',
                      'Every 2 hours',
                      'Every 6 hours',
                      'Daily',
                    ],
                    currentValue: _intervalLabel(
                        settings?.notifications.feedRefreshIntervalMinutes ??
                            60),
                    onSelected: (value) {
                      _updateSettings({
                        'notifications': {
                          'feedRefreshIntervalMinutes':
                              _intervalFromLabel(value),
                        },
                      });
                    },
                  )
              : null,
        ),
        const Divider(),

        // Transcripts section
        _buildSectionHeader(context, 'Transcripts'),
        ListTile(
          leading: const Icon(Icons.translate),
          title: const Text('Transcript Language'),
          subtitle: Text(settings?.transcripts.defaultLanguage ?? 'Auto-detect'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showChoiceDialog(
            title: 'Transcript Language',
            options: ['Auto-detect', 'English', 'French', 'Spanish', 'German'],
            currentValue:
                settings?.transcripts.defaultLanguage ?? 'Auto-detect',
            onSelected: (value) {
              _updateSettings({
                'transcripts': {
                  'defaultLanguage': value == 'Auto-detect' ? null : value.toLowerCase(),
                },
              });
            },
          ),
        ),
        const SizedBox(height: 32),

        // App info
        Center(
          child: Text(
            'TubeFlow v1.0.0',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
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

  void _showChoiceDialog({
    required String title,
    required List<String> options,
    required String currentValue,
    required ValueChanged<String> onSelected,
  }) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(title),
        children: options.map((option) {
          return RadioListTile<String>(
            title: Text(option),
            value: option,
            groupValue: currentValue,
            onChanged: (value) {
              if (value != null) {
                onSelected(value);
                Navigator.of(context).pop();
              }
            },
          );
        }).toList(),
      ),
    );
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
                backgroundImage:
                    user.imageUrl != null ? NetworkImage(user.imageUrl!) : null,
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
                    await ref.read(clerkServiceProvider).signOut();
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
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: const Text('Not signed in'),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clerk = ref.watch(clerkServiceProvider);
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
        value: _convexUrl.isNotEmpty ? _convexUrl : '(missing)',
        ok: _convexUrl.isNotEmpty,
      ),
      (
        key: 'CLERK_PUBLISHABLE_KEY',
        value: _clerkPublishableKey.isNotEmpty
            ? '${_clerkPublishableKey.substring(0, _clerkPublishableKey.length.clamp(0, 10))}…'
            : '(missing)',
        ok: _clerkPublishableKey.isNotEmpty,
      ),
      (
        key: 'Clerk initialised',
        value: clerk.isInitialised ? 'yes' : 'no',
        ok: clerk.isInitialised,
      ),
      (
        key: 'Auth state',
        value: authLabel,
        ok: authState is AuthAuthenticated,
      ),
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
                              fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          r.value,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 12),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied')),
    );
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
                      separatorBuilder: (_, __) => const Divider(height: 8),
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
