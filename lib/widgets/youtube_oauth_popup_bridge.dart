import 'package:tubeflow_app/widgets/youtube_oauth_popup_result.dart';

import 'youtube_oauth_popup_bridge_stub.dart'
    if (dart.library.js_interop) 'youtube_oauth_popup_bridge_web.dart' as impl;

Future<YoutubeOAuthPopupResult> openYoutubeOauthPopup(Uri uri) {
  return impl.openYoutubeOauthPopup(uri);
}
