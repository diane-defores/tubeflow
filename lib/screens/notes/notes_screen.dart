import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';

import 'package:tubeflow_app/app/router.dart';
import 'package:tubeflow_app/models/models.dart';
import 'package:tubeflow_app/providers/providers.dart';
import 'package:tubeflow_app/widgets/common_app_bar_actions.dart';
import 'package:tubeflow_app/widgets/error_feedback.dart';
import 'package:tubeflow_app/widgets/youtube_connect.dart';

/// Notes overview screen with search and grouped display.
///
/// Convex queries used:
/// - `notes.getNotes` — fetch all notes for the current user
/// - `youtube.getVideosInfoBatch` — fetch video metadata for note grouping
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final youtubeConnectionAsync = ref.watch(youtubeConnectionProvider);
    final youtubeConnected =
        youtubeConnectionAsync.asData?.value?['connected'] == true;
    final notesAsync = ref.watch(notesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () {
              // TODO: show sort options (by date, by video, by timestamp)
            },
          ),
          ...commonAppBarActions(context, ref),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search notes...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
          // Notes list grouped by video
          Expanded(
            child: notesAsync.when(
              data: (notes) =>
                  _buildGroupedNotesList(context, notes, youtubeConnected),
              loading: () {
                if (youtubeConnectionAsync.isLoading &&
                    youtubeConnectionAsync.asData == null) {
                  return const YoutubeConnectionLoadingState(
                    title: 'Checking your YouTube notes',
                    description:
                        'TubeFlow is confirming your YouTube connection before loading notes.',
                  );
                }

                if (!youtubeConnected) {
                  return const YoutubeConnectRequiredState(
                    title: 'Connect YouTube to start taking notes',
                    description:
                        'TubeFlow creates notes while you watch synced YouTube videos. Connect YouTube first, then your notes will appear here.',
                    returnTo: Routes.notes,
                  );
                }

                return _buildShimmerLoading();
              },
              error: (error, stack) => ErrorStateView(
                error: error,
                prefix: 'Failed to load notes',
                onRetry: () => ref.invalidate(notesProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 6,
        itemBuilder: (context, index) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(width: 50, height: 14, color: Colors.white),
            title: Container(height: 12, width: 200, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedNotesList(
    BuildContext context,
    List<Note> allNotes,
    bool youtubeConnected,
  ) {
    // Filter notes by search query.
    final filtered = _searchQuery.isEmpty
        ? allNotes
        : allNotes
            .where((n) =>
                n.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                n.content.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    if (filtered.isEmpty) {
      if (!youtubeConnected) {
        return const YoutubeConnectRequiredState(
          title: 'Connect YouTube to start taking notes',
          description:
              'TubeFlow notes are attached to YouTube playback. Connect YouTube, open a video, and your notes will show up here.',
          returnTo: Routes.notes,
        );
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.note_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? 'No matching notes' : 'No notes yet',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            if (_searchQuery.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Notes you take during video playback will appear here',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
          ],
        ),
      );
    }

    // Group notes by youtubeVideoId (null = standalone).
    final grouped = <String?, List<Note>>{};
    for (final note in filtered) {
      grouped.putIfAbsent(note.youtubeVideoId, () => []).add(note);
    }

    final groupKeys = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: groupKeys.length,
      itemBuilder: (context, groupIndex) {
        final videoId = groupKeys[groupIndex];
        final groupNotes = grouped[videoId]!;
        final videoTitle = videoId != null ? 'Video: $videoId' : 'Standalone Notes';
        return _buildVideoGroup(
            context, videoTitle, groupNotes, groupIndex, groupKeys.length);
      },
    );
  }

  Widget _buildVideoGroup(
    BuildContext context,
    String videoTitle,
    List<Note> notes,
    int groupIndex,
    int totalGroups,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Video header
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.play_arrow, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  videoTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Text(
                '${notes.length} note${notes.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
        ),
        // Notes for this video
        ...notes.map((note) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: note.isTimestamped
                  ? Text(
                      '[${note.formattedTimestamp}]',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    )
                  : null,
              title: Text(
                note.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                context.go(Routes.noteDetail(note.id));
              },
            ),
          );
        }),
        if (groupIndex < totalGroups - 1) const Divider(),
      ],
    );
  }
}
