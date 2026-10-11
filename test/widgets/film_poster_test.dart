import 'package:almamoura_film_festival/widgets/film_poster.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads the supplied poster URL', (tester) async {
    const url = 'https://example.com/poster.jpg';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 100,
            height: 140,
            child: FilmPoster(seed: 'film-1', imageUrl: url),
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, url);
  });

  testWidgets('keeps the gradient fallback when no URL is supplied', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 100,
            height: 140,
            child: FilmPoster(seed: 'film-1'),
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.byType(DecoratedBox), findsOneWidget);
  });
}
