class RecordedAudioUpload {
  const RecordedAudioUpload({
    required this.bytes,
    required this.contentType,
    required this.fileName,
  });

  final List<int> bytes;
  final String contentType;
  final String fileName;
}
