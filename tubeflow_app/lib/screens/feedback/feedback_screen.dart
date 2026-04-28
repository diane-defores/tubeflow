import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';

import 'package:tubeflow_app/auth/auth_state.dart';
import 'package:tubeflow_app/providers/providers.dart';
import 'package:tubeflow_app/screens/feedback/feedback_audio_file.dart';
import 'package:tubeflow_app/screens/feedback/feedback_service.dart';
import 'package:tubeflow_app/utils/duration_utils.dart';
import 'package:tubeflow_app/widgets/error_feedback.dart';

enum _FeedbackComposerMode { text, audio }

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  static const _maxAudioDurationMs = 120000;

  final _messageController = TextEditingController();
  final _recorder = AudioRecorder();
  final _stopwatch = Stopwatch();

  Timer? _draftDebounce;
  Timer? _recordingTicker;
  _FeedbackComposerMode _mode = _FeedbackComposerMode.text;
  bool _draftLoaded = false;
  bool _submitting = false;
  bool _recording = false;
  bool _stoppingRecording = false;
  Duration _recordingDuration = Duration.zero;
  String? _recordingPath;
  String? _successNotice;

  FeedbackSubmissionService get _service => FeedbackSubmissionService(ref);

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    _recordingTicker?.cancel();
    _messageController.dispose();
    _recorder.dispose();
    unawaited(_cleanupRecording());
    super.dispose();
  }

  Future<void> _loadDraft() async {
    final draft = await _service.loadTextDraft();
    if (!mounted) return;
    _messageController.text = draft;
    setState(() => _draftLoaded = true);
  }

  Future<void> _scheduleDraftSave(String value) async {
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_service.saveTextDraft(value));
    });
  }

  String _effectiveLocale() {
    final settings = ref.read(settingsProvider).asData?.value;
    final preferred = settings?.language?.trim();
    if (preferred != null && preferred.isNotEmpty) {
      return preferred;
    }
    return Localizations.localeOf(context).languageCode;
  }

  Future<void> _startRecording() async {
    try {
      final granted = await _recorder.hasPermission();
      if (!granted) {
        throw StateError(
          'Microphone permission is required for audio feedback.',
        );
      }

      await _cleanupRecording();

      final recordingPath = await createFeedbackRecordingPath();
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: recordingPath,
      );

      _stopwatch
        ..reset()
        ..start();

      _recordingTicker?.cancel();
      _recordingTicker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        final elapsed = _stopwatch.elapsed;
        if (!mounted) return;
        setState(() {
          _recordingDuration = elapsed;
        });
        if (elapsed.inMilliseconds >= _maxAudioDurationMs) {
          unawaited(_stopRecording(autoStopped: true));
        }
      });

      setState(() {
        _recording = true;
        _recordingPath = null;
        _recordingDuration = Duration.zero;
        _successNotice = null;
      });
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, error: e, prefix: 'Audio recording failed');
      }
    }
  }

  Future<void> _stopRecording({bool autoStopped = false}) async {
    if (!_recording || _stoppingRecording) return;

    setState(() => _stoppingRecording = true);

    try {
      final path = await _recorder.stop();
      _stopwatch.stop();
      _recordingTicker?.cancel();

      if (path == null || path.isEmpty) {
        throw StateError('No audio file was produced.');
      }

      if (!mounted) return;
      setState(() {
        _recording = false;
        _recordingPath = path;
        _recordingDuration = _stopwatch.elapsed;
        _successNotice = autoStopped
            ? 'Recording stopped at 2 minutes. You can send it now.'
            : null;
      });
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, error: e, prefix: 'Could not stop recording');
      }
    } finally {
      if (mounted) {
        setState(() => _stoppingRecording = false);
      }
    }
  }

  Future<void> _cleanupRecording() async {
    _recordingTicker?.cancel();
    _stopwatch.stop();
    if (_recording) {
      await _recorder.cancel();
    }
    final existingPath = _recordingPath;
    if (existingPath != null && existingPath.isNotEmpty) {
      await cleanupFeedbackRecording(existingPath);
    }
    _recording = false;
    _recordingPath = null;
    _recordingDuration = Duration.zero;
  }

  Future<void> _submitText() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _submitting = true;
      _successNotice = null;
    });

    try {
      await _service.submitText(
        message: message,
        locale: _effectiveLocale(),
      );
      if (!mounted) return;
      _messageController.clear();
      setState(() {
        _successNotice = 'Feedback sent. Thank you.';
      });
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, error: e, prefix: 'Feedback submission failed');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _submitAudio() async {
    final recordingPath = _recordingPath;
    if (recordingPath == null || recordingPath.isEmpty) return;

    setState(() {
      _submitting = true;
      _successNotice = null;
    });

    try {
      await _service.submitAudio(
        recordingPath: recordingPath,
        durationMs: _recordingDuration.inMilliseconds,
        locale: _effectiveLocale(),
        message: _messageController.text,
      );
      if (!mounted) return;
      _messageController.clear();
      setState(() {
        _recordingPath = null;
        _recordingDuration = Duration.zero;
        _successNotice = 'Audio feedback sent. Thank you.';
      });
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          error: e,
          prefix: 'Audio feedback submission failed',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final settings = ref.watch(settingsProvider).asData?.value;
    final locale =
        settings?.language?.trim().isNotEmpty == true
        ? settings!.language!.trim()
        : Localizations.localeOf(context).languageCode;
    final canSendText = !_submitting && _messageController.text.trim().isNotEmpty;
    final canSendAudio =
        !_submitting &&
        !_recording &&
        _recordingPath != null &&
        _recordingDuration.inMilliseconds > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Feedback'),
        actions: [
          if (GoRouter.of(context).canPop())
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Close',
              onPressed: () => context.pop(),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tell us what is working, what is broken, or what you want next.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        authState is AuthAuthenticated
                            ? 'Your feedback will be attached to ${authState.user.email}.'
                            : 'You can send feedback anonymously even without signing in.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<_FeedbackComposerMode>(
                        segments: const [
                          ButtonSegment<_FeedbackComposerMode>(
                            value: _FeedbackComposerMode.text,
                            icon: Icon(Icons.text_fields),
                            label: Text('Text'),
                          ),
                          ButtonSegment<_FeedbackComposerMode>(
                            value: _FeedbackComposerMode.audio,
                            icon: Icon(Icons.mic_none),
                            label: Text('Audio'),
                          ),
                        ],
                        selected: {_mode},
                        onSelectionChanged: _submitting
                            ? null
                            : (selection) {
                                setState(() => _mode = selection.first);
                              },
                      ),
                      const SizedBox(height: 20),
                      if (_mode == _FeedbackComposerMode.text) ...[
                        TextField(
                          controller: _messageController,
                          minLines: 6,
                          maxLines: 10,
                          decoration: const InputDecoration(
                            labelText: 'What do you want to tell us?',
                            alignLabelWithHint: true,
                            hintText:
                                'Example: The play screen loses my position after refresh...',
                          ),
                          onChanged: _scheduleDraftSave,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: canSendText ? _submitText : null,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send),
                          label: Text(
                            _submitting ? 'Sending…' : 'Send feedback',
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _recording
                                    ? 'Recording in progress'
                                    : _recordingPath != null
                                    ? 'Audio ready to send'
                                    : 'Record a short voice note',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Duration: ${formatDuration(_recordingDuration.inSeconds)} / 2:00',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  FilledButton.icon(
                                    onPressed: _submitting || _recording
                                        ? null
                                        : _startRecording,
                                    icon: const Icon(Icons.mic),
                                    label: const Text('Record'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _recording && !_stoppingRecording
                                        ? () => _stopRecording()
                                        : null,
                                    icon: const Icon(Icons.stop_circle_outlined),
                                    label: Text(
                                      _stoppingRecording
                                          ? 'Stopping…'
                                          : 'Stop',
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _submitting ||
                                            (_recordingPath == null &&
                                                !_recording)
                                        ? null
                                        : () async {
                                            await _cleanupRecording();
                                            if (mounted) {
                                              setState(() {
                                                _successNotice = null;
                                              });
                                            }
                                          },
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Discard'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _messageController,
                          minLines: 4,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            labelText: 'Add context (optional)',
                            alignLabelWithHint: true,
                            hintText:
                                'Example: This happened after opening a playlist from the sidebar.',
                          ),
                          onChanged: _scheduleDraftSave,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: canSendAudio ? _submitAudio : null,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.cloud_upload_outlined),
                          label: Text(
                            _submitting ? 'Uploading…' : 'Send audio feedback',
                          ),
                        ),
                      ],
                      if (_successNotice != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _successNotice!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (_draftLoaded && _messageController.text.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Draft saved locally. Current locale: $locale.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
