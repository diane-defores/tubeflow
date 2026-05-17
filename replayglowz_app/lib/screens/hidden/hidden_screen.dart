import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:replayglowz_app/models/models.dart';
import 'package:replayglowz_app/providers/mutations.dart';
import 'package:replayglowz_app/providers/providers.dart';
import 'package:replayglowz_app/utils/date_utils.dart';
import 'package:replayglowz_app/widgets/app_states.dart';
import 'package:replayglowz_app/widgets/error_feedback.dart';

/// Hidden items screen with tabs for hidden videos and hidden playlists.
///
/// Convex queries/mutations used:
/// - `hidden.getHiddenItems` — fetch all hidden items
/// - `hidden.unhideItem` — restore a hidden video or playlist
class HiddenScreen extends ConsumerStatefulWidget {
  const HiddenScreen({super.key});

  @override
  ConsumerState<HiddenScreen> createState() => _HiddenScreenState();
}

class _HiddenScreenState extends ConsumerState<HiddenScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hiddenAsync = ref.watch(hiddenItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hidden Items'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.videocam_off), text: 'Hidden Videos'),
            Tab(icon: Icon(Icons.playlist_remove), text: 'Hidden Playlists'),
          ],
        ),
      ),
      body: hiddenAsync.when(
        data: (items) {
          final hiddenVideos = items
              .where((i) => i.itemType == HiddenItemType.video)
              .toList();
          final hiddenPlaylists = items
              .where((i) => i.itemType == HiddenItemType.playlist)
              .toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildHiddenVideosList(context, hiddenVideos),
              _buildHiddenPlaylistsList(context, hiddenPlaylists),
            ],
          );
        },
        loading: () => _buildShimmerLoading(),
        error: (error, stack) => ErrorStateView(
          error: error,
          prefix: 'Failed to load hidden items',
          onRetry: () => ref.invalidate(hiddenItemsProvider),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return AppLoadingListSkeleton(
      itemCount: 3,
      itemBuilder: (context, index) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Container(
            width: 80,
            height: 45,
            color: Theme.of(context).colorScheme.surface,
          ),
          title: Container(
            height: 14,
            width: 120,
            color: Theme.of(context).colorScheme.surface,
          ),
          subtitle: Container(
            height: 10,
            width: 100,
            color: Theme.of(context).colorScheme.surface,
          ),
        ),
      ),
    );
  }

  Widget _buildHiddenVideosList(
    BuildContext context,
    List<HiddenItem> hiddenVideos,
  ) {
    if (hiddenVideos.isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.videocam_off,
        title: 'No hidden videos',
        subtitle: 'Videos you hide will appear here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: hiddenVideos.length,
      itemBuilder: (context, index) {
        final item = hiddenVideos[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 80,
              height: 45,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(
                child: Icon(Icons.visibility_off, size: 24, color: Colors.grey),
              ),
            ),
            title: Text(
              item.youtubeId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              'Hidden ${formatDate(item.hiddenAt)}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            trailing: FilledButton.tonal(
              onPressed: () {
                _confirmUnhide(
                  context,
                  itemType: 'video',
                  itemName: item.youtubeId,
                  onConfirm: () => _unhideItem(item),
                );
              },
              child: const Text('Unhide'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHiddenPlaylistsList(
    BuildContext context,
    List<HiddenItem> hiddenPlaylists,
  ) {
    if (hiddenPlaylists.isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.playlist_remove,
        title: 'No hidden playlists',
        subtitle: 'Playlists you hide will appear here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: hiddenPlaylists.length,
      itemBuilder: (context, index) {
        final item = hiddenPlaylists[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.playlist_play, size: 28, color: Colors.grey),
              ),
            ),
            title: Text(
              item.youtubeId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              'Hidden ${formatDate(item.hiddenAt)}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            trailing: FilledButton.tonal(
              onPressed: () {
                _confirmUnhide(
                  context,
                  itemType: 'playlist',
                  itemName: item.youtubeId,
                  onConfirm: () => _unhideItem(item),
                );
              },
              child: const Text('Unhide'),
            ),
          ),
        );
      },
    );
  }

  Future<void> _unhideItem(HiddenItem item) async {
    try {
      await unhideItem(ref, item.id);
      // Refresh the list after unhiding.
      ref.invalidate(hiddenItemsProvider);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, error: e, prefix: 'Failed to unhide');
      }
    }
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return AppEmptyState(icon: icon, title: title, description: subtitle);
  }

  void _confirmUnhide(
    BuildContext context, {
    required String itemType,
    required String itemName,
    required VoidCallback onConfirm,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Unhide $itemType?'),
        content: Text('"$itemName" will be visible again in your library.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onConfirm();
            },
            child: const Text('Unhide'),
          ),
        ],
      ),
    );
  }
}
