import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tubeflow_app/auth/auth_gate.dart';
import 'package:tubeflow_app/auth/auth_state.dart';
import 'package:tubeflow_app/screens/hidden/hidden_screen.dart';
import 'package:tubeflow_app/screens/notes/note_detail_screen.dart';
import 'package:tubeflow_app/screens/notes/notes_screen.dart';
import 'package:tubeflow_app/screens/notifications/notifications_screen.dart';
import 'package:tubeflow_app/screens/play/play_screen.dart';
import 'package:tubeflow_app/screens/playlists/create_playlist_screen.dart';
import 'package:tubeflow_app/screens/playlists/playlist_detail_screen.dart';
import 'package:tubeflow_app/screens/playlists/playlists_screen.dart';
import 'package:tubeflow_app/screens/preferences/preferences_screen.dart';
import 'package:tubeflow_app/screens/stats/stats_screen.dart';
import 'package:tubeflow_app/screens/videos/videos_screen.dart';
import 'package:tubeflow_app/widgets/app_shell.dart';

// ---------------------------------------------------------------------------
// Route paths
// ---------------------------------------------------------------------------

abstract final class Routes {
  static const signIn = '/sign-in';
  static const videos = '/videos';
  static const play = '/play';
  static const playlists = '/playlists';
  static const playlistCreate = '/playlists/create';
  static String playlistDetail(String id) => '/playlists/$id';
  static const notes = '/notes';
  static String noteDetail(String slug) => '/notes/$slug';
  static const notifications = '/notifications';
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

      if (isAuthenticated && goingToSignIn) {
        return Routes.videos;
      }
      return null;
    },
    routes: [
      // Sign-in (no shell)
      GoRoute(
        path: Routes.signIn,
        builder: (context, state) => const ClerkSignInPage(),
      ),

      // Main app with shell navigation
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: Routes.videos,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const VideosScreen(),
            ),
          ),
          GoRoute(
            path: Routes.play,
            pageBuilder: (context, state) {
              final videoId = state.uri.queryParameters['videoId'] ?? '';
              return NoTransitionPage(
                key: state.pageKey,
                child: PlayScreen(videoId: videoId),
              );
            },
          ),
          GoRoute(
            path: Routes.playlists,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const PlaylistsScreen(),
            ),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) => const CreatePlaylistScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => PlaylistDetailScreen(
                  id: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: Routes.notes,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const NotesScreen(),
            ),
            routes: [
              GoRoute(
                path: ':slug',
                builder: (context, state) => NoteDetailScreen(
                  slug: state.pathParameters['slug']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: Routes.notifications,
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: Routes.preferences,
            builder: (context, state) => const PreferencesScreen(),
          ),
          GoRoute(
            path: Routes.hidden,
            builder: (context, state) => const HiddenScreen(),
          ),
          GoRoute(
            path: Routes.stats,
            builder: (context, state) => const StatsScreen(),
          ),
        ],
      ),
    ],
  );
});
