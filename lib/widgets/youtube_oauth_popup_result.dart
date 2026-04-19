class YoutubeOAuthPopupResult {
  const YoutubeOAuthPopupResult({
    required this.completed,
    required this.connected,
    this.error,
    this.closed = false,
  });

  final bool completed;
  final bool connected;
  final String? error;
  final bool closed;

  bool get hasError => error != null && error!.isNotEmpty;
}
