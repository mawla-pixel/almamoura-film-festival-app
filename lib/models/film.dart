/// Represents a single festival film entry used across browse, vote,
/// and detail screens.
class Film {
  final String id;
  final String title;
  final String category;
  final String director;
  final String country;
  final String countryFlag;
  final double rating;
  final int durationMinutes;
  final String year;
  final String badge;
  final String synopsis;
  final int audienceVotes;
  final List<String> tags;
  final String? posterUrl;
  final String? heroImageUrl;
  final String? trailerUrl;
  final String? videoUrl;
  final String mediaProvider;
  final String mediaStatus;
  final String publicationStatus;
  final String visibility;
  final String? originalTitle;
  final String? originalSynopsis;
  final DateTime? completionDate;
  final List<String> languages;
  final List<String> countriesOfFilming;
  final String? aspectRatio;
  final String? shootingFormat;
  final String? filmColor;
  final bool isStudentProject;
  final bool isAiAssisted;
  final String? officialWebsiteUrl;

  const Film({
    required this.id,
    required this.title,
    required this.category,
    required this.director,
    required this.country,
    required this.countryFlag,
    required this.rating,
    required this.durationMinutes,
    this.year = '2026',
    this.badge = '',
    this.synopsis = '',
    this.audienceVotes = 0,
    this.tags = const [],
    this.posterUrl,
    this.heroImageUrl,
    this.trailerUrl,
    this.videoUrl,
    this.mediaProvider = 'local',
    this.mediaStatus = 'placeholder',
    this.publicationStatus = 'published',
    this.visibility = 'public',
    this.originalTitle,
    this.originalSynopsis,
    this.completionDate,
    this.languages = const [],
    this.countriesOfFilming = const [],
    this.aspectRatio,
    this.shootingFormat,
    this.filmColor,
    this.isStudentProject = false,
    this.isAiAssisted = false,
    this.officialWebsiteUrl,
  });

  factory Film.fromJson(Map<String, dynamic> map) {
    return Film(
      id: map['id']?.toString() ?? '',
      title: _stringValue(map['title']),
      category: _firstString(map['project_types']) ?? '',
      director: _nullableString(map['director']) ?? '',
      country: _firstString(map['countries_of_origin']) ?? '',
      countryFlag: '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      durationMinutes:
          _intValue(map['duration_minutes']) ??
          ((_intValue(map['duration_seconds']) ?? 0) ~/ 60),
      year: _dateTime(map['completion_date'])?.year.toString() ?? '2026',
      badge: map['badge'] as String? ?? '',
      synopsis: _stringValue(map['synopsis']),
      audienceVotes: (map['audience_votes'] as num?)?.toInt() ?? 0,
      tags: _firstStringList(map['tags'], map['genres']),
      posterUrl: map['poster_url'] as String?,
      heroImageUrl: map['hero_image_url'] as String?,
      trailerUrl: map['trailer_url'] as String?,
      videoUrl: map['video_url'] as String?,
      mediaProvider: map['media_provider'] as String? ?? 'local',
      mediaStatus: map['media_status'] as String? ?? 'placeholder',
      publicationStatus: _stringValue(
        map['publication_status'],
        fallback: 'published',
      ),
      visibility: _stringValue(map['visibility'], fallback: 'public'),
      originalTitle: _nullableString(map['original_title']),
      originalSynopsis: _nullableString(map['original_synopsis']),
      completionDate: _dateTime(map['completion_date']),
      languages: _stringList(map['languages']),
      countriesOfFilming: _stringList(map['countries_of_filming']),
      aspectRatio: _nullableString(map['aspect_ratio']),
      shootingFormat: _nullableString(map['shooting_format']),
      filmColor: _nullableString(map['film_color']),
      isStudentProject: _boolValue(map['is_student_project']),
      isAiAssisted: _boolValue(map['is_ai_assisted']),
      officialWebsiteUrl: _nullableString(map['official_website_url']),
    );
  }

  factory Film.fromMap(Map<String, dynamic> map) => Film.fromJson(map);

  static List<String> _stringList(Object? value) {
    return value is List
        ? value.map((entry) => entry.toString()).toList(growable: false)
        : value is String
        ? value
              .split(';')
              .map((entry) => entry.trim())
              .where((entry) => entry.isNotEmpty)
              .toList(growable: false)
        : const [];
  }

  static List<String> _firstStringList(Object? first, Object? second) {
    final values = _stringList(first);
    return values.isEmpty ? _stringList(second) : values;
  }

  static String? _firstString(Object? value) {
    final values = _stringList(value);
    return values.isEmpty ? null : values.first;
  }

  static int? _intValue(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '');
  }

  static bool _boolValue(Object? value) {
    if (value is bool) return value;
    return value?.toString().trim().toLowerCase() == 'true';
  }

  static String? _nullableString(Object? value) {
    final result = value?.toString().trim();
    return result == null || result.isEmpty ? null : result;
  }

  static String _stringValue(Object? value, {String fallback = ''}) {
    final result = value?.toString().trim();
    return result == null || result.isEmpty ? fallback : result;
  }

  static DateTime? _dateTime(Object? value) {
    final result = _nullableString(value);
    return result == null ? null : DateTime.tryParse(result);
  }

  String get durationLabel => '$durationMinutes min';
}
