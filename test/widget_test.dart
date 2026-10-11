// Basic smoke test verifying the app boots to the splash screen.
import 'package:flutter_test/flutter_test.dart';

import 'package:almamoura_film_festival/main.dart';

void main() {
  testWidgets('App shows splash screen with tagline', (tester) async {
    await tester.pumpWidget(const AlmamouraApp());

    expect(
      find.text('from the heart of Abu Dhabi to the world'),
      findsOneWidget,
    );
    expect(find.text('Get Started'), findsOneWidget);
  });
}
