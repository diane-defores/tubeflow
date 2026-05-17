import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import 'package:replayglowz_app/app/router.dart';
import 'package:replayglowz_app/models/models.dart';
import 'package:replayglowz_app/providers/mutations.dart';
import 'package:replayglowz_app/providers/providers.dart';
import 'package:replayglowz_app/utils/color_utils.dart';
import 'package:replayglowz_app/utils/duration_utils.dart';
import 'package:replayglowz_app/widgets/app_states.dart';
import 'package:replayglowz_app/widgets/error_feedback.dart';
import 'package:replayglowz_app/widgets/media/video_list_tile.dart';

/// Playlist detail screen showing the playlist header and its video list.
///
/// Convex queries/mutations used:
/// - `playlists.getPlaylistWithVideos` — fetch playlist metadata + videos
/// - `videoOrder.getOrder` — fetch custom video sort order within playlist
/// - `videoOrder.updateOrder` (or `videoOrder.saveVideoOrder`) — persist reorder changes
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
  bool _isSavingOrder = false;
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
              error: (error, stackTrace) => _buildStatsBar(context, []),
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
                  onRetry: () =>
                      ref.invalidate(playlistVideosProvider(widget.id)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerList() {
    return AppLoadingListSkeleton(
      itemCount: 5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) => ListTile(
        leading: Container(
          width: 100,
          height: 56,
          color: Theme.of(context).colorScheme.surface,
        ),
        title: Container(
          height: 14,
          width: 160,
          color: Theme.of(context).colorScheme.surface,
        ),
        subtitle: Container(
          height: 10,
          width: 100,
          color: Theme.of(context).colorScheme.surface,
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(
    BuildContext context,
    String title,
    Color color,
    YouTubePlaylist? playlist,
  ) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      actions: [
        IconButton(
          icon: _isSavingOrder
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(_isReorderMode ? Icons.check : Icons.reorder),
          tooltip: _isReorderMode ? 'Done reordering' : 'Reorder videos',
          onPressed: _isSavingOrder
              ? null
              : () async {
                  if (!_isReorderMode) {
                    setState(() => _isReorderMode = true);
                    return;
                  }
                  await _persistVideoOrder(context);
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
              case 'share':
                await _copyPlaylistLink(context);
                break;
              case 'edit':
                if (context.mounted) {
                  showErrorSnackBar(
                    context,
                    error: 'Playlist editing is not implemented yet.',
                    prefix: 'Edit disabled',
                  );
                }
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit Playlist')),
            const PopupMenuItem(
              value: 'refresh',
              child: Text('Refresh from YouTube'),
            ),
            const PopupMenuItem(value: 'share', child: Text('Share')),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(title, style: const TextStyle(fontSize: 16)),
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
                    child: Icon(
                      Icons.playlist_play,
                      size: 64,
                      color: Colors.white70,
                    ),
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
          _buildStatChip(
            context,
            Icons.video_library,
            '${videos.length} video${videos.length == 1 ? '' : 's'}',
          ),
          const SizedBox(width: 16),
          _buildStatChip(
            context,
            Icons.schedule,
            '${formatDuration(totalSeconds)} total',
          ),
          const Spacer(),
          FilledButton.tonal(
            onPressed: videos.isNotEmpty
                ? () => _openVideo(context, videos.first.youtubeVideoId)
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
        child: AppEmptyState(
          icon: Icons.playlist_play,
          title: 'No videos in this playlist',
          description: 'Sync the playlist to import items from YouTube.',
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final video = videos[index];
        return VideoListTile(
          video: video,
          leadingWidth: 100,
          leadingHeight: 56,
          trailing: PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'remove':
                  try {
                    await removeVideoFromPlaylist(
                      ref,
                      playlistId: widget.id,
                      videoId: video.id,
                    );
                    if (context.mounted) {
                      ref.invalidate(playlistVideosProvider(widget.id));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Video removed from playlist.'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      showErrorSnackBar(context, error: e, prefix: 'Error');
                    }
                  }
                  break;
                case 'hide':
                  try {
                    await hideVideo(ref, video.youtubeVideoId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Video hidden from library.'),
                        ),
                      );
                    }
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
          onTap: () => _openVideo(context, video.youtubeVideoId),
        );
      }, childCount: videos.length),
    );
  }

  Future<void> _persistVideoOrder(BuildContext context) async {
    if (_reorderList.isEmpty) {
      setState(() => _isReorderMode = false);
      return;
    }

    final orderedIds = _reorderList
        .map((video) => video.id)
        .toList(growable: false);
    setState(() {
      _isSavingOrder = true;
    });

    try {
      await reorderPlaylistVideos(
        ref,
        playlistId: widget.id,
        orderedIds: orderedIds,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Playlist order saved.')));
      }
      setState(() {
        _isReorderMode = false;
      });
      ref.invalidate(playlistVideosProvider(widget.id));
    } catch (e) {
      if (context.mounted) {
        showErrorSnackBar(
          context,
          error: e,
          prefix: 'Failed to save playlist order',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingOrder = false;
        });
      }
    }
  }

  void _openVideo(BuildContext context, String youtubeVideoId) {
    if (youtubeVideoId.isEmpty) {
      showErrorSnackBar(
        context,
        error: 'This video is missing a YouTube identifier.',
        prefix: 'Cannot open video',
      );
      return;
    }

    context.go(
      Uri(
        path: Routes.play,
        queryParameters: {'videoId': youtubeVideoId},
      ).toString(),
    );
  }

  Future<void> _copyPlaylistLink(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(text: Routes.playlistDetail(widget.id)),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Playlist link copied.')));
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
            title: Text(
              video.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              durationSec != null ? formatDuration(durationSec) : '',
            ),
          );
        },
      ),
    );
  }
}
