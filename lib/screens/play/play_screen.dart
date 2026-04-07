import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import 'package:tubeflow_app/models/models.dart';
import 'package:tubeflow_app/providers/mutations.dart';
import 'package:tubeflow_app/providers/providers.dart';
import 'package:tubeflow_app/utils/duration_utils.dart';

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
    final notesAsync = ref.watch(videoNotesProvider(widget.videoId));
    final progressAsync = ref.watch(videoProgressProvider(widget.videoId));

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
              // TODO: show playlist queue drawer
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // TODO: show options (share, hide, report)
            },
          ),
        ],
      ),
      body: Column(
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
                        _currentTimestamp = (_currentTimestamp - 10).clamp(0, 300);
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
                        _currentTimestamp = (_currentTimestamp + 10).clamp(0, 300);
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
                    hintText: 'Add a note at ${_formatTime(_currentTimestamp)}...',
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
                    await createNote(ref,
                      videoId: widget.videoId,
                      content: content,
                      timestamp: _currentTimestamp,
                      title: content.length > 50
                          ? '${content.substring(0, 50)}...'
                          : content,
                    );
                    _noteController.clear();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to save note: $e')),
                      );
                    }
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
                                    () => _currentTimestamp = note.timestamp!);
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('Failed to delete note: $e')),
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
            error: (error, stack) => Center(
              child: Text('Failed to load notes: $error',
                  style: const TextStyle(color: Colors.red)),
            ),
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
          Text(
            'Comments coming soon',
            style: TextStyle(color: Colors.grey),
          ),
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
