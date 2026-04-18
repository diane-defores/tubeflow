import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:tubeflow_app/models/models.dart';
import 'package:tubeflow_app/providers/mutations.dart';
import 'package:tubeflow_app/providers/providers.dart';
import 'package:tubeflow_app/utils/date_utils.dart';
import 'package:tubeflow_app/widgets/common_app_bar_actions.dart';
import 'package:tubeflow_app/widgets/error_feedback.dart';
import 'package:tubeflow_app/widgets/youtube_connect.dart';

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
    final playlistsAsync = ref.watch(playlistsProvider);

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
              try {
                await syncAllPlaylists(ref);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Syncing playlists...')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  showErrorSnackBar(
                    context,
                    error: e,
                    prefix: 'Sync failed',
                  );
                }
              }
            },
          ),
          ...commonAppBarActions(context, ref),
        ],
      ),
      body: playlistsAsync.when(
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
        loading: () => Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 4,
            itemBuilder: (context, index) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(width: 120, height: 90, color: Colors.white),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(height: 14, width: 100, color: Colors.white),
                          const SizedBox(height: 8),
                          Container(height: 10, width: 60, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        error: (error, stack) => ErrorStateView(
          error: error,
          prefix: 'Failed to load playlists',
          onRetry: () => ref.invalidate(playlistsProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: navigate to create playlist screen
        },
        icon: const Icon(Icons.add),
        label: const Text('New Playlist'),
      ),
    );
  }

  Widget _buildPlaylistCard(
      BuildContext context, WidgetRef ref, YouTubePlaylist playlist) {
    final color = playlist.color != null
        ? _parseColor(playlist.color!)
        : Colors.purple;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // TODO: navigate to playlist detail screen with playlist.id
        },
        child: Row(
          children: [
            // Thumbnail area with color accent
            Container(
              width: 120,
              height: 90,
              color: color.withValues(alpha: 0.2),
              child: Stack(
                children: [
                  playlist.effectiveThumbnailUrl != null
                      ? CachedNetworkImage(
                          imageUrl: playlist.effectiveThumbnailUrl!,
                          width: 120,
                          height: 90,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => const Center(
                            child: Icon(Icons.playlist_play, size: 40),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.playlist_play, size: 40),
                        ),
                  // Color bar
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 4,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            // Playlist info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${playlist.videoCount} video${playlist.videoCount == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      playlist.cachedAt > 0
                          ? 'Updated ${formatDate(playlist.cachedAt)}'
                          : '',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            // Overflow menu
            PopupMenuButton<String>(
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
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    final hexCode = hex.replaceFirst('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }
}
