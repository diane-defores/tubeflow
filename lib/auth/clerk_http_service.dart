import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:http/http.dart' as http;

import 'clerk_http_client_factory.dart'
    if (dart.library.js_interop) 'clerk_http_client_factory_web.dart';

class ClerkHttpService implements clerk.HttpService {
  ClerkHttpService();

  late final http.Client _client = createClerkHttpClient();

  @override
  Future<void> initialize() async {}

  @override
  void terminate() {
    _client.close();
  }

  @override
  Future<bool> ping(Uri uri, {required Duration timeout}) async {
    try {
      final result = await _client.head(uri).timeout(timeout);
      return result.statusCode == 200;
    } on Exception {
      return false;
    }
  }

  @override
  Future<http.Response> send(
    clerk.HttpMethod method,
    Uri uri, {
    Map<String, String>? headers,
    Map<String, dynamic>? params,
    String? body,
  }) async {
    final request = http.Request(method.toString(), uri);

    if (headers != null) {
      request.headers.addAll(headers);
    }

    if (params != null) {
      request.bodyFields = params.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      );
    }

    if (body != null) {
      request.body = body;
    }

    final streamedResponse = await _client.send(request);
    return http.Response.fromStream(streamedResponse);
  }

  @override
  Future<http.Response> sendByteStream(
    clerk.HttpMethod method,
    Uri uri,
    http.ByteStream byteStream,
    int length,
    Map<String, String> headers,
  ) async {
    final request = http.MultipartRequest(method.toString(), uri);
    request.headers.addAll(headers);
    request.files.add(
      http.MultipartFile(
        'file',
        byteStream,
        length,
        filename: byteStream.hashCode.toString(),
      ),
    );

    final streamedResponse = await _client.send(request);
    return http.Response.fromStream(streamedResponse);
  }
}
