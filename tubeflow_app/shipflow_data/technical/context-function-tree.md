---
artifact: documentation
metadata_schema_version: "1.0"
artifact_version: "1.0.0"
project: "tubeflow-app"
created: "2026-04-26"
updated: "2026-04-26"
status: "reviewed"
source_skill: sf-docs
scope: "file"
owner: "Diane"
confidence: "high"
risk_level: "medium"
security_impact: "medium"
docs_impact: "yes"
linked_systems:
  - "Flutter"
  - "Riverpod"
  - "Clerk"
  - "Convex"
  - "Vercel"
depends_on:
  - "shipflow_data/technical/context.md"
  - "shipflow_data/technical/architecture.md"
supersedes:
  - artifact_version: "0.1.0"
evidence:
  - "lib/main.dart"
  - "lib/app/router.dart"
  - "lib/app/build_info.dart"
  - "lib/auth/auth_state.dart"
  - "lib/auth/clerk_service.dart"
  - "lib/convex/convex_client.dart"
  - "lib/convex/convex_provider.dart"
  - "lib/providers/providers.dart"
  - "lib/providers/mutations.dart"
  - "lib/widgets/app_shell.dart"
  - "api/auth/_youtube.js"
  - "api/auth/youtube.js"
  - "api/auth/youtube/callback.js"
  - "tool/check_shared_backend_contract.dart"
next_step: "Refresh when provider names, route graph, or OAuth handler flow changes."
---

# CONTEXT FUNCTION TREE

## Bootstrap and app composition

```text
main()
├── WidgetsFlutterBinding.ensureInitialized()
├── FlutterError.onError -> AppLogger
├── PlatformDispatcher.instance.onError -> AppLogger
├── AppLogger build/config diagnostics
├── if convexUrl.isNotEmpty -> ConvexService.initialize(convexUrl)
└── runApp(ProviderScope(child: _AppBootstrap))

_AppBootstrapState.initState()
└── addPostFrameCallback(_bootstrap)

_AppBootstrapState._bootstrap()
├── if Convex and Clerk config exist
│   ├── ref.read(clerkServiceProvider)
│   ├── await clerk.ready
│   ├── ref.read(convexServiceProvider)
│   ├── await convex.setAuth(() => clerk.getConvexToken())
│   └── if clerk.isAuthenticated -> clerk.waitForConvexTokenReady()
├── else log skipped wiring
└── set _initialised=true

_AppBootstrapState.build()
├── loading MaterialApp while bootstrap runs
├── _ConfigFallbackScreen on bootstrap error or missing required config
└── ReplayGlowzApp on success
```

## Routing and shell

```text
routerProvider -> GoRouter(initialLocation: /videos)
├── redirect()
│   ├── unauthenticated protected route -> /sign-in?tf_redirect=...
│   ├── authenticated /sign-in -> resolved tf_redirect or /videos
│   └── public feedback routes bypass auth redirect
├── /sign-in -> ClerkSignInPage
├── /feedback -> FeedbackScreen
├── /feedback/admin -> FeedbackAdminScreen
└── ShellRoute -> AppShell
    ├── /videos -> VideosScreen
    ├── /play -> PlayScreen(videoId from query)
    ├── /playlists -> PlaylistsScreen
    │   ├── create -> CreatePlaylistScreen
    │   └── :id -> PlaylistDetailScreen
    ├── /notes -> NotesScreen
    │   └── :slug -> NoteDetailScreen
    ├── /notifications -> NotificationsScreen
    ├── /preferences -> PreferencesScreen
    ├── /hidden -> HiddenScreen
    └── /stats -> StatsScreen

AppShell
├── width >= 600 -> NavigationRail
└── width < 600 -> NavigationBar
```

## Auth tree

```text
authStateProvider -> AuthNotifier
├── setLoading()
├── setAuthenticated(AuthUser)
└── setUnauthenticated()

clerkServiceProvider -> ClerkService
├── ready
├── authState
├── isAuthenticated / currentUser
├── _init()
│   ├── initClerkWebBridge()
│   ├── _handleWebOAuthRedirectIfNeeded()
│   ├── ClerkAuthState.create()
│   ├── _restoreWebSessionOnStartup()
│   └── _syncAuthNotifier()
├── getConvexToken() -> sessionToken(templateName: 'convex')
├── waitForConvexTokenReady()
├── signOut()
└── convexAuthReadyProvider
```

## Convex tree

