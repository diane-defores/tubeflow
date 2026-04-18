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

Future<void> clerkWebSignOut() async {}
