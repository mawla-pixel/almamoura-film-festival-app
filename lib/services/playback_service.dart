import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/playback_session.dart';
import 'supabase_service.dart';

class PlaybackService {
  PlaybackService._();

  static Future<PlaybackSession> createSession(String filmId) async {
    if (!SupabaseService.isConfigured) {
      throw StateError('Online playback is unavailable while the backend is disconnected.');
    }
    final response = await SupabaseService.client.functions.invoke(
      'create-playback-session',
      body: {'filmId': filmId},
    );

    final data = response.data;
    if (data is! Map) {
      throw const FormatException('Invalid playback session response.');
    }

    return PlaybackSession.fromJson(
      Map<String, dynamic>.from(data),
      expectedFilmId: filmId,
    );
  }

  static String messageFor(Object error) {
    if (error is FunctionException) {
      return error.reasonPhrase ?? 'Playback is not available right now.';
    }
    if (error is FormatException) return error.message;
    if (error is StateError) return error.message.toString();
    return 'Playback is not available right now. Please try again.';
  }
}
