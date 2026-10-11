import 'supabase_service.dart';

/// Data-access layer for the `profiles` table: one row per permanent
/// authenticated user, auto-created on signup by a database trigger.
class ProfileRepository {
  ProfileRepository._();

  static const _table = 'profiles';

  /// Fetches the current user's display name, or `null` if signed out,
  /// a guest, or the row doesn't exist yet.
  static Future<String?> fetchDisplayName() async {
    if (!SupabaseService.isConfigured) return null;
    final user = SupabaseService.auth.currentUser;
    if (user == null || user.isAnonymous) return null;

    final row = await SupabaseService.client
        .from(_table)
        .select('display_name')
        .eq('id', user.id)
        .maybeSingle();
    if (row == null) return null;
    final name = row['display_name'] as String?;
    return (name == null || name.isEmpty) ? null : name;
  }

  /// Updates the current user's display name.
  static Future<void> updateDisplayName(String displayName) async {
    final user = SupabaseService.auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to update your profile.');
    }
    if (user.isAnonymous) {
      throw StateError('Guests cannot update a profile.');
    }

    await SupabaseService.client
        .from(_table)
        .update({'display_name': displayName})
        .eq('id', user.id);
  }
}
