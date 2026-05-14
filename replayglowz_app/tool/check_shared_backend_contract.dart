import 'dart:io';

const _requiredFunctions = <String>[
  'users:ensureUser',
  'users:getCurrentUser',
  'settings:getSettings',
  'subscriptions:getSubscription',
  'youtube:getYoutubeConnectionStatus',
  'feedback:isAdmin',
  'feedback:listAdmin',
  'notifications:getNotifications',
  'notifications:getUnreadCount',
];

void main() {
  final backendRoot = _resolveBackendRoot();
  if (!backendRoot.existsSync()) {
    stderr.writeln(
      'Shared backend not found at ${backendRoot.path}.\n'
      'Set REPLAYGLOWZ_BACKEND_ROOT to the Convex backend directory if needed.',
    );
    exitCode = 1;
    return;
  }

  final missing = <String>[];

  for (final functionPath in _requiredFunctions) {
    final parts = functionPath.split(':');
    final moduleName = parts.first;
    final exportName = parts.last;
    final file = File('${backendRoot.path}/$moduleName.ts');
    if (!file.existsSync()) {
      missing.add('$functionPath (missing file ${file.path})');
      continue;
    }

    final source = file.readAsStringSync();
    final expectedExport = 'export const $exportName =';
    if (!source.contains(expectedExport)) {
      missing.add('$functionPath (missing `$expectedExport`)');
    }
  }

  if (missing.isEmpty) {
    stdout.writeln(
      'Shared backend contract OK: ${_requiredFunctions.length} critical '
      'Flutter functions found in ${backendRoot.path}',
    );
    return;
  }

  stderr.writeln('Shared backend contract check failed:');
  for (final item in missing) {
    stderr.writeln('- $item');
  }
  exitCode = 1;
}

Directory _resolveBackendRoot() {
  final fromEnv =
      Platform.environment['REPLAYGLOWZ_BACKEND_ROOT'] ??
      Platform.environment['TUBEFLOW_BACKEND_ROOT'];
  if (fromEnv != null && fromEnv.trim().isNotEmpty) {
    return Directory(fromEnv.trim());
  }

  final cwd = Directory.current.uri;
  return Directory.fromUri(
    cwd.resolve('../tubeflow_expo/packages/backend/convex'),
  );
}
