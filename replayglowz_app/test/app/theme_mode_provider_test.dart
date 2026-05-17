import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:replayglowz_app/app/theme.dart';
import 'package:replayglowz_app/models/settings.dart';
import 'package:replayglowz_app/providers/providers.dart';

void main() {
  group('appThemeModeToThemeMode', () {
    test('maps persisted values to Flutter ThemeMode', () {
      expect(appThemeModeToThemeMode(AppThemeMode.light), ThemeMode.light);
      expect(appThemeModeToThemeMode(AppThemeMode.dark), ThemeMode.dark);
      expect(appThemeModeToThemeMode(AppThemeMode.system), ThemeMode.system);
      expect(appThemeModeToThemeMode(null), ThemeMode.system);
    });
  });

  testWidgets('themeModeProvider follows settingsProvider theme value', (
    tester,
  ) async {
    ThemeMode? observed;
    const settings = UserSettings(
      id: 'settings:test',
      userId: 'user:test',
      theme: AppThemeMode.dark,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => Stream.value(settings)),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            observed = ref.watch(themeModeProvider);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();

    expect(observed, ThemeMode.dark);
  });
}
