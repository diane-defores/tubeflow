import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tubeflow_app/app/router.dart';
import 'package:tubeflow_app/providers/providers.dart';

List<Widget> commonAppBarActions(BuildContext context, WidgetRef ref) {
  final unreadAsync = ref.watch(unreadNotificationCountProvider);
  final unreadCount = unreadAsync.asData?.value ?? 0;

  return [
    IconButton(
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text(
          unreadCount > 99 ? '99+' : '$unreadCount',
          style: const TextStyle(fontSize: 10),
        ),
        child: const Icon(Icons.notifications_outlined),
      ),
      tooltip: 'Notifications',
      onPressed: () => context.go(Routes.notifications),
    ),
    IconButton(
      icon: const Icon(Icons.settings_outlined),
      tooltip: 'Preferences',
      onPressed: () => context.go(Routes.preferences),
    ),
  ];
}
