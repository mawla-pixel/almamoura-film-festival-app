import 'package:flutter_test/flutter_test.dart';

import 'package:almamoura_film_festival/models/film.dart';

void main() {
  test('public voting view maps paid vote totals to film audience votes', () {
    final film = Film.fromJson({
      'id': 'film-uuid',
      'title': 'Festival Film',
      'project_types': ['Short Film'],
      'audience_votes': 16,
      'duration_minutes': 12,
      'year': '2026',
    });

    expect(film.id, 'film-uuid');
    expect(film.title, 'Festival Film');
    expect(film.category, 'Short Film');
    expect(film.audienceVotes, 16);
  });
}
