import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'package:tubeflow_app/models/models.dart';
import 'package:tubeflow_app/providers/mutations.dart';
import 'package:tubeflow_app/providers/providers.dart';
import 'package:tubeflow_app/utils/date_utils.dart';
import 'package:tubeflow_app/utils/duration_utils.dart';
import 'package:tubeflow_app/widgets/error_feedback.dart';

enum _FeedbackAdminFilter {
  all,
  unread,
  text,
  audio;

  FeedbackAdminListArgs get args {
    switch (this) {
      case _FeedbackAdminFilter.all:
        return const FeedbackAdminListArgs();
      case _FeedbackAdminFilter.unread:
        return const FeedbackAdminListArgs(
          status: FeedbackEntryStatus.newEntry,
        );
      case _FeedbackAdminFilter.text:
        return const FeedbackAdminListArgs(type: FeedbackEntryType.text);
      case _FeedbackAdminFilter.audio:
        return const FeedbackAdminListArgs(type: FeedbackEntryType.audio);
    }
  }

  String get label {
    switch (this) {
      case _FeedbackAdminFilter.all:
        return 'All';
      case _FeedbackAdminFilter.unread:
        return 'Unread';
      case _FeedbackAdminFilter.text:
        return 'Text';
      case _FeedbackAdminFilter.audio:
        return 'Audio';
    }
  }
}

class FeedbackAdminScreen extends ConsumerStatefulWidget {
  const FeedbackAdminScreen({super.key});

  @override
  ConsumerState<FeedbackAdminScreen> createState() =>
      _FeedbackAdminScreenState();
}

class _FeedbackAdminScreenState extends ConsumerState<FeedbackAdminScreen> {
  final _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSub;
  _FeedbackAdminFilter _filter = _FeedbackAdminFilter.all;
  String? _activeAudioId;
  String? _loadingAudioId;
  final Set<String> _reviewingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _playerStateSub = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        unawaited(_player.seek(Duration.zero));
        unawaited(_player.pause());
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback(FeedbackEntry entry) async {
    if (!entry.hasAudio || entry.audioUrl == null) return;

    try {
      setState(() => _loadingAudioId = entry.id);

      if (_activeAudioId == entry.id) {
        if (_player.playing) {
          await _player.pause();
        } else {
          await _player.play();
        }
        return;
      }

      await _player.stop();
      await _player.setUrl(entry.audioUrl!);
      _activeAudioId = entry.id;
      await _player.play();
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, error: e, prefix: 'Audio playback failed');
      }
    } finally {
      if (mounted) {
        setState(() => _loadingAudioId = null);
      }
    }
  }

  Future<void> _markReviewed(String feedbackId) async {
    setState(() => _reviewingIds.add(feedbackId));
    try {
      await markFeedbackReviewed(ref, feedbackId);
      ref.invalidate(feedbackAdminEntriesProvider);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          error: e,
          prefix: 'Could not mark feedback as reviewed',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _reviewingIds.remove(feedbackId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final isAdminAsync = ref.watch(feedbackIsAdminProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Feedback Admin')),
      body: isAdminAsync.when(
        data: (isAdmin) {
          if (!isAdmin) {
            return const Center(
              child: Text(
                'Access denied. This screen is restricted to admins.',
              ),
            );
          }

          final entriesAsync = ref.watch(
            feedbackAdminEntriesProvider(_filter.args),
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final filter in _FeedbackAdminFilter.values)
                      ChoiceChip(
                        label: Text(filter.label),
                        selected: _filter == filter,
                        onSelected: (_) {
                          setState(() => _filter = filter);
                        },
                      ),
                  ],
                ),
              ),
              Expanded(
                child: entriesAsync.when(
                  data: (entries) {
                    if (entries.isEmpty) {
                      return const Center(
                        child: Text('No feedback entries match this filter.'),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final isPlaying =
                            _activeAudioId == entry.id && _player.playing;
                        final isLoadingAudio = _loadingAudioId == entry.id;
                        final isReviewing = _reviewingIds.contains(entry.id);
                        final subtitle =
                            entry.message?.trim().isNotEmpty == true
                            ? entry.message!.trim()
                            : entry.type == FeedbackEntryType.audio
                            ? 'Audio feedback'
                            : 'No message';
                        final meta = [
                          formatDateTime(entry.createdAt, locale: locale),
                          entry.platform,
                          entry.locale,
                          entry.isAnonymous ? 'Anonymous' : entry.userEmail!,
                          if (entry.buildCommitShort != null)
                            'build ${entry.buildCommitShort}',
                        ].join(' • ');

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              Chip(
                                                label: Text(entry.type.name),
                                              ),
                                              Chip(
                                                label: Text(
                                                  entry.isUnread
                                                      ? 'Unread'
                                                      : 'Reviewed',
                                                ),
                                              ),
                                              if (entry.audioDurationMs != null)
                                                Chip(
                                                  label: Text(
                                                    formatDuration(
                                                      (entry.audioDurationMs! /
                                                              1000)
                                                          .round(),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            subtitle,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            meta,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                          if (!entry.isUnread &&
                                              entry.reviewedByEmail != null &&
                                              entry.reviewedAt != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: Text(
                                                'Reviewed by ${entry.reviewedByEmail} on ${formatDateTime(entry.reviewedAt, locale: locale)}',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (entry.hasAudio)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 12,
                                        ),
                                        child: IconButton.filledTonal(
                                          onPressed: isLoadingAudio
                                              ? null
                                              : () => _togglePlayback(entry),
                                          icon: isLoadingAudio
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : Icon(
                                                  isPlaying
                                                      ? Icons.pause
                                                      : Icons.play_arrow,
                                                ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (entry.isUnread) ...[
                                  const SizedBox(height: 16),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: FilledButton.tonalIcon(
                                      onPressed: isReviewing
                                          ? null
                                          : () => _markReviewed(entry.id),
                                      icon: isReviewing
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.done),
                                      label: Text(
                                        isReviewing
                                            ? 'Updating…'
                                            : 'Mark as read',
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => ErrorStateView(
                    error: error,
                    prefix: 'Failed to load feedback admin entries',
                    onRetry: () => ref.invalidate(feedbackAdminEntriesProvider),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => ErrorStateView(
          error: error,
          prefix: 'Failed to resolve admin access',
          onRetry: () => ref.invalidate(feedbackIsAdminProvider),
        ),
      ),
    );
  }
}
