import '../models/film.dart';
import 'supabase_service.dart';

enum FilmCatalogSort { mostViewed, highestRated, title }

class FilmCatalogPage {
  final List<Film> films;
  final int page;
  final bool hasMore;

  const FilmCatalogPage({
    required this.films,
    required this.page,
    required this.hasMore,
  });
}

/// Loads the public film catalogue from Supabase.
class FilmCatalogService {
  FilmCatalogService._();

  static const int pageSize = 30;

  static bool get isAdmin => false;

  static Future<FilmCatalogPage> fetchPage({
    int page = 0,
    String? query,
    String? category,
    bool? featured,
    bool? trending,
    bool? voteBallot,
    bool adminCatalog = false,
    FilmCatalogSort sort = FilmCatalogSort.mostViewed,
  }) async {
    if (!SupabaseService.isConfigured) {
      throw StateError(
        'Supabase must be configured to load the film catalogue.',
      );
    }

    if (page < 0) throw ArgumentError.value(page, 'page');
    final start = page * pageSize;
    final end = start + pageSize - 1;
    var queryBuilder = SupabaseService.client
        .from('public_voting_films')
        .select();
    if (query != null && query.trim().isNotEmpty) {
      queryBuilder = queryBuilder.ilike('title', '%${query.trim()}%');
    }
    if (category != null && category.trim().isNotEmpty) {
      queryBuilder = queryBuilder.contains('project_types', [category]);
    }
    final orderedQuery = switch (sort) {
      FilmCatalogSort.mostViewed => queryBuilder.order(
        'audience_votes',
        ascending: false,
      ),
      FilmCatalogSort.highestRated => queryBuilder.order(
        'rating',
        ascending: false,
      ),
      FilmCatalogSort.title => queryBuilder.order('title'),
    };
    final rows = await orderedQuery
        .order('title')
        .order('id')
        .range(start, end);
    final films = rows.map(Film.fromJson).toList(growable: false);
    return FilmCatalogPage(
      films: films,
      page: page,
      hasMore: films.length == pageSize,
    );
  }

  static Future<FilmCatalogPage> fetchPublicPage({
    int page = 0,
    String? query,
    String? category,
    bool? featured,
    bool? trending,
    bool? voteBallot,
  }) {
    return fetchPage(
      page: page,
      query: query,
      category: category,
      featured: featured,
      trending: trending,
      voteBallot: voteBallot,
      sort: FilmCatalogSort.mostViewed,
    );
  }

  static Future<FilmCatalogPage> fetchAdminPage({
    int page = 0,
    String? query,
    String? category,
  }) {
    return fetchPage(page: page, query: query, category: category);
  }

  static Future<List<Film>> fetchFeatured() async {
    if (SupabaseService.isConfigured) {
      final rows = await SupabaseService.client
          .from('public_voting_films')
          .select()
          .order('audience_votes', ascending: false)
          .order('title')
          .order('id')
          .limit(10);
      return rows.map(Film.fromJson).toList(growable: false);
    }
    return fetchPage(page: 0).then((page) => page.films.take(10).toList());
  }

  static Future<List<Film>> fetchTrending() async {
    final rows = await SupabaseService.client
        .from('public_voting_films')
        .select()
        .order('audience_votes', ascending: false)
        .order('title')
        .order('id')
        .range(10, 19);
    return rows.map(Film.fromJson).toList(growable: false);
  }

  static Future<List<Film>> fetchLibrary() async {
    return (await fetchPage()).films;
  }

  static Future<FilmCatalogPage> fetchVoteBallot({
    int page = 0,
    String? query,
    String? category,
  }) => fetchPage(
    page: page,
    query: query,
    category: category,
    sort: FilmCatalogSort.mostViewed,
  );

  static Future<Film?> fetchById(String filmId) {
    if (!SupabaseService.isConfigured) {
      throw StateError(
        'Supabase must be configured to load the film catalogue.',
      );
    }
    return SupabaseService.client
        .from('public_voting_films')
        .select()
        .eq('id', filmId)
        .maybeSingle()
        .then((row) => row == null ? null : Film.fromJson(row));
  }
}
