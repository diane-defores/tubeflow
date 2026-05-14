import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tubeflow_app/app/build_info.dart';
import 'package:tubeflow_app/providers/mutations.dart';
import 'package:tubeflow_app/screens/feedback/feedback_audio_file.dart';

const feedbackTextDraftKey = 'replayglowz_feedback_text_draft';
const legacyFeedbackTextDraftKey = 'tubeflow_feedback_text_draft';

class FeedbackSubmissionService {
  const FeedbackSubmissionService(this.ref);

  final WidgetRef ref;

  Future<String> loadTextDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString(feedbackTextDraftKey);
    if (current != null) return current;

    final legacy = prefs.getString(legacyFeedbackTextDraftKey);
    if (legacy == null) return '';

    await prefs.setString(feedbackTextDraftKey, legacy);
    await prefs.remove(legacyFeedbackTextDraftKey);
    return legacy;
  }

  Future<void> saveTextDraft(String value) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(feedbackTextDraftKey);
      await prefs.remove(legacyFeedbackTextDraftKey);
      return;
    }
    await prefs.setString(feedbackTextDraftKey, value);
    await prefs.remove(legacyFeedbackTextDraftKey);
  }

  Future<void> clearTextDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(feedbackTextDraftKey);
    await prefs.remove(legacyFeedbackTextDraftKey);
  }

  Future<void> submitText({
    required String message,
    required String locale,
  }) async {
    await createFeedbackText(
      ref,
      message: message.trim(),
      platform: _platform,
      locale: locale.trim().isEmpty ? 'en' : locale.trim(),
      buildCommitSha: _buildValue(buildCommitSha),
      buildEnvironment: _buildValue(buildEnvironment),
      buildTimestamp: _buildValue(buildTimestamp),
    );

    await clearTextDraft();
  }

  Future<void> submitAudio({
    required String recordingPath,
    required int durationMs,
    required String locale,
    String? message,
  }) async {
    final uploadData = await readRecordedAudioUpload(recordingPath);
    final uploadUrl = await getFeedbackUploadUrl(ref);

    final uploadResponse = await http.post(
      Uri.parse(uploadUrl),
      headers: {
        'Content-Type': uploadData.contentType,
        'X-Requested-With': 'ReplayGlowzFeedback',
      },
      body: uploadData.bytes,
    );

    if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
      throw StateError(
        'Feedback audio upload failed (${uploadResponse.statusCode})',
      );
    }

    final decoded = jsonDecode(uploadResponse.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Feedback audio upload response is invalid');
    }

    final storageId = decoded['storageId'] as String?;
    if (storageId == null || storageId.isEmpty) {
      throw StateError('Feedback audio upload did not return a storageId');
    }

    await createFeedbackAudio(
      ref,
      audioStorageId: storageId,
      audioDurationMs: durationMs,
      platform: _platform,
      locale: locale.trim().isEmpty ? 'en' : locale.trim(),
      message: message?.trim().isEmpty == true ? null : message?.trim(),
      buildCommitSha: _buildValue(buildCommitSha),
      buildEnvironment: _buildValue(buildEnvironment),
      buildTimestamp: _buildValue(buildTimestamp),
    );

    await clearTextDraft();
    await cleanupFeedbackRecording(recordingPath);
  }

  String get _platform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      default:
        return 'other';
    }
  }

  String? _buildValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == 'unknown') {
      return null;
    }
    return trimmed;
  }
}
