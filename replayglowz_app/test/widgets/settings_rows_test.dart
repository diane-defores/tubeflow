import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:replayglowz_app/widgets/settings/settings_rows.dart';

void main() {
  testWidgets('showSettingsChoiceDialog selects option and closes', (
    tester,
  ) async {
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return SettingsChoiceTile(
                icon: Icons.palette_outlined,
                title: 'Theme',
                value: 'system',
                onTap: () => showSettingsChoiceDialog(
                  context,
                  title: 'Theme',
                  options: const ['light', 'dark', 'system'],
                  currentValue: 'system',
                  onSelected: (value) => selected = value,
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('dark'));
    await tester.pumpAndSettle();

    expect(selected, 'dark');
    expect(find.text('Theme'), findsOneWidget);
  });
}
