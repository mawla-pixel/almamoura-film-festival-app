import 'package:almamoura_film_festival/models/film.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps catalogue tags stored as a string', () {
    final film = Film.fromJson({
      'id': 'film-1',
      'title': 'Example',
      'project_types': ['Short films'],
      'tags': 'Drama, Documentary',
      'languages': ['English'],
      'countries_of_filming': ['UAE'],
    });

    expect(film.tags, ['Drama, Documentary']);
    expect(film.category, 'Short films');
  });
}
