import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:replayglowz_app/widgets/app_states.dart';

void main() {
  testWidgets('AppEmptyState renders icon, title and description', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            icon: Icons.info_outline,
            title: 'Nothing yet',
            description: 'Try syncing your library.',
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.text('Nothing yet'), findsOneWidget);
    expect(find.text('Try syncing your library.'), findsOneWidget);
  });
}
