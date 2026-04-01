import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tubeflow_app/convex/convex_client.dart';

// ---------------------------------------------------------------------------
// Singleton Convex service
// ---------------------------------------------------------------------------

/// Provides a single, app-wide [ConvexService] instance.
///
/// The service must be initialised before the provider is first read —
/// `ConvexService.initialize()` is called in `main()` before `runApp()`.
///
/// The service is disposed when the provider scope is destroyed.
final convexServiceProvider = Provider<ConvexService>((ref) {
  // Use the already-initialised singleton.
  final service = ConvexService.instance;

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

// ---------------------------------------------------------------------------
// Generic query provider family
// ---------------------------------------------------------------------------

/// Arguments for a Convex query: the function path and its arguments map.
///
/// Used as the family key for [convexQueryProvider].
typedef ConvexQueryArgs = ({String path, Map<String, dynamic> args});

/// A Riverpod provider family that executes a Convex query and exposes the
/// result as an [AsyncValue].
///
/// Usage:
/// ```dart
/// final videosAsync = ref.watch(
///   convexQueryProvider((path: 'youtube:getAllVideos', args: {})),
/// );
///
/// return videosAsync.when(
///   data: (data) => VideoList(data),
///   loading: () => const CircularProgressIndicator(),
///   error: (e, st) => ErrorWidget(e),
/// );
/// ```
///
/// Each unique combination of `(path, args)` gets its own cached provider
/// instance, so identical queries share the same result.
final convexQueryProvider =
    FutureProvider.family<dynamic, ConvexQueryArgs>((ref, queryArgs) async {
  final service = ref.watch(convexServiceProvider);
  return service.query<dynamic>(queryArgs.path, queryArgs.args);
});

// ---------------------------------------------------------------------------
// Generic subscription provider family
// ---------------------------------------------------------------------------

/// A Riverpod [StreamProvider] family that subscribes to a Convex query and
/// exposes each real-time update as an [AsyncValue].
///
/// Usage:
/// ```dart
/// final videosAsync = ref.watch(
///   convexSubscriptionProvider((path: 'youtube:getAllVideos', args: {})),
/// );
///
/// return videosAsync.when(
///   data: (data) => VideoList(data),
///   loading: () => const CircularProgressIndicator(),
///   error: (e, st) => ErrorWidget(e),
/// );
/// ```
final convexSubscriptionProvider =
    StreamProvider.family<dynamic, ConvexQueryArgs>((ref, queryArgs) {
  final service = ref.watch(convexServiceProvider);
  return service.subscribe<dynamic>(queryArgs.path, queryArgs.args);
});
