class PlaybackSession {
  final String playbackSessionId;
  final String filmId;
  final Uri embedUrl;
  final DateTime? expiresAt;
  final List<SubtitleTrack> subtitleTracks;

  const PlaybackSession({
    required this.playbackSessionId,
    required this.filmId,
    required this.embedUrl,
    required this.expiresAt,
    required this.subtitleTracks,
  });

  factory PlaybackSession.fromJson(
    Map<String, dynamic> json, {
    String? expectedFilmId,
  }) {
    final playbackSessionId = _requiredString(json['playbackSessionId']);
    final filmId = _requiredString(json['filmId']);
    final embedUrl = _httpsUri(json['embedUrl']);
    final expiresAt = _optionalDateTime(json['expiresAt']);

    if (expectedFilmId != null && filmId != expectedFilmId) {
      throw const FormatException('Playback session film mismatch.');
    }
    if (expiresAt != null && !expiresAt.isAfter(DateTime.now().toUtc())) {
      throw const FormatException('Playback session has expired.');
    }

    final rawTracks = json['subtitleTracks'];
    final subtitleTracks = rawTracks is List
        ? rawTracks
              .whereType<Map>()
              .map(
                (track) =>
                    SubtitleTrack.fromJson(Map<String, dynamic>.from(track)),
              )
              .toList(growable: false)
        : const <SubtitleTrack>[];

    return PlaybackSession(
      playbackSessionId: playbackSessionId,
      filmId: filmId,
      embedUrl: embedUrl,
      expiresAt: expiresAt,
      subtitleTracks: subtitleTracks,
    );
  }

  static String _requiredString(Object? value) {
    final result = value?.toString().trim() ?? '';
    if (result.isEmpty) {
      throw const FormatException('Playback session response is incomplete.');
    }
    return result;
  }

  static Uri _httpsUri(Object? value) {
    final uri = Uri.tryParse(_requiredString(value));
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('Playback URL must use HTTPS.');
    }
    return uri;
  }

  static DateTime? _optionalDateTime(Object? value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value.toString())?.toUtc();
    if (parsed == null) {
      throw const FormatException('Invalid playback expiry.');
    }
    return parsed;
  }
}

class SubtitleTrack {
  final String language;
  final String label;
  final Uri url;

  const SubtitleTrack({
    required this.language,
    required this.label,
    required this.url,
  });

  factory SubtitleTrack.fromJson(Map<String, dynamic> json) {
    final url = Uri.tryParse(json['url']?.toString().trim() ?? '');
    if (url == null || url.scheme != 'https' || url.host.isEmpty) {
      throw const FormatException('Subtitle URL must use HTTPS.');
    }
    return SubtitleTrack(
      language: json['language']?.toString().trim() ?? '',
      label: json['label']?.toString().trim() ?? '',
      url: url,
    );
  }
}
