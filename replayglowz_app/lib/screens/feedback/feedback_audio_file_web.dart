import 'package:http/http.dart' as http;

import 'feedback_audio_types.dart';

Future<String> createFeedbackRecordingPath() async => '';

Future<RecordedAudioUpload> readRecordedAudioUpload(String pathOrUrl) async {
  final response = await http.get(Uri.parse(pathOrUrl));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError('Could not read recorded audio blob');
  }

  return RecordedAudioUpload(
    bytes: response.bodyBytes,
    contentType: 'audio/wav',
    fileName: 'feedback-${DateTime.now().millisecondsSinceEpoch}.wav',
  );
}

Future<void> cleanupFeedbackRecording(String pathOrUrl) async {}
