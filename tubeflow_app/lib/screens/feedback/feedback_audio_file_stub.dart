import 'feedback_audio_types.dart';

Future<String> createFeedbackRecordingPath() async {
  throw UnsupportedError('Recording is not supported on this platform');
}

Future<RecordedAudioUpload> readRecordedAudioUpload(String pathOrUrl) async {
  throw UnsupportedError('Recording upload is not supported on this platform');
}

Future<void> cleanupFeedbackRecording(String pathOrUrl) async {}
