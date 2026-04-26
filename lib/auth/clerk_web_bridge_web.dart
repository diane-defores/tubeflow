import 'dart:convert';
import 'dart:js_interop';

@JS('tubeFlowClerkBridge')
external _TubeFlowClerkBridge get _bridge;

extension type _TubeFlowClerkBridge(JSObject _) implements JSObject {
  external JSPromise<JSBoolean> init(JSString publishableKey);
  external JSPromise<JSBoolean> isSignedIn(JSString publishableKey);
  external JSPromise<JSString> getUserJson(JSString publishableKey);
  external JSPromise<JSString> getToken(
    JSString publishableKey,
    JSString template,
  );
  external JSPromise<JSString> buildSignInUrl(
    JSString publishableKey,
    JSString redirectUrl,
  );
  external JSPromise<JSBoolean> openSignIn(
    JSString publishableKey,
    JSString redirectUrl,
  );
  external JSPromise<JSBoolean> startGoogleSignIn(
    JSString publishableKey,
    JSString redirectUrl,
    JSString redirectUrlComplete,
  );
  external JSPromise<JSBoolean> handleOAuthRedirect(
    JSString publishableKey,
    JSString redirectUrlComplete,
  );
  external JSPromise<JSBoolean> prepareSessionCookie(JSString publishableKey);
  external JSPromise<JSBoolean> signOut(JSString publishableKey);
  external JSPromise<JSBoolean> resetState(JSString publishableKey);
}

class ClerkWebUser {
  const ClerkWebUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.imageUrl,
  });

  final String id;
  final String email;
  final String displayName;
  final String imageUrl;

  factory ClerkWebUser.fromJson(Map<String, dynamic> json) {
    return ClerkWebUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
    );
  }
}

String? _publishableKey;

Future<void> initClerkWebBridge(String publishableKey) async {
  _publishableKey = publishableKey;
  await _bridge.init(publishableKey.toJS).toDart;
}

Future<bool> clerkWebIsSignedIn() async {
  final key = _publishableKey;
  if (key == null || key.isEmpty) return false;
  return (await _bridge.isSignedIn(key.toJS).toDart).toDart;
}

Future<ClerkWebUser?> clerkWebGetUser() async {
  final key = _publishableKey;
  if (key == null || key.isEmpty) return null;
  final jsonString = (await _bridge.getUserJson(key.toJS).toDart).toDart;
  if (jsonString.isEmpty) return null;
  return ClerkWebUser.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
}

Future<String?> clerkWebGetToken({String? template}) async {
  final key = _publishableKey;
  if (key == null || key.isEmpty) return null;
  final token =
      (await _bridge.getToken(key.toJS, (template ?? '').toJS).toDart).toDart;
  return token.isEmpty ? null : token;
}

Future<String?> clerkWebBuildSignInUrl(String redirectUrl) async {
  final key = _publishableKey;
  if (key == null || key.isEmpty) return null;
  final url =
      (await _bridge.buildSignInUrl(key.toJS, redirectUrl.toJS).toDart).toDart;
  return url.isEmpty ? null : url;
}

Future<bool> clerkWebStartGoogleSignIn({
  required String redirectUrl,
  required String redirectUrlComplete,
}) async {
  final key = _publishableKey;
  if (key == null || key.isEmpty) return false;
  return (await _bridge
          .startGoogleSignIn(
            key.toJS,
            redirectUrl.toJS,
            redirectUrlComplete.toJS,
          )
          .toDart)
      .toDart;
}

Future<bool> clerkWebHandleOAuthRedirect(String redirectUrlComplete) async {
  final key = _publishableKey;
  if (key == null || key.isEmpty) return false;
  return (await _bridge
          .handleOAuthRedirect(key.toJS, redirectUrlComplete.toJS)
          .toDart)
      .toDart;
}

Future<bool> clerkWebPrepareSessionCookie() async {
  final key = _publishableKey;
  if (key == null || key.isEmpty) return false;
  return (await _bridge.prepareSessionCookie(key.toJS).toDart).toDart;
}

Future<bool> clerkWebOpenSignIn(String redirectUrl) async {
  final key = _publishableKey;
  if (key == null || key.isEmpty) return false;
  return (await _bridge.openSignIn(key.toJS, redirectUrl.toJS).toDart).toDart;
}

Future<void> clerkWebSignOut() async {
  final key = _publishableKey;
  if (key == null || key.isEmpty) return;
  await _bridge.signOut(key.toJS).toDart;
}

Future<bool> clerkWebResetState() async {
  final key = _publishableKey;
  if (key == null || key.isEmpty) return false;
  return (await _bridge.resetState(key.toJS).toDart).toDart;
}
