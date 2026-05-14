bool isMissingPublicConvexFunctionError(Object error, {String? path}) {
  final message = error.toString();
  if (!message.contains('Could not find public function for')) {
    return false;
  }
  return path == null || message.contains("'$path'");
}

bool isConvexUnauthorizedError(Object error) {
  return error.toString().contains('Unauthorized');
}
