import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around the Supabase client used across the app.
///
/// Call [SupabaseService.initialize] once in `main()` before `runApp`,
/// then access the client anywhere via [SupabaseService.client].
class SupabaseService {
  SupabaseService._();

  static const String _url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://cbksbxmzeqefbdqzbprn.supabase.co',
  );
  static const String _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_ay7pcgnrEUzJLZLvMg5zMA_gaSVKusR',
  );

  static bool get isConfigured =>
      _url.isNotEmpty && _publishableKey.isNotEmpty;

  static Future<void> initialize() async {
    if (_url.isEmpty && _publishableKey.isEmpty) return;
    if (!isConfigured) {
      throw StateError(
        'Both SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY must be configured.',
      );
    }
    final uri = Uri.tryParse(_url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw StateError('SUPABASE_URL must be a valid HTTPS URL.');
    }
    await Supabase.initialize(url: _url, publishableKey: _publishableKey);
  }

  static SupabaseClient get client {
    if (!isConfigured) {
      throw StateError(
        'Supabase is disconnected. Configure the new project before using this feature.',
      );
    }
    return Supabase.instance.client;
  }

  static GoTrueClient get auth => client.auth;

  /// True only for a fully signed-in (non-anonymous) user. Guests browsing
  /// without a session, or any leftover anonymous session, are excluded —
  /// they cannot vote or rate under the current RLS policies.
  static bool get isSignedInPermanent {
    if (!isConfigured) return false;
    final user = auth.currentUser;
    return user != null && !user.isAnonymous;
  }
}
