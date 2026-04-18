import 'package:flutter/foundation.dart';

const legacyClerkPublishableKey = String.fromEnvironment(
  'NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY',
  defaultValue: '',
);

const clerkPublishableKey = String.fromEnvironment(
  'CLERK_PUBLISHABLE_KEY',
  defaultValue: legacyClerkPublishableKey,
);

const convexUrl = String.fromEnvironment('CONVEX_URL', defaultValue: '');

const legacyTubeFlowAppUrl = String.fromEnvironment(
  'TUBEFLOW_WEB_URL',
  defaultValue: '',
);

const tubeFlowAppUrl = String.fromEnvironment(
  'TUBEFLOW_APP_URL',
  defaultValue: legacyTubeFlowAppUrl,
);

const configuredClerkHostedSignInUrl = String.fromEnvironment(
  'CLERK_HOSTED_SIGN_IN_URL',
  defaultValue: '',
);

const buildCommitSha = String.fromEnvironment(
  'BUILD_COMMIT_SHA',
  defaultValue: 'unknown',
);

const buildEnvironment = String.fromEnvironment(
  'BUILD_ENVIRONMENT',
  defaultValue: 'unknown',
);

const buildTimestamp = String.fromEnvironment(
  'BUILD_TIMESTAMP',
  defaultValue: 'unknown',
);

String buildModeLabel() {
  if (kReleaseMode) return 'release';
  if (kProfileMode) return 'profile';
  return 'debug';
}

String maskValue(String value, {int head = 10, int tail = 5}) {
  if (value.isEmpty) return '(missing)';
  if (value.length <= head + tail + 3) return value;
  return '${value.substring(0, head)}...${value.substring(value.length - tail)}';
}

String hostForUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.isEmpty) {
    return 'invalid';
  }
  return uri.host;
}

String hostMatchLabel(String value) {
  if (!kIsWeb) {
    return 'not-web';
  }
  final host = hostForUrl(value);
  if (host == 'invalid') {
    return 'invalid';
  }
  return host == Uri.base.host ? 'yes' : 'no (expected $host)';
}

String clerkHostedSignInUrl() {
  if (configuredClerkHostedSignInUrl.isNotEmpty) {
    return configuredClerkHostedSignInUrl;
  }

  final fallbackBase = tubeFlowAppUrl.isNotEmpty
      ? tubeFlowAppUrl
      : (kIsWeb ? Uri.base.origin : '');
  final uri = Uri.tryParse(fallbackBase);
  if (uri == null || uri.host.isEmpty) {
    return '';
  }

  return uri
      .replace(
        scheme: uri.scheme.isEmpty ? 'https' : uri.scheme,
        host: 'accounts.${uri.host}',
        path: '/sign-in',
        query: null,
        fragment: null,
      )
      .toString();
}
