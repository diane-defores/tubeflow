import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:replayglowz_app/widgets/media/media_thumbnail.dart';

void main() {
  testWidgets('MediaThumbnail shows fallback icon when URL is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MediaThumbnail(
            imageUrl: null,
            width: 120,
            height: 68,
            icon: Icons.play_circle_outline,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
  });
}
