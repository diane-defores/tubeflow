import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import 'package:tubeflow_app/models/models.dart';
import 'package:tubeflow_app/providers/mutations.dart';
import 'package:tubeflow_app/providers/providers.dart';
import 'package:tubeflow_app/widgets/error_feedback.dart';

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
    final settingsAsync = ref.watch(settingsProvider);
    final subscriptionAsync = ref.watch(subscriptionProvider);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preferences'),
      ),
      body: settingsAsync.when(
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
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView(
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

    return ListView(
      children: [
        // Account section
        _buildSectionHeader(context, 'Account'),
        userAsync.when(
          data: (user) => ListTile(
            leading: CircleAvatar(
              backgroundImage:
                  user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
              child: user?.avatarUrl == null ? const Icon(Icons.person) : null,
            ),
            title: Text(user?.displayName ?? 'User'),
            subtitle: Text(user?.email ?? ''),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: navigate to account management / Clerk profile
            },
          ),
          loading: () => const ListTile(
            leading: CircleAvatar(child: Icon(Icons.person)),
            title: Text('Loading...'),
          ),
          error: (_, __) => const ListTile(
            leading: CircleAvatar(child: Icon(Icons.person)),
            title: Text('Could not load user'),
          ),
        ),
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
