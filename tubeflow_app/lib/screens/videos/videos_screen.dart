import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import 'package:tubeflow_app/app/router.dart';
import 'package:tubeflow_app/models/models.dart';
import 'package:tubeflow_app/providers/mutations.dart';
import 'package:tubeflow_app/providers/providers.dart';
import 'package:tubeflow_app/utils/color_utils.dart';
import 'package:tubeflow_app/utils/duration_utils.dart';
import 'package:tubeflow_app/widgets/common_app_bar_actions.dart';
import 'package:tubeflow_app/widgets/error_feedback.dart';
import 'package:tubeflow_app/widgets/youtube_connect.dart';

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
  static const _compactViewBreakpoint = 640.0;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool _useCompactViewSwitcher(BuildContext context) {
    return MediaQuery.sizeOf(context).width < _compactViewBreakpoint;
  }

  ({IconData icon, String label}) _viewModeMeta(int index) {
    switch (index) {
      case 1:
        return (icon: Icons.list_rounded, label: 'List');
      case 2:
        return (icon: Icons.notes_rounded, label: 'Notes');
      default:
        return (icon: Icons.grid_view_rounded, label: 'Cards');
    }
  }

  Widget _buildViewModeAction(BuildContext context) {
    final current = _viewModeMeta(_tabController.index);

    return PopupMenuButton<int>(
      tooltip: 'View mode: ${current.label}',
      icon: Icon(current.icon),
      position: PopupMenuPosition.under,
      onSelected: (index) {
        if (index != _tabController.index) {
          _tabController.animateTo(index);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<int>(
          value: 0,
          child: _ViewModeMenuItem(
            icon: Icons.grid_view_rounded,
            label: 'Cards',
            selected: _tabController.index == 0,
          ),
        ),
        PopupMenuItem<int>(
          value: 1,
          child: _ViewModeMenuItem(
            icon: Icons.list_rounded,
            label: 'List',
            selected: _tabController.index == 1,
          ),
        ),
        PopupMenuItem<int>(
          value: 2,
          child: _ViewModeMenuItem(
            icon: Icons.notes_rounded,
            label: 'Notes',
            selected: _tabController.index == 2,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final useCompactViewSwitcher = _useCompactViewSwitcher(context);
    final youtubeConnectionAsync = ref.watch(youtubeConnectionProvider);
    final youtubeConnected =
        youtubeConnectionAsync.asData?.value?['connected'] == true;
    final videosAsync = youtubeConnected
        ? ref.watch(videosProvider(const VideosArgs()))
        : null;
    final notesAsync =
        youtubeConnected ? ref.watch(notesProvider) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Videos'),
        bottom: useCompactViewSwitcher
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.grid_view_rounded), text: 'Cards'),
                  Tab(icon: Icon(Icons.list_rounded), text: 'List'),
                  Tab(icon: Icon(Icons.notes_rounded), text: 'Notes'),
                ],
              ),
        actions: [
          if (useCompactViewSwitcher) _buildViewModeAction(context),
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
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              if (!youtubeConnected) {
                await startYoutubeConnectFlow(
                  context,
                  returnTo: Routes.videos,
                );
                return;
              }

              try {
                await syncAllPlaylists(ref);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Refreshing videos...')),
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
            },
          ),
          ...commonAppBarActions(context, ref),
        ],
      ),
      body: youtubeConnectionAsync.when(
        data: (status) {
          if (status?['connected'] != true) {
            return const YoutubeConnectRequiredState(
              title: 'Connect YouTube to browse videos',
              description:
                  'TubeFlow builds your video library from your synced YouTube playlists. Connect YouTube first, then your videos will appear here.',
              returnTo: Routes.videos,
            );
          }

          return videosAsync!.when(
            data: (videos) {
              final notesByVideo = <String, int>{};
              notesAsync?.whenData((notes) {
                for (final note in notes) {
                  if (note.youtubeVideoId != null) {
                    notesByVideo[note.youtubeVideoId!] =
                        (notesByVideo[note.youtubeVideoId!] ?? 0) + 1;
                  }
                }
              });

              if (videos.isEmpty) {
                return YoutubeAwareEmptyState(
                  fallbackIcon: Icons.video_library_outlined,
                  fallbackTitle: 'Aucune vidéo',
                  fallbackDescription:
                      'Lancez une synchronisation pour importer vos vidéos YouTube.',
                  onRefresh: () => syncAllPlaylists(ref),
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
            error: (error, stack) => ErrorStateView(
              error: error,
              prefix: 'Failed to load videos',
              onRetry: () => ref.invalidate(videosProvider(const VideosArgs())),
            ),
          );
        },
        loading: () => const YoutubeConnectionLoadingState(
          title: 'Checking your YouTube library',
          description:
              'TubeFlow is confirming whether your YouTube account is connected before loading your videos.',
        ),
        error: (error, stack) => ErrorStateView(
          error: error,
          prefix: 'Failed to check YouTube connection',
          onRetry: () => ref.invalidate(youtubeConnectionProvider),
        ),
      ),
      floatingActionButton: youtubeConnected
          ? FloatingActionButton(
              onPressed: () async {
                try {
                  await syncAllPlaylists(ref);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Refreshing videos...')),
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
              },
              tooltip: 'Refresh videos',
              child: const Icon(Icons.refresh),
            )
          : null,
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
              _openVideo(context, video.youtubeVideoId);
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
                                  color: parseHexColor(video.playlistColor!),
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
            _openVideo(context, video.youtubeVideoId);
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
              _openVideo(context, video.youtubeVideoId);
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

  void _openVideo(BuildContext context, String youtubeVideoId) {
    if (youtubeVideoId.isEmpty) {
      showErrorSnackBar(
        context,
        error: 'This video is missing an identifier.',
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
}

class _ViewModeMenuItem extends StatelessWidget {
  const _ViewModeMenuItem({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
        if (selected) ...[
          const SizedBox(width: 12),
          Icon(
            Icons.check_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          ),
        ],
      ],
    );
  }
}
