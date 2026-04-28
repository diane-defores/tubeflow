import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'package:tubeflow_app/app/router.dart';
import 'package:tubeflow_app/convex/convex_provider.dart';
import 'package:tubeflow_app/models/models.dart';
import 'package:tubeflow_app/providers/mutations.dart';
import 'package:tubeflow_app/providers/providers.dart';
import 'package:tubeflow_app/utils/duration_utils.dart';
import 'package:tubeflow_app/widgets/common_app_bar_actions.dart';
import 'package:tubeflow_app/widgets/error_feedback.dart';
import 'package:tubeflow_app/widgets/youtube_connect.dart';

class _TranscriptEntry {
  const _TranscriptEntry({
    required this.startSeconds,
    required this.durationSeconds,
    required this.text,
    this.speaker,
  });

  final double startSeconds;
  final double durationSeconds;
  final String text;
  final String? speaker;

  double get endSeconds => startSeconds + durationSeconds;
}

/// Video player screen with notes, transcript, and comments tabs.
///
/// Convex queries/mutations used:
/// - `youtube.getAllVideos` — resolve metadata and current playlist queue
/// - `youtube.getPlaylistVideos` — load the playlist queue drawer
/// - `notes.getNotesByYoutubeVideo` — fetch notes for the current video
/// - `notes.createNote` — create a timestamped note
/// - `notes.deleteNote` — remove a note
/// - `progress.getProgress` — load saved playback position
/// - `progress.upsertProgress` — save current playback position
/// - `transcripts.getActiveTranscript` / `youtube.getTranscript` — transcript
/// - `transcriptGeneration.generateTranscript` — generate transcript on demand
class PlayScreen extends ConsumerStatefulWidget {
  /// YouTube video ID of the video to play.
  final String videoId;

  const PlayScreen({super.key, required this.videoId});

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final YoutubePlayerController _playerController;
  final TextEditingController _noteController = TextEditingController();

