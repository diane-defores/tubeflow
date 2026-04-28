import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'feedback_audio_types.dart';

Future<String> createFeedbackRecordingPath() async {
  final directory = await getTemporaryDirectory();
  return '${directory.path}/feedback-${DateTime.now().millisecondsSinceEpoch}.wav';
}

Future<RecordedAudioUpload> readRecordedAudioUpload(String pathOrUrl) async {
  final file = File(pathOrUrl);
  final bytes = await file.readAsBytes();
  final fileName = file.uri.pathSegments.isNotEmpty
      ? file.uri.pathSegments.last
      : 'feedback.wav';

  return RecordedAudioUpload(
    bytes: bytes,
    contentType: 'audio/wav',
    fileName: fileName,
  );
}

Future<void> cleanupFeedbackRecording(String pathOrUrl) async {
  final file = File(pathOrUrl);
  if (await file.exists()) {
    await file.delete();
  }
}
