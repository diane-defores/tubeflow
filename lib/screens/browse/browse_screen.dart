import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:tubeflow_app/models/models.dart';
import 'package:tubeflow_app/providers/providers.dart';
import 'package:tubeflow_app/utils/duration_utils.dart';

/// Netflix-style browse screen with horizontal scroll rows per playlist.
///
/// Convex queries/mutations used:
/// - `youtube.getAllVideos` — fetch all videos grouped by playlist
/// - `playlists.getPlaylists` — fetch playlist metadata for row headers
/// - `youtubeInteractions.toggleLike` — like/unlike a video
class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: open search delegate
            },
          ),
          IconButton(
            icon: const Icon(Icons.cast),
            onPressed: () {
              // TODO: cast / external player
            },
          ),
        ],
      ),
      body: playlistsAsync.when(
        data: (playlists) {
          if (playlists.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.explore_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Nothing to browse yet',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  SizedBox(height: 8),
                  Text('Add some playlists to get started',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: playlists.length,
            itemBuilder: (context, sectionIndex) {
              return _BrowsePlaylistRow(playlist: playlists[sectionIndex]);
            },
          );
        },
        loading: () => _buildShimmerLoading(),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Failed to load: $error',
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(playlistsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        itemCount: 3,
        itemBuilder: (context, index) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Container(height: 18, width: 140, color: Colors.white),
              ),
              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 4,
                  itemBuilder: (context, i) => Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 90,
                          width: 160,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(height: 12, width: 120, color: Colors.white),
                        const SizedBox(height: 4),
                        Container(height: 10, width: 80, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A single playlist row that loads its own videos via [playlistVideosProvider].
class _BrowsePlaylistRow extends ConsumerWidget {
  final YouTubePlaylist playlist;

  const _BrowsePlaylistRow({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = ref.watch(playlistVideosProvider(playlist.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (playlist.color != null)
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: _parseColor(playlist.color!),
                          shape: BoxShape.circle,
                        ),
                      ),
                    Flexible(
                      child: Text(
                        playlist.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: navigate to playlist detail with playlist.id
                },
                child: const Text('See All'),
              ),
            ],
          ),
        ),
        // Horizontal video row
        SizedBox(
          height: 200,
          child: videosAsync.when(
            data: (videos) {
              if (videos.isEmpty) {
                return const Center(
                  child: Text('No videos', style: TextStyle(color: Colors.grey)),
                );
              }
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: videos.length,
                itemBuilder: (context, videoIndex) {
                  return _buildVideoCard(context, videos[videoIndex]);
                },
              );
            },
            loading: () => Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 4,
                itemBuilder: (context, i) => Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 90, width: 160,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(height: 12, width: 120, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
            error: (error, stack) => Center(
              child: Text('Error: $error',
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoCard(BuildContext context, YouTubeVideo video) {
    final durationSec = parseDuration(video.duration);

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () {
          // TODO: navigate to play screen with video.id
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: video.thumbnailUrl != null
                      ? CachedNetworkImage(
                          imageUrl: video.thumbnailUrl!,
                          height: 90,
                          width: 160,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 90, width: 160, color: Colors.grey[300],
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 90, width: 160, color: Colors.grey[300],
                            child: const Center(
                              child: Icon(Icons.play_circle_outline, size: 36),
                            ),
                          ),
                        )
                      : Container(
                          height: 90,
                          width: 160,
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(Icons.play_circle_outline, size: 36),
                          ),
                        ),
                ),
                // Duration badge
                if (durationSec != null)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        formatDuration(durationSec),
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Title
            Text(
              video.title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Channel
            Text(
              video.channelTitle,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.grey,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Like button row
            Row(
              children: [
                InkWell(
                  onTap: () {
                    // TODO: call youtubeInteractions.toggleLike
                  },
                  child: const Icon(Icons.thumb_up_outlined, size: 16),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.bookmark_border, size: 16),
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