```text
ConvexService
├── initialize(url)
├── instance
├── setAuth(tokenProvider)
├── setAuthToken(token)
├── clearAuth()
├── query(path, args)
│   ├── optional web HTTP bridge
│   ├── _waitForConnection()
│   └── _decode()
├── mutate(path, args)
│   ├── optional web HTTP bridge
│   ├── _waitForConnection()
│   └── _decode()
├── action(path, args)
│   ├── optional web HTTP bridge
│   ├── _waitForConnection()
│   └── _decode()
├── subscribe(path, args)
└── dispose()

convexServiceProvider
convexQueryProvider
convexSubscriptionProvider
```

## Typed read providers

```text
providers.dart
├── videosProvider -> youtube:getAllVideos subscription
├── playlistsProvider -> youtube:getYoutubePlaylists
├── notesProvider -> notes:getNotes
├── settingsProvider -> settings:getSettings
├── subscriptionProvider -> subscriptions:getSubscription
├── currentUserProvider -> users:getCurrentUser plus auth fallback
├── youtubeConnectionProvider -> youtube:getYoutubeConnectionStatus
├── preferencesDataProvider -> settings + subscription + user composition
├── feedbackIsAdminProvider -> feedback:isAdmin
├── feedbackAdminEntriesProvider -> feedback:listAdmin
├── hiddenItemsProvider
├── watchedVideosProvider
├── videoProgressProvider(videoId)
├── quotaUsageProvider
├── playlistVideosProvider
├── notificationsProvider -> notifications:getNotifications
├── unreadNotificationCountProvider -> notifications:getUnreadCount
└── videoNotesProvider(videoId)
```

## Mutation and action entrypoints

```text
mutations.dart
├── Notes
│   ├── createNote() -> notes:createNote
│   ├── updateNote() -> notes:updateNote
│   └── deleteNote() -> notes:deleteNote
├── Hidden items
│   ├── hideVideo() -> hidden:hideItem
│   ├── hidePlaylist() -> hidden:hideItem
│   ├── unhideVideo() -> hidden:unhideItem
│   └── unhideItem() -> hidden:unhideItem
├── Watch history
│   ├── markWatched() -> watched:markWatched
│   └── unmarkWatched() -> watched:unmarkWatched
├── Playback progress
│   ├── saveProgress() -> progress:saveProgress
│   └── upsertProgress() -> progress:upsertProgress
├── Playlists / YouTube
│   ├── syncAllPlaylists() -> youtube:fetchYoutubePlaylists + youtube:fetchPlaylistItems
│   ├── syncAllPlaylistsWithContainer()
│   ├── syncPlaylist() -> youtube:fetchPlaylistItems
│   ├── disconnectYoutube() -> youtube:disconnectYoutube
│   ├── removeVideoFromPlaylist() -> playlists:removeVideoFromPlaylist
│   └── createPlaylist() -> playlists:createPlaylist
├── Likes
│   └── toggleLike()
├── Comments
│   └── createComment()
├── Notifications
│   ├── markNotificationRead()
│   └── markAllNotificationsRead()
├── Settings
│   └── updateSettings()
└── Feedback
    ├── getFeedbackUploadUrl()
    ├── createFeedbackText()
    ├── createFeedbackAudio()
    └── markFeedbackReviewed()
```

## Feedback flow

```text
FeedbackSubmissionService
├── loadTextDraft()
├── saveTextDraft()
├── clearTextDraft()
├── submitText()
│   └── createFeedbackText()
└── submitAudio()
    ├── readRecordedAudioUpload()
    ├── getFeedbackUploadUrl()
    ├── http.post(uploadUrl)
    ├── createFeedbackAudio()
    └── cleanupFeedbackRecording()
```

## YouTube OAuth serverless flow

```text
GET /api/auth/youtube
├── getRequestOrigin(req)
├── sanitizeReturnTo(return_to)
├── require GOOGLE_CLIENT_ID and tubeflow_youtube_clerk_session_id cookie
├── create state
├── set youtube_oauth_state and youtube_oauth_return_to cookies
└── redirect to Google OAuth consent

GET /api/auth/youtube/callback
├── validate method, code, state, and cookies
├── require GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, CLERK_SECRET_KEY, CONVEX_URL
├── exchangeCodeForTokens()
├── mintConvexJwt(sessionId, CLERK_SECRET_KEY) using Clerk template convex
├── ensureConvexUser() -> users:ensureUser
├── saveYoutubeTokens() -> youtube:saveYoutubeTokens
├── clear OAuth/session cookies
└── redirect to app hash route with youtube_connected or youtube_error
```

## Shared backend contract check

```text
dart run tool/check_shared_backend_contract.dart
├── resolve TUBEFLOW_BACKEND_ROOT
├── default ../tubeflow/packages/backend/convex
├── verify module file exists for each required function
└── verify `export const <function> =` exists
```
