import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:replayglowz_app/app/router.dart';
import 'package:replayglowz_app/models/models.dart';
import 'package:replayglowz_app/providers/mutations.dart';
import 'package:replayglowz_app/providers/providers.dart';
import 'package:replayglowz_app/widgets/app_states.dart';
import 'package:replayglowz_app/widgets/common_app_bar_actions.dart';
import 'package:replayglowz_app/widgets/error_feedback.dart';
import 'package:replayglowz_app/widgets/media/playlist_card.dart';
import 'package:replayglowz_app/widgets/youtube_connect.dart';

/// Playlists overview screen showing all user playlists.
///
/// Convex queries/mutations used:
/// - `playlists.getPlaylists` — fetch all playlists for the current user
/// - `playlistOrder.getOrder` — fetch custom sort order
/// - `playlistOrder.updateOrder` — persist reorder changes
class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final youtubeConnectionAsync = ref.watch(youtubeConnectionProvider);
    final youtubeConnected =
        youtubeConnectionAsync.asData?.value?['connected'] == true;
    final playlistsAsync = youtubeConnected
        ? ref.watch(playlistsProvider)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () {
              // TODO: show sort options (alphabetical, date, custom)
            },
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              if (!youtubeConnected) {
                await startYoutubeConnectFlow(
                  context,
                  returnTo: Routes.playlists,
                );
                return;
              }

              try {
                await syncAllPlaylists(ref);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Syncing playlists...')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  showErrorSnackBar(context, error: e, prefix: 'Sync failed');
                }
              }
            },
          ),
          ...commonAppBarActions(context, ref),
        ],
      ),
      body: youtubeConnectionAsync.when(
        data: (status) {
          if (status?['connected'] != true) {
            return const YoutubeConnectRequiredState(
              title: 'Connect YouTube to import playlists',
              description:
                  'Playlists, channel imports, and automatic refresh all depend on your YouTube connection.',
              returnTo: Routes.playlists,
            );
          }

          return playlistsAsync!.when(
            data: (playlists) {
              if (playlists.isEmpty) {
                return YoutubeAwareEmptyState(
                  fallbackIcon: Icons.playlist_play,
                  fallbackTitle: 'Aucune playlist',
                  fallbackDescription:
                      'Créez une playlist ou lancez une synchronisation YouTube.',
                  onRefresh: () => syncAllPlaylists(ref),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  return _buildPlaylistCard(context, ref, playlists[index]);
                },
              );
            },
            loading: () => AppLoadingListSkeleton(
              itemCount: 4,
              itemBuilder: (context, index) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 120,
                      height: 90,
                      color: Theme.of(context).colorScheme.surface,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 14,
                              width: 100,
                              color: Theme.of(context).colorScheme.surface,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 10,
                              width: 60,
                              color: Theme.of(context).colorScheme.surface,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            error: (error, stack) => ErrorStateView(
              error: error,
              prefix: 'Failed to load playlists',
              onRetry: () => ref.invalidate(playlistsProvider),
            ),
          );
        },
        loading: () => const YoutubeConnectionLoadingState(
          title: 'Checking your YouTube playlists',
          description:
              'ReplayGlowz is confirming your YouTube connection before loading playlist data.',
        ),
        error: (error, stack) => ErrorStateView(
          error: error,
          prefix: 'Failed to check YouTube connection',
          onRetry: () => ref.invalidate(youtubeConnectionProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: youtubeConnected
            ? () {
                context.go(Routes.playlistCreate);
              }
            : null,
        icon: const Icon(Icons.add),
        label: const Text('New Playlist'),
      ),
    );
  }

  Widget _buildPlaylistCard(
    BuildContext context,
    WidgetRef ref,
    YouTubePlaylist playlist,
  ) {
    return PlaylistCard(
      playlist: playlist,
      onTap: () => context.go(Routes.playlistDetail(playlist.id)),
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          switch (value) {
            case 'hide':
              try {
                await hidePlaylist(ref, playlist.youtubePlaylistId);
              } catch (e) {
                if (context.mounted) {
                  showErrorSnackBar(context, error: e, prefix: 'Error');
                }
              }
              break;
            case 'delete':
              // TODO: confirm and delete playlist
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          const PopupMenuItem(value: 'hide', child: Text('Hide')),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}
