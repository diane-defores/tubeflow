import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:tubeflow_app/models/models.dart';
import 'package:tubeflow_app/providers/providers.dart';
import 'package:tubeflow_app/convex/convex_provider.dart';
import 'package:tubeflow_app/utils/duration_utils.dart';

/// Video feed screen with multiple view modes.
///
/// Convex queries/mutations used:
/// - `youtube.getAllVideos` — fetch all cached videos across playlists
/// - `notes.getNotes` — fetch notes count per video for badge display
/// - `settings.getSettings` — load user preferences (default view mode, etc.)
class VideosScreen extends ConsumerStatefulWidget {
  const VideosScreen({super.key});

  @override
  ConsumerState<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends ConsumerState<VideosScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videosAsync = ref.watch(videosProvider(const VideosArgs()));
    final notesAsync = ref.watch(notesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Videos'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.grid_view), text: 'Cards'),
            Tab(icon: Icon(Icons.list), text: 'List'),
            Tab(icon: Icon(Icons.summarize), text: 'Summary'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: open search delegate
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: show filter bottom sheet (by playlist, date, etc.)
            },
          ),
        ],
      ),
      body: videosAsync.when(
        data: (videos) {
          final notesByVideo = <String, int>{};
          notesAsync.whenData((notes) {
            for (final note in notes) {
              if (note.youtubeVideoId != null) {
                notesByVideo[note.youtubeVideoId!] =
                    (notesByVideo[note.youtubeVideoId!] ?? 0) + 1;
              }
            }
          });

          if (videos.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_library_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No videos yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  SizedBox(height: 8),
                  Text('Sync your YouTube playlists to get started',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildCardView(videos),
              _buildListView(videos),
              _buildSummaryView(videos, notesByVideo),
            ],
          );
        },
        loading: () => _buildShimmerLoading(),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Failed to load videos: $error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(videosProvider(const VideosArgs())),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            await ref.read(convexServiceProvider).mutate(
                'youtube:syncAllPlaylists', {});
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Refreshing videos...')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Refresh failed: $e')),
              );
            }
          }
        },
        tooltip: 'Refresh videos',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 200, color: Colors.white),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 16, width: 200, color: Colors.white),
                      const SizedBox(height: 8),
                      Container(height: 12, width: 120, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardView(List<YouTubeVideo> videos) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              // TODO: navigate to play screen with video.id
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                video.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: video.thumbnailUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 200,
                          color: Colors.grey[300],
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 200,
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(Icons.play_circle_outline, size: 64),
                          ),
                        ),
                      )
                    : Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.play_circle_outline, size: 64),
                        ),
                      ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              video.channelTitle,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          if (video.duration != null)
                            Text(
                              formatDuration(parseDuration(video.duration) ?? 0),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                        ],
                      ),
                      if (video.playlistTitle != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (video.playlistColor != null)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: _parseColor(video.playlistColor!),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Text(
                              video.playlistTitle!,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.grey,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildListView(List<YouTubeVideo> videos) {
    return ListView.builder(
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return ListTile(
          leading: video.thumbnailUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: video.thumbnailUrl!,
                    width: 120,
                    height: 68,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 120, height: 68, color: Colors.grey[300],
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 120, height: 68, color: Colors.grey[300],
                      child: const Icon(Icons.play_circle_outline),
                    ),
                  ),
                )
              : Container(
                  width: 120,
                  height: 68,
                  color: Colors.grey[300],
                  child: const Icon(Icons.play_circle_outline),
                ),
          title: Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${video.channelTitle}'
            '${video.duration != null ? ' - ${formatDuration(parseDuration(video.duration) ?? 0)}' : ''}',
          ),
          trailing: const Icon(Icons.more_vert),
          onTap: () {
            // TODO: navigate to play screen with video.id
          },
        );
      },
    );
  }

  Widget _buildSummaryView(
      List<YouTubeVideo> videos, Map<String, int> notesByVideo) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        final noteCount = notesByVideo[video.youtubeVideoId] ?? 0;
        final durationSec = parseDuration(video.duration);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              // TODO: navigate to play screen with video.id
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    video.description ??
                        'No description available for this video.',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.notes, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$noteCount note${noteCount == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(width: 16),
                      if (durationSec != null) ...[
                        const Icon(Icons.schedule, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          formatDuration(durationSec),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _parseColor(String hex) {
    final hexCode = hex.replaceFirst('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }
}
