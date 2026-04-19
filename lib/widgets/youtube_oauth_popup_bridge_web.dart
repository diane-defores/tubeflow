import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:tubeflow_app/widgets/youtube_oauth_popup_result.dart';

const _popupName = 'tubeflow_youtube_oauth';

Future<YoutubeOAuthPopupResult> openYoutubeOauthPopup(Uri uri) async {
  final popup = html.window.open(
    uri.toString(),
    _popupName,
    'popup=yes,width=520,height=760,menubar=no,toolbar=no,location=yes,resizable=yes,scrollbars=yes,status=no',
  );

  if (popup == null) {
    return const YoutubeOAuthPopupResult(
      completed: false,
      connected: false,
      error:
          'TubeFlow could not open the YouTube OAuth window. Allow pop-ups for this site, then retry.',
    );
  }

  final completer = Completer<YoutubeOAuthPopupResult>();
  StreamSubscription<html.MessageEvent>? messageSubscription;
  Timer? closePollTimer;

  void finish(YoutubeOAuthPopupResult result) {
    if (completer.isCompleted) return;
    messageSubscription?.cancel();
    closePollTimer?.cancel();
    completer.complete(result);
  }

  messageSubscription = html.window.onMessage.listen((event) {
    if (event.origin != html.window.location.origin) {
      return;
    }

    final data = event.data;
    if (data is! String || data.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      if (decoded['source'] != 'tubeflow-youtube-oauth') {
        return;
      }

      finish(
        YoutubeOAuthPopupResult(
          completed: true,
          connected: decoded['connected'] == true,
          error: decoded['error'] as String?,
        ),
      );
    } catch (_) {
      // Ignore unrelated postMessage payloads.
    }
  });

  closePollTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
    if (popup.closed == true) {
      finish(
        const YoutubeOAuthPopupResult(
          completed: false,
          connected: false,
          closed: true,
        ),
      );
    }
  });

  return completer.future.timeout(
    const Duration(minutes: 5),
    onTimeout: () => const YoutubeOAuthPopupResult(
      completed: false,
      connected: false,
      error: 'TubeFlow timed out while waiting for the YouTube OAuth window.',
    ),
  );
}
