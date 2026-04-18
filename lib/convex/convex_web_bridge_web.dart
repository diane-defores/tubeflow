import 'dart:convert';
import 'dart:js_interop';

@JS('tubeFlowConvexBridge')
external _TubeFlowConvexBridge get _bridge;

extension type _TubeFlowConvexBridge(JSObject _) implements JSObject {
  external JSPromise<JSString> query(
    JSString convexUrl,
    JSString authToken,
    JSString path,
    JSString argsJson,
  );

  external JSPromise<JSString> mutate(
    JSString convexUrl,
    JSString authToken,
    JSString path,
    JSString argsJson,
  );

  external JSPromise<JSString> action(
    JSString convexUrl,
    JSString authToken,
    JSString path,
    JSString argsJson,
  );
}

Future<String?> convexWebQuery({
  required String convexUrl,
  required String path,
  required Map<String, dynamic> args,
  String? authToken,
}) async {
  final result = (await _bridge
          .query(
            convexUrl.toJS,
            (authToken ?? '').toJS,
            path.toJS,
            jsonEncode(args).toJS,
          )
          .toDart)
      .toDart;
  return result.isEmpty ? null : result;
}

Future<String?> convexWebMutation({
  required String convexUrl,
  required String path,
  required Map<String, dynamic> args,
  String? authToken,
}) async {
  final result = (await _bridge
          .mutate(
            convexUrl.toJS,
            (authToken ?? '').toJS,
            path.toJS,
            jsonEncode(args).toJS,
          )
          .toDart)
      .toDart;
  return result.isEmpty ? null : result;
}

Future<String?> convexWebAction({
  required String convexUrl,
  required String path,
  required Map<String, dynamic> args,
  String? authToken,
}) async {
  final result = (await _bridge
          .action(
            convexUrl.toJS,
            (authToken ?? '').toJS,
            path.toJS,
            jsonEncode(args).toJS,
          )
          .toDart)
      .toDart;
  return result.isEmpty ? null : result;
}
