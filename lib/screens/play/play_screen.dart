import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import 'package:tubeflow_app/app/router.dart';
import 'package:tubeflow_app/models/models.dart';
import 'package:tubeflow_app/providers/mutations.dart';
import 'package:tubeflow_app/providers/providers.dart';
import 'package:tubeflow_app/widgets/common_app_bar_actions.dart';
import 'package:tubeflow_app/widgets/error_feedback.dart';
import 'package:tubeflow_app/widgets/youtube_connect.dart';

/// Video player screen with notes, transcript, and comments tabs.
///
/// Convex queries/mutations used:
/// - `youtube.getPlaylistVideos` — fetch sibling videos in the same playlist
/// - `notes.getNotes` — fetch notes for the current video
/// - `notes.createNote` — create a timestamped note
/// - `notes.updateNote` — edit an existing note
/// - `notes.deleteNote` — remove a note
/// - `transcripts.getTranscript` — fetch video transcript
/// - `progress.getProgress` — load saved playback position
/// - `progress.upsertProgress` — save current playback position
class PlayScreen extends ConsumerStatefulWidget {
  /// Convex document ID of the video to play.
  final String videoId;

  const PlayScreen({super.key, required this.videoId});

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _noteController = TextEditingController();

  // Playback state
  double _currentTimestamp = 0.0;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _saveProgress();
    _tabController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Save playback progress to Convex on dispose / pause.
  Future<void> _saveProgress() async {
    if (_currentTimestamp > 0) {
      try {
        await upsertProgress(ref, widget.videoId, _currentTimestamp);
      } catch (_) {
        // Best-effort save; don't crash on dispose.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final youtubeConnectionAsync = ref.watch(youtubeConnectionProvider);
    final youtubeConnected =
        youtubeConnectionAsync.asData?.value?['connected'] == true;
    final hasVideoId = widget.videoId.isNotEmpty;
    final notesAsync = youtubeConnected && hasVideoId
        ? ref.watch(videoNotesProvider(widget.videoId))
        : const AsyncValue<List<Note>>.data(<Note>[]);
    final progressAsync = youtubeConnected && hasVideoId
        ? ref.watch(videoProgressProvider(widget.videoId))
        : const AsyncValue<VideoProgress?>.data(null);

    // Restore saved progress on first load.
    progressAsync.whenData((progress) {
      if (progress != null && _currentTimestamp == 0.0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _currentTimestamp = progress.progressSeconds);
          }
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_play),
            onPressed: () {
              if (!youtubeConnected) {
                startYoutubeConnectFlow(context, returnTo: Routes.play);
                return;
              }
              // TODO: show playlist queue drawer
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // TODO: show options (share, hide, report)
            },
          ),
          ...commonAppBarActions(context, ref),
        ],
      ),
      body: youtubeConnectionAsync.when(
        data: (status) {
          if (status?['connected'] != true) {
            return const YoutubeConnectRequiredState(
              title: 'Connect YouTube to watch and take notes',
              description:
                  'Playback, transcript lookups, and timestamped notes all depend on your YouTube library being connected first.',
              returnTo: Routes.play,
            );
          }

          if (!hasVideoId) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.play_circle_outline_rounded,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Choose a video to start playback',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Open Videos or Playlists, then select a synced YouTube video to unlock playback, transcript, and notes.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Column(
            children: [
              // Video player area
              _buildPlayerArea(),
              // Playback controls
              _buildPlaybackControls(),
              // Tabs for Notes / Transcript / Comments
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Notes'),
                  Tab(text: 'Transcript'),
                  Tab(text: 'Comments'),
                ],
              ),
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildNotesTab(notesAsync),
                    _buildTranscriptTab(),
                    _buildCommentsTab(),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const YoutubeConnectionLoadingState(
          title: 'Checking playback access',
          description:
              'TubeFlow is confirming your YouTube connection before opening the player.',
        ),
        error: (error, stack) => ErrorStateView(
          error: error,
          prefix: 'Failed to check YouTube connection',
          onRetry: () => ref.invalidate(youtubeConnectionProvider),
        ),
      ),
    );
  }

  Widget _buildPlayerArea() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_circle_filled, size: 72, color: Colors.white70),
              SizedBox(height: 8),
              Text(
                'YouTube Player Placeholder',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                'Will use youtube_player_flutter',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaybackControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Progress slider
          Slider(
            value: _currentTimestamp,
            max: 300, // placeholder 5 minutes
            onChanged: (value) {
              setState(() => _currentTimestamp = value);
              // TODO: seek player to position
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatTime(_currentTimestamp)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_10),
                    onPressed: () {
                      setState(() {
                        _currentTimestamp = (_currentTimestamp - 10).clamp(
                          0,
                          300,
                        );
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: () {
                      setState(() => _isPlaying = !_isPlaying);
                      if (!_isPlaying) _saveProgress();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.forward_10),
                    onPressed: () {
                      setState(() {
                        _currentTimestamp = (_currentTimestamp + 10).clamp(
                          0,
                          300,
                        );
                      });
                    },
                  ),
                ],
              ),
              const Text('5:00'), // placeholder total duration
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesTab(AsyncValue<List<Note>> notesAsync) {
    return Column(
      children: [
        // Note input area
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    hintText:
                        'Add a note at ${_formatTime(_currentTimestamp)}...',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 2,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.send),
                onPressed: () async {
                  final content = _noteController.text.trim();
                  if (content.isEmpty) return;
                  try {
                    await createNote(
                      ref,
                      videoId: widget.videoId,
                      content: content,
                      timestamp: _currentTimestamp,
                      title: content.length > 50
                          ? '${content.substring(0, 50)}...'
                          : content,
                    );
                    _noteController.clear();
                  } catch (e) {
                    if (!mounted) return;
                    showErrorSnackBar(
                      context,
                      error: e,
                      prefix: 'Failed to save note',
                    );
                  }
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Notes list
        Expanded(
          child: notesAsync.when(
            data: (notes) {
              if (notes.isEmpty) {
                return const Center(
                  child: Text(
                    'No notes yet. Add one above!',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: note.isTimestamped
                          ? TextButton(
                              onPressed: () {
                                setState(
                                  () => _currentTimestamp = note.timestamp!,
                                );
                                // TODO: seek player to timestamp
                              },
                              child: Text(
                                '[${note.formattedTimestamp}]',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                      title: Text(
                        note.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () async {
                          try {
                            await deleteNote(ref, note.id);
                          } catch (e) {
                            if (context.mounted) {
                              showErrorSnackBar(
                                context,
                                error: e,
                                prefix: 'Failed to delete note',
                              );
                            }
                          }
                        },
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: 3,
                itemBuilder: (context, index) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Container(height: 56, color: Colors.white),
                ),
              ),
            ),
            error: (error, stack) =>
                ErrorStateView(error: error, prefix: 'Failed to load notes'),
          ),
        ),
      ],
    );
  }

  Widget _buildTranscriptTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 20, // TODO: replace with transcript segments from provider
      itemBuilder: (context, index) {
        final seconds = index * 15;
        return InkWell(
          onTap: () {
            setState(() => _currentTimestamp = seconds.toDouble());
            // TODO: seek player to this transcript segment
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    _formatTime(seconds.toDouble()),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Transcript segment $index — placeholder text for the '
                    'auto-generated or fetched transcript content.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentsTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.comment_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text('Comments coming soon', style: TextStyle(color: Colors.grey)),
          SizedBox(height: 8),
          Text(
            'YouTube comments will be displayed here',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatTime(double seconds) {
    final total = seconds.floor();
    final mins = total ~/ 60;
    final secs = total % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}