  String _loadedVideoId = '';
  bool _isPlayerReady = false;
  bool _isPlaying = false;
  bool _progressRestored = false;
  bool _isGeneratingTranscript = false;
  int _lastSyncedSecond = -1;
  double _currentTimestamp = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadedVideoId = widget.videoId;
    _playerController = YoutubePlayerController(
      initialVideoId: _initialPlayerVideoId(widget.videoId),
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        enableCaption: true,
        captionLanguage: 'en',
      ),
    )..addListener(_syncPlayerState);
  }

  @override
  void didUpdateWidget(covariant PlayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId == widget.videoId) {
      return;
    }

    _loadedVideoId = widget.videoId;
    _progressRestored = false;
    _currentTimestamp = 0;
    _lastSyncedSecond = -1;

    if (_isPlayerReady && _loadedVideoId.isNotEmpty) {
      _playerController.load(_loadedVideoId);
    }
  }

  @override
  void dispose() {
    _saveProgress();
    _playerController.removeListener(_syncPlayerState);
    _playerController.dispose();
    _tabController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Save playback progress to Convex on dispose / pause.
  Future<void> _saveProgress() async {
    if (_currentTimestamp <= 0 || widget.videoId.isEmpty) {
      return;
    }
    try {
      await upsertProgress(ref, widget.videoId, _currentTimestamp);
    } catch (_) {
      // Best-effort save; don't crash on dispose.
    }
  }

  void _syncPlayerState() {
    if (!mounted) return;
    final value = _playerController.value;
    if (!value.isReady) return;

    final second = value.position.inSeconds;
    final playing = value.isPlaying;

    if (second == _lastSyncedSecond && playing == _isPlaying) {
      return;
    }

    _lastSyncedSecond = second;
    setState(() {
      _currentTimestamp = value.position.inMilliseconds / 1000;
      _isPlaying = playing;
    });
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
    final videosAsync = youtubeConnected
        ? ref.watch(videosProvider(const VideosArgs()))
        : const AsyncValue<List<YouTubeVideo>>.data(<YouTubeVideo>[]);

    final settings = ref.watch(settingsProvider).asData?.value;
    final transcriptLanguage = _effectiveTranscriptLanguage(settings);
    final transcriptArgs = TranscriptArgs(
      youtubeVideoId: widget.videoId,
      language: transcriptLanguage,
    );
    final transcriptAsync = youtubeConnected && hasVideoId
        ? ref.watch(activeTranscriptProvider(transcriptArgs))
        : const AsyncValue<Map<String, dynamic>?>.data(null);

    final currentVideo = _findCurrentVideo(videosAsync.asData?.value);

    // Restore saved progress once per video load.
    progressAsync.whenData((progress) {
      if (_progressRestored || progress == null || progress.progressSeconds <= 0) {
        return;
      }
      _progressRestored = true;
      final resumeAt = progress.progressSeconds;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _currentTimestamp = resumeAt);
        _seekToSeconds(resumeAt);
      });
    });

    final title = currentVideo?.title ?? 'Now Playing';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_play),
            tooltip: 'Playlist queue',
            onPressed: () async {
              if (!youtubeConnected) {
                await startYoutubeConnectFlow(context, returnTo: Routes.play);
                return;
              }
              await _showQueueDrawer(currentVideo);
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Video options',
            onPressed: () => _showVideoOptions(currentVideo),
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
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
              _buildPlayerArea(),
              _buildPlaybackControls(currentVideo),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Notes'),
                  Tab(text: 'Transcript'),
                  Tab(text: 'Comments'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildNotesTab(notesAsync),
                    _buildTranscriptTab(
                      transcriptAsync,
                      language: transcriptLanguage,
                    ),
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
      child: YoutubePlayer(
        controller: _playerController,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Theme.of(context).colorScheme.primary,
        progressColors: ProgressBarColors(
          playedColor: Theme.of(context).colorScheme.primary,
          handleColor: Theme.of(context).colorScheme.primary,
        ),
        onReady: () {
          if (!mounted) return;
          if (!_isPlayerReady) {
            setState(() => _isPlayerReady = true);
          }
          if (_loadedVideoId.isNotEmpty &&
              _playerController.metadata.videoId != _loadedVideoId) {
            _playerController.load(_loadedVideoId);
          }
        },
        onEnded: (_) {
          setState(() {
            _isPlaying = false;
            _currentTimestamp = _playerController.metadata.duration.inSeconds
                .toDouble();
          });
          _saveProgress();
        },
      ),
    );
  }

  Widget _buildPlaybackControls(YouTubeVideo? currentVideo) {
    final maxSeconds = math.max(_resolvedDurationSeconds(currentVideo), 1);
    final sliderValue =
        _currentTimestamp.clamp(0, maxSeconds.toDouble()).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Slider(
            value: sliderValue,
            max: maxSeconds.toDouble(),
            onChanged: (value) {
              setState(() => _currentTimestamp = value);
            },
            onChangeEnd: _seekToSeconds,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatTime(_currentTimestamp)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_10),
                    onPressed: () => _seekToSeconds(_currentTimestamp - 10),
                  ),
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: _togglePlayPause,
                  ),
                  IconButton(
                    icon: const Icon(Icons.forward_10),
                    onPressed: () => _seekToSeconds(_currentTimestamp + 10),
                  ),
                ],
              ),
              Text(_formatTime(maxSeconds.toDouble())),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesTab(AsyncValue<List<Note>> notesAsync) {
    return Column(
      children: [
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
                  if (content.isEmpty || widget.videoId.isEmpty) return;
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
                              onPressed: () => _seekToSeconds(note.timestamp!),
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

  Widget _buildTranscriptTab(
    AsyncValue<Map<String, dynamic>?> transcriptAsync, {
    required String language,
  }) {
    return transcriptAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => ErrorStateView(
        error: error,
        prefix: 'Failed to load transcript',
        onRetry: () => ref.invalidate(
          activeTranscriptProvider(
            TranscriptArgs(
              youtubeVideoId: widget.videoId,
              language: language,
            ),
          ),
        ),
      ),
      data: (rawTranscript) {
        final entries = _parseTranscriptEntries(rawTranscript);
        if (entries.isEmpty) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.subtitles_off, size: 40, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text(
                      'No transcript available yet.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _isGeneratingTranscript
                          ? null
                          : () => _generateTranscript(language),
                      icon: _isGeneratingTranscript
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        _isGeneratingTranscript
                            ? 'Generating...'
                            : 'Generate Transcript',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final isActive = _currentTimestamp >= entry.startSeconds &&
                _currentTimestamp < entry.endSeconds;

            return Card(
              color: isActive
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _seekToSeconds(entry.startSeconds),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 58,
                        child: Text(
                          _formatTime(entry.startSeconds),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (entry.speaker != null &&
                                entry.speaker!.trim().isNotEmpty) ...[
                              Text(
                                entry.speaker!.trim(),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              const SizedBox(height: 4),
                            ],
                            Text(entry.text),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
            'In-app comments will appear here',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _effectiveTranscriptLanguage(UserSettings? settings) {
    final preferred = settings?.transcripts.defaultLanguage?.trim();
    if (preferred != null && preferred.isNotEmpty) {
      return preferred;
    }
    return 'en';
  }

  String _initialPlayerVideoId(String videoId) {
    if (videoId.length == 11) {
      return videoId;
    }
    // Stable fallback so the controller can initialize even before route state
    // resolves a valid video.
    return 'M7lc1UVf-VE';
  }

  YouTubeVideo? _findCurrentVideo(List<YouTubeVideo>? videos) {
    if (videos == null || videos.isEmpty || widget.videoId.isEmpty) {
      return null;
    }
    for (final video in videos) {
      if (video.youtubeVideoId == widget.videoId) {
        return video;
      }
    }
    return null;
  }

  int _resolvedDurationSeconds(YouTubeVideo? currentVideo) {
    final playerDuration = _playerController.metadata.duration.inSeconds;
    if (playerDuration > 0) {
      return playerDuration;
    }
    final parsed = parseDuration(currentVideo?.duration);
    if (parsed != null && parsed > 0) {
      return parsed;
    }
    return 0;
  }

  void _seekToSeconds(double seconds) {
    final duration = _playerController.metadata.duration.inSeconds;
    final max = duration > 0 ? duration.toDouble() : math.max(seconds, 0.0);
    final clamped = seconds.clamp(0, max).toDouble();
    setState(() => _currentTimestamp = clamped);

    if (_isPlayerReady) {
      _playerController.seekTo(
        Duration(milliseconds: (clamped * 1000).round()),
      );
    }
  }

  void _togglePlayPause() {
    if (!_isPlayerReady) {
      return;
    }
    if (_isPlaying) {
      _playerController.pause();
      _saveProgress();
    } else {
      _playerController.play();
    }
  }

  List<_TranscriptEntry> _parseTranscriptEntries(Map<String, dynamic>? transcript) {
    if (transcript == null) {
      return const <_TranscriptEntry>[];
    }
    final entriesRaw = transcript['entries'];
    if (entriesRaw is! List) {
      return const <_TranscriptEntry>[];
    }

    final entries = <_TranscriptEntry>[];
    for (final item in entriesRaw) {
      if (item is! Map) continue;
      final start = (item['start'] as num?)?.toDouble();
      final duration = (item['duration'] as num?)?.toDouble();
      final text = item['text']?.toString() ?? '';

      if (start == null || duration == null || text.trim().isEmpty) {
        continue;
      }

      entries.add(
        _TranscriptEntry(
          startSeconds: start,
          durationSeconds: duration,
          text: text.trim(),
          speaker: item['speaker']?.toString(),
        ),
      );
    }

    entries.sort((a, b) => a.startSeconds.compareTo(b.startSeconds));
    return entries;
  }

  Future<void> _generateTranscript(String language) async {
    if (_isGeneratingTranscript || widget.videoId.isEmpty) {
      return;
    }

    setState(() => _isGeneratingTranscript = true);
    try {
      await generateTranscript(
        ref,
        youtubeVideoId: widget.videoId,
        language: language,
      );
      ref.invalidate(
        activeTranscriptProvider(
          TranscriptArgs(youtubeVideoId: widget.videoId, language: language),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transcript generated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          error: e,
          prefix: 'Transcript generation failed',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingTranscript = false);
      }
    }
  }

  Future<List<YouTubeVideo>> _loadPlaylistQueue(String playlistId) async {
    final service = ref.read(convexServiceProvider);
    final raw = await service.query<dynamic>('youtube:getPlaylistVideos', {
      'playlistId': playlistId,
    });

    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is! List) {
      return const <YouTubeVideo>[];
    }

    final videos = <YouTubeVideo>[];
    for (final item in decoded) {
      if (item is Map<String, dynamic>) {
        videos.add(YouTubeVideo.fromJson(item));
      }
    }
    return videos;
  }

  Future<void> _showQueueDrawer(YouTubeVideo? currentVideo) async {
    if (currentVideo == null) {
      showErrorSnackBar(
        context,
        error: 'Current video metadata is not ready yet.',
        prefix: 'Queue unavailable',
      );
      return;
    }

    final currentVideoId = widget.videoId;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.65,
            child: FutureBuilder<List<YouTubeVideo>>(
              future: _loadPlaylistQueue(currentVideo.playlistId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: InlineErrorCard(
                        error: '${snapshot.error}',
                        prefix: 'Failed to load queue',
                      ),
                    ),
                  );
                }

                final queue = snapshot.data ?? const <YouTubeVideo>[];
                if (queue.isEmpty) {
                  return const Center(child: Text('No videos in this playlist.'));
                }

                return ListView.builder(
                  itemCount: queue.length,
                  itemBuilder: (context, index) {
                    final video = queue[index];
                    final isCurrent = video.youtubeVideoId == currentVideoId;
                    final durationSec = parseDuration(video.duration);

                    return ListTile(
                      leading: Icon(
                        isCurrent ? Icons.play_circle_filled : Icons.play_circle,
                        color: isCurrent
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                      title: Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        durationSec != null ? formatDuration(durationSec) : '',
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        if (!mounted) return;
                        this.context.go(
                          Uri(
                            path: Routes.play,
                            queryParameters: {'videoId': video.youtubeVideoId},
                          ).toString(),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showVideoOptions(YouTubeVideo? currentVideo) async {
    final videoId = currentVideo?.youtubeVideoId ?? widget.videoId;
    if (videoId.isEmpty) {
      showErrorSnackBar(
        context,
        error: 'Cannot resolve the current video id.',
        prefix: 'Options unavailable',
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Copy YouTube link'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final link = 'https://www.youtube.com/watch?v=$videoId';
                  await Clipboard.setData(ClipboardData(text: link));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('YouTube link copied.')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: const Text('Hide from library'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  try {
                    await hideVideo(ref, videoId);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Video hidden from library.')),
                    );
                    context.go(Routes.videos);
                  } catch (e) {
                    if (!mounted) return;
                    showErrorSnackBar(
                      context,
                      error: e,
                      prefix: 'Could not hide video',
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.report_outlined),
                title: const Text('Send feedback'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  if (!mounted) return;
                  context.go(Routes.feedback);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(double seconds) {
    final total = seconds.floor();
    final mins = total ~/ 60;
    final secs = total % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}
