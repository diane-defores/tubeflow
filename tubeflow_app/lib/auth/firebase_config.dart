import 'package:firebase_core/firebase_core.dart';

const firebaseApiKey = String.fromEnvironment(
  'FIREBASE_API_KEY',
  defaultValue: '',
);

const firebaseAuthDomain = String.fromEnvironment(
  'FIREBASE_AUTH_DOMAIN',
  defaultValue: '',
);

const firebaseProjectId = String.fromEnvironment(
  'FIREBASE_PROJECT_ID',
  defaultValue: '',
);

const firebaseStorageBucket = String.fromEnvironment(
  'FIREBASE_STORAGE_BUCKET',
  defaultValue: '',
);

const firebaseMessagingSenderId = String.fromEnvironment(
  'FIREBASE_MESSAGING_SENDER_ID',
  defaultValue: '',
);

const firebaseAppId = String.fromEnvironment(
  'FIREBASE_APP_ID',
  defaultValue: '',
);

bool get hasFirebaseConfig =>
    firebaseApiKey.isNotEmpty &&
    firebaseProjectId.isNotEmpty &&
    firebaseMessagingSenderId.isNotEmpty &&
    firebaseAppId.isNotEmpty;

FirebaseOptions? firebaseOptions() {
  if (!hasFirebaseConfig) return null;

  return FirebaseOptions(
    apiKey: firebaseApiKey,
    appId: firebaseAppId,
    messagingSenderId: firebaseMessagingSenderId,
    projectId: firebaseProjectId,
    authDomain: firebaseAuthDomain.isEmpty ? null : firebaseAuthDomain,
    storageBucket: firebaseStorageBucket.isEmpty ? null : firebaseStorageBucket,
  );
}
