import 'feedback_audio_types.dart';
import 'feedback_audio_file_stub.dart'
    if (dart.library.html) 'feedback_audio_file_web.dart'
    if (dart.library.io) 'feedback_audio_file_io.dart' as platform;

Future<String> createFeedbackRecordingPath() {
  return platform.createFeedbackRecordingPath();
}

Future<RecordedAudioUpload> readRecordedAudioUpload(String pathOrUrl) {
  return platform.readRecordedAudioUpload(pathOrUrl);
}

Future<void> cleanupFeedbackRecording(String pathOrUrl) {
  return platform.cleanupFeedbackRecording(pathOrUrl);
}
