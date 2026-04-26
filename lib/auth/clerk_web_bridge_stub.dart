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
}

Future<void> initClerkWebBridge(String publishableKey) async {}

Future<bool> clerkWebIsSignedIn() async => false;

Future<ClerkWebUser?> clerkWebGetUser() async => null;

Future<String?> clerkWebGetToken({String? template}) async => null;

Future<String?> clerkWebBuildSignInUrl(String redirectUrl) async => null;

Future<bool> clerkWebOpenSignIn(String redirectUrl) async => false;

Future<bool> clerkWebStartGoogleSignIn({
  required String redirectUrl,
  required String redirectUrlComplete,
}) async => false;

Future<bool> clerkWebHandleOAuthRedirect(String redirectUrlComplete) async =>
    false;

Future<bool> clerkWebPrepareSessionCookie() async => false;

Future<void> clerkWebSignOut() async {}

Future<bool> clerkWebResetState() async => false;

Future<String> clerkWebDebugLog() async => '';
