import 'package:tubeflow_app/widgets/youtube_oauth_popup_result.dart';

Future<YoutubeOAuthPopupResult> openYoutubeOauthPopup(Uri uri) async {
  return const YoutubeOAuthPopupResult(
    completed: false,
    connected: false,
    error: 'YouTube popup OAuth is only available on the web build.',
  );
}
