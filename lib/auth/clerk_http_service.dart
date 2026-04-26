import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:io' show HttpHeaders;

import 'clerk_http_client_factory.dart'
    if (dart.library.js_interop) 'clerk_http_client_factory_web.dart';
import 'package:tubeflow_app/utils/app_logger.dart';

class ClerkHttpService implements clerk.HttpService {
  ClerkHttpService();

  late final http.Client _client = createClerkHttpClient();
  static const _nativeFlag = '_is_native';
  static const _clerkApiVersionHeader = 'clerk-api-version';
  static const _clerkClientIdHeader = 'x-clerk-client-id';
  static const _flutterSdkHeader = 'x-flutter-sdk-version';
  static const _mobileHeader = 'x-mobile';

  @override
  Future<void> initialize() async {}

  @override
  void terminate() {
    _client.close();
  }

  @override
  Future<bool> ping(Uri uri, {required Duration timeout}) async {
    if (kIsWeb) {
      try {
        final probe = uri.replace(path: '/v1/environment');
        final result = await _client.get(probe).timeout(timeout);
        return result.statusCode >= 200 && result.statusCode < 500;
      } on Exception {
        return false;
      }
    }

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
    final effectiveUri = _normalizeUri(uri);
    final request = http.Request(method.toString(), effectiveUri);
    final effectiveHeaders = _normalizeHeaders(method, headers);

    if (effectiveHeaders != null) {
      request.headers.addAll(effectiveHeaders);
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
    final response = await http.Response.fromStream(streamedResponse);
    _logHttpFailureIfNeeded(method, effectiveUri, response);
    return response;
  }

  @override
  Future<http.Response> sendByteStream(
    clerk.HttpMethod method,
    Uri uri,
    http.ByteStream byteStream,
    int length,
    Map<String, String> headers,
  ) async {
    final effectiveUri = _normalizeUri(uri);
    final request = http.MultipartRequest(method.toString(), effectiveUri);
    request.headers.addAll(_normalizeHeaders(method, headers) ?? const {});
    request.files.add(
      http.MultipartFile(
        'file',
        byteStream,
        length,
        filename: byteStream.hashCode.toString(),
      ),
    );

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    _logHttpFailureIfNeeded(method, effectiveUri, response);
    return response;
  }

  Uri _normalizeUri(Uri uri) {
    if (!kIsWeb || !uri.queryParameters.containsKey(_nativeFlag)) {
      return uri;
    }

    final updatedParameters = Map<String, String>.from(uri.queryParameters)
      ..remove(_nativeFlag);

    final normalized = uri.replace(queryParameters: updatedParameters);
    AppLogger.instance.log(
      'Removed $_nativeFlag from Clerk web request: $uri -> $normalized',
      source: 'ClerkHttpService',
    );
    return normalized;
  }

  Map<String, String>? _normalizeHeaders(
    clerk.HttpMethod method,
    Map<String, String>? headers,
  ) {
    if (!kIsWeb || headers == null) {
      return headers;
    }

    final normalized = Map<String, String>.from(headers);
    final removed = <String>[];

    void removeHeader(String name) {
      final removedValue = normalized.remove(name);
      if (removedValue != null) {
        removed.add(name);
      }
    }

    removeHeader(HttpHeaders.authorizationHeader);
    removeHeader(_clerkApiVersionHeader);
    removeHeader(_clerkClientIdHeader);
    removeHeader(_flutterSdkHeader);
    removeHeader(_mobileHeader);

    if (method.isGet) {
      removeHeader(HttpHeaders.contentTypeHeader);
    }

    if (removed.isNotEmpty) {
      AppLogger.instance.log(
        'Removed Clerk web headers to avoid CORS preflight issues: ${removed.join(', ')}',
        source: 'ClerkHttpService',
      );
    }

    return normalized;
  }

  void _logHttpFailureIfNeeded(
    clerk.HttpMethod method,
    Uri uri,
    http.Response response,
  ) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    AppLogger.instance.log(
      'Clerk HTTP ${method.toString()} ${uri.path} failed with ${response.statusCode}: ${response.body}',
      source: 'ClerkHttpService',
      level: LogLevel.error,
    );
  }
}
