import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tubeflow_app/app/router.dart';

/// Responsive app shell with bottom navigation (mobile) or side rail
/// (tablet / web).
///
/// Used as the builder for the [ShellRoute] in [router.dart]. The [child]
/// parameter is the currently active route widget injected by GoRouter.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  /// The routed page content.
  final Widget child;

  // ---------------------------------------------------------------------------
  // Navigation destinations
  // ---------------------------------------------------------------------------

  static const _destinations = <_NavDestination>[
    _NavDestination(
      label: 'Videos',
      icon: Icons.video_library_outlined,
      selectedIcon: Icons.video_library,
      path: Routes.videos,
    ),
    _NavDestination(
      label: 'Browse',
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore,
      path: Routes.browse,
    ),
    _NavDestination(
      label: 'Play',
      icon: Icons.play_circle_outline,
      selectedIcon: Icons.play_circle,
      path: Routes.play,
    ),
    _NavDestination(
      label: 'Playlists',
      icon: Icons.queue_music_outlined,
      selectedIcon: Icons.queue_music,
      path: Routes.playlists,
    ),
    _NavDestination(
      label: 'Notes',
      icon: Icons.sticky_note_2_outlined,
      selectedIcon: Icons.sticky_note_2,
      path: Routes.notes,
    ),
  ];

  /// Returns the index of the currently selected destination based on the
  /// active route location, or 0 if no match is found.
  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (var i = 0; i < _destinations.length; i++) {
      if (location.startsWith(_destinations[i].path)) {
        return i;
      }
    }
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    context.go(_destinations[index].path);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  /// Breakpoint above which the side [NavigationRail] is used instead of the
  /// bottom [NavigationBar]. 600dp matches the Material 3 compact/medium
  /// breakpoint.
  static const _railBreakpoint = 600.0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final selected = _selectedIndex(context);

    if (width >= _railBreakpoint) {
      return _buildWithRail(context, selected);
    }
    return _buildWithBottomNav(context, selected);
  }

  // ---------------------------------------------------------------------------
  // Bottom navigation (mobile)
  // ---------------------------------------------------------------------------

  Widget _buildWithBottomNav(BuildContext context, int selected) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) => _onDestinationSelected(context, i),
        destinations: [
          for (final dest in _destinations)
            NavigationDestination(
              icon: Icon(dest.icon),
              selectedIcon: Icon(dest.selectedIcon),
              label: dest.label,
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Side rail (tablet / web)
  // ---------------------------------------------------------------------------

  Widget _buildWithRail(BuildContext context, int selected) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selected,
            onDestinationSelected: (i) => _onDestinationSelected(context, i),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Icon(
                Icons.play_circle_outline_rounded,
                size: 32,
                color: colorScheme.primary,
              ),
            ),
            destinations: [
              for (final dest in _destinations)
                NavigationRailDestination(
                  icon: Icon(dest.icon),
                  selectedIcon: Icon(dest.selectedIcon),
                  label: Text(dest.label),
                ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper model
// ---------------------------------------------------------------------------

class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.path,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
}
