import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:tubeflow_app/models/models.dart';
import 'package:tubeflow_app/providers/mutations.dart';
import 'package:tubeflow_app/providers/providers.dart';
import 'package:tubeflow_app/utils/color_utils.dart';
import 'package:tubeflow_app/utils/duration_utils.dart';
import 'package:tubeflow_app/widgets/error_feedback.dart';

/// Playlist detail screen showing the playlist header and its video list.
///
/// Convex queries/mutations used:
/// - `playlists.getPlaylistWithVideos` — fetch playlist metadata + videos
/// - `videoOrder.getOrder` — fetch custom video sort order within playlist
/// - `videoOrder.updateOrder` — persist reorder changes
/// - `playlists.updatePlaylist` — update playlist metadata (title, color, etc.)
/// - `playlists.removeVideoFromPlaylist` — remove a video from the playlist
class PlaylistDetailScreen extends ConsumerStatefulWidget {
  /// Convex document ID of the playlist.
  final String id;

  const PlaylistDetailScreen({super.key, required this.id});

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  bool _isReorderMode = false;
  List<YouTubeVideo> _reorderList = [];

  @override
  Widget build(BuildContext context) {
    final videosAsync = ref.watch(playlistVideosProvider(widget.id));
    final playlistsAsync = ref.watch(playlistsProvider);

    // Find the current playlist from the playlists list.
    YouTubePlaylist? playlist;
    playlistsAsync.whenData((playlists) {
      for (final p in playlists) {
        if (p.id == widget.id) {
          playlist = p;
          break;
        }
      }
    });

    final playlistColor = playlist?.color != null
        ? parseHexColor(playlist!.color!)
        : Colors.purple;
    final playlistTitle = playlist?.title ?? 'Playlist';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Collapsible playlist header
          _buildSliverAppBar(context, playlistTitle, playlistColor, playlist),
          // Stats bar
          SliverToBoxAdapter(
            child: videosAsync.when(
              data: (videos) => _buildStatsBar(context, videos),
              loading: () => _buildStatsBar(context, []),
              error: (_, __) => _buildStatsBar(context, []),
            ),
          ),
          // Video list (reorderable when in edit mode)
          videosAsync.when(
            data: (videos) {
              if (_isReorderMode) {
                if (_reorderList.isEmpty ||
                    _reorderList.length != videos.length) {
                  _reorderList = List.from(videos);
                }
                return _buildReorderableList();
              }
              return _buildVideoList(videos);
            },
            loading: () => SliverToBoxAdapter(child: _buildShimmerList()),
            error: (error, stack) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: ErrorStateView(
                  error: error,
                  prefix: 'Failed to load videos',
                  onRetry: () => ref.invalidate(playlistVideosProvider(widget.id)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: List.generate(
          5,
          (index) => ListTile(
            leading: Container(
              width: 100, height: 56, color: Colors.white,
            ),
            title: Container(height: 14, width: 160, color: Colors.white),
            subtitle: Container(height: 10, width: 100, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, String title, Color color,
      YouTubePlaylist? playlist) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      actions: [
        IconButton(
          icon: Icon(_isReorderMode ? Icons.check : Icons.reorder),
          tooltip: _isReorderMode ? 'Done reordering' : 'Reorder videos',
          onPressed: () {
            setState(() => _isReorderMode = !_isReorderMode);
            if (!_isReorderMode && _reorderList.isNotEmpty) {
              // TODO: call videoOrder.updateOrder with _reorderList IDs
            }
          },
        ),
        PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'refresh':
                try {
                  await syncPlaylist(ref, widget.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Refreshing playlist...')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    showErrorSnackBar(
                      context,
                      error: e,
                      prefix: 'Refresh failed',
                    );
                  }
                }
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
                value: 'edit', child: Text('Edit Playlist')),
            const PopupMenuItem(
                value: 'refresh', child: Text('Refresh from YouTube')),
            const PopupMenuItem(value: 'share', child: Text('Share')),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          title,
          style: const TextStyle(fontSize: 16),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.6),
                color.withValues(alpha: 0.2),
              ],
            ),
          ),
          child: playlist?.effectiveThumbnailUrl != null
              ? CachedNetworkImage(
                  imageUrl: playlist!.effectiveThumbnailUrl!,
                  fit: BoxFit.cover,
                  color: Colors.black.withValues(alpha: 0.3),
                  colorBlendMode: BlendMode.darken,
                  errorWidget: (context, url, error) => const Center(
                    child: Icon(Icons.playlist_play,
                        size: 64, color: Colors.white70),
                  ),
                )
              : const Center(
                  child: Icon(
                    Icons.playlist_play,
                    size: 64,
                    color: Colors.white70,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildStatsBar(BuildContext context, List<YouTubeVideo> videos) {
    int totalSeconds = 0;
    for (final v in videos) {
      totalSeconds += parseDuration(v.duration) ?? 0;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildStatChip(context, Icons.video_library,
              '${videos.length} video${videos.length == 1 ? '' : 's'}'),
          const SizedBox(width: 16),
          _buildStatChip(
              context, Icons.schedule, '${formatDuration(totalSeconds)} total'),
          const Spacer(),
          FilledButton.tonal(
            onPressed: videos.isNotEmpty
                ? () {
                    // TODO: play all from beginning - navigate to play screen
                  }
                : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow, size: 18),
                SizedBox(width: 4),
                Text('Play All'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(BuildContext context, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildVideoList(List<YouTubeVideo> videos) {
    if (videos.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('No videos in this playlist',
                style: TextStyle(color: Colors.grey)),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final video = videos[index];
          final durationSec = parseDuration(video.duration);

          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: video.thumbnailUrl != null
                  ? CachedNetworkImage(
                      imageUrl: video.thumbnailUrl!,
                      width: 100,
                      height: 56,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 100, height: 56, color: Colors.grey[300],
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 100, height: 56, color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.play_circle_outline, size: 28),
                        ),
                      ),
                    )
                  : Container(
                      width: 100,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(
                        child: Icon(Icons.play_circle_outline, size: 28),
                      ),
                    ),
            ),
            title: Text(
              video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${video.channelTitle}'
              '${durationSec != null ? ' - ${formatDuration(durationSec)}' : ''}',
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'remove':
                    try {
                      await removeVideoFromPlaylist(ref,
                          playlistId: widget.id, videoId: video.id);
                    } catch (e) {
                      if (context.mounted) {
                        showErrorSnackBar(context, error: e, prefix: 'Error');
                      }
                    }
                    break;
                  case 'hide':
                    try {
                      await hideVideo(ref, video.youtubeVideoId);
                    } catch (e) {
                      if (context.mounted) {
                        showErrorSnackBar(context, error: e, prefix: 'Error');
                      }
                    }
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'remove', child: Text('Remove')),
                const PopupMenuItem(value: 'hide', child: Text('Hide')),
              ],
            ),
            onTap: () {
              // TODO: navigate to play screen with video.id
            },
          );
        },
        childCount: videos.length,
      ),
    );
  }

  Widget _buildReorderableList() {
    return SliverToBoxAdapter(
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _reorderList.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex--;
            final item = _reorderList.removeAt(oldIndex);
            _reorderList.insert(newIndex, item);
          });
        },
        itemBuilder: (context, index) {
          final video = _reorderList[index];
          final durationSec = parseDuration(video.duration);
          return ListTile(
            key: ValueKey(video.id),
            leading: const Icon(Icons.drag_handle),
            title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(durationSec != null ? formatDuration(durationSec) : ''),
          );
        },
      ),
    );
  }

}
