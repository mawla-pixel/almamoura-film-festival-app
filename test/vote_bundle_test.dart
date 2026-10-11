import 'package:flutter_test/flutter_test.dart';

import 'package:almamoura_film_festival/data/festival_options.dart';

void main() {
  test('vote bundles display their AED prices', () {
    expect(
      FestivalOptions.voteBundles.map((bundle) => bundle.priceLabel).toList(),
      ['AED 5.00', 'AED 25.00', 'AED 50.00'],
    );
  });
}
