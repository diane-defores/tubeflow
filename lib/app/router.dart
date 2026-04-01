import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tubeflow_app/auth/auth_gate.dart';
import 'package:tubeflow_app/auth/auth_state.dart';
import 'package:tubeflow_app/widgets/app_shell.dart';

// ---------------------------------------------------------------------------
// Route paths
// ---------------------------------------------------------------------------

abstract final class Routes {
  static const signIn = '/sign-in';
  static const videos = '/videos';
  static const browse = '/browse';
  static const play = '/play';
  static const playlists = '/playlists';
  static const playlistCreate = '/playlists/create';
  static String playlistDetail(String id) => '/playlists/$id';
  static const notes = '/notes';
  static String noteDetail(String slug) => '/notes/$slug';
  static const preferences = '/preferences';
  static const hidden = '/hidden';
  static const stats = '/stats';
}

// ---------------------------------------------------------------------------
// Router provider
// ---------------------------------------------------------------------------

final routerProvider = Provider<GoRouter>((ref) {
  // Derive a simple boolean from the sealed AuthState for redirect logic.
  final authState = ref.watch(authStateProvider);
  final isAuthenticated = authState is AuthAuthenticated;

  return GoRouter(
    initialLocation: Routes.videos,
    redirect: (BuildContext context, GoRouterState state) {
      final goingToSignIn = state.matchedLocation == Routes.signIn;

      if (!isAuthenticated && !goingToSignIn) {
        return Routes.signIn;
      }
      if (isAuthenticated && goingToSignIn) {
        return Routes.videos;
      }
      return null;
    },
    routes: [
      // Sign-in (no shell)
      GoRoute(
        path: Routes.signIn,
        builder: (context, state) => const AuthGate(
          child: SizedBox.shrink(),
        ),
      ),

      // Main app with shell navigation
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: Routes.videos,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const _Placeholder(title: 'Videos'),
            ),
          ),
          GoRoute(
            path: Routes.browse,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const _Placeholder(title: 'Browse'),
            ),
          ),
          GoRoute(
            path: Routes.play,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const _Placeholder(title: 'Play'),
            ),
          ),
          GoRoute(
            path: Routes.playlists,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const _Placeholder(title: 'Playlists'),
            ),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) =>
                    const _Placeholder(title: 'Create Playlist'),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => _Placeholder(
                  title: 'Playlist ${state.pathParameters['id']}',
                ),
              ),
            ],
          ),
          GoRoute(
            path: Routes.notes,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const _Placeholder(title: 'Notes'),
            ),
            routes: [
              GoRoute(
                path: ':slug',
                builder: (context, state) => _Placeholder(
                  title: 'Note: ${state.pathParameters['slug']}',
                ),
              ),
            ],
          ),
          GoRoute(
            path: Routes.preferences,
            builder: (context, state) =>
                const _Placeholder(title: 'Preferences'),
          ),
          GoRoute(
            path: Routes.hidden,
            builder: (context, state) => const _Placeholder(title: 'Hidden'),
          ),
          GoRoute(
            path: Routes.stats,
            builder: (context, state) => const _Placeholder(title: 'Stats'),
          ),
        ],
      ),
    ],
  );
});

// ---------------------------------------------------------------------------
// Placeholder screen (to be replaced with real screens)
// ---------------------------------------------------------------------------

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
