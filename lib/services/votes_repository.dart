import 'supabase_service.dart';

/// Data-access layer for the `votes` table: one star-rating per
/// (user, film) pair.
class VotesRepository {
  VotesRepository._();

  static const _table = 'votes';

  /// Casts or updates the current user's rating for [filmId].
  ///
  /// Requires a fully signed-in (non-anonymous, non-guest) session, since
  /// votes are tied to `auth.uid()` and gated by the "not anonymous" RLS
  /// policy on `public.votes`. Guests remain local-only and cannot vote.
  static Future<void> submitVote({
    required String filmId,
    required double rating,
  }) async {
    final user = SupabaseService.auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to vote.');
    }
    if (user.isAnonymous) {
      throw StateError('Guests cannot vote. Please create an account.');
    }

    // `votes.rating` is a `smallint check (rating between 1 and 5)`: whole
    // stars only, no half-stars and no zero/unrated value.
    final wholeRating = rating.round();
    if (wholeRating < 1 || wholeRating > 5) {
      throw ArgumentError('Rating must be a whole number between 1 and 5.');
    }

    await SupabaseService.client.from(_table).upsert({
      'film_id': filmId,
      'user_id': user.id,
      'rating': wholeRating,
    }, onConflict: 'film_id,user_id');
  }

  /// Fetches the current user's rating for [filmId], or `null` if none.
  ///
  /// Guests (no session, or anonymous session) have no rating to fetch.
  static Future<double?> fetchMyRating(String filmId) async {
    if (!SupabaseService.isConfigured) return null;
    final user = SupabaseService.auth.currentUser;
    if (user == null || user.isAnonymous) return null;

    final row = await SupabaseService.client
        .from(_table)
        .select('rating')
        .eq('film_id', filmId)
        .eq('user_id', user.id)
        .maybeSingle();
    if (row == null) return null;
    return (row['rating'] as num).toDouble();
  }
}
