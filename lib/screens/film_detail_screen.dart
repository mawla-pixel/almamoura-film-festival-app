import 'package:flutter/material.dart';

import '../models/film.dart';
import '../services/supabase_service.dart';
import '../services/votes_repository.dart';
import '../widgets/film_poster.dart';
import '../widgets/star_rating.dart';
import 'film_player_screen.dart';
import 'vote_payment_screen.dart';

/// Screen 6: Film detail page with trailer preview, synopsis, audience
/// rating, locked jury rating, and a personal rating input.
class FilmDetailScreen extends StatefulWidget {
  final Film film;
  const FilmDetailScreen({super.key, required this.film});

  @override
  State<FilmDetailScreen> createState() => _FilmDetailScreenState();
}

class _FilmDetailScreenState extends State<FilmDetailScreen> {
  double _myRating = 0;

  @override
  void initState() {
    super.initState();
    _loadMyRating();
  }

  Future<void> _loadMyRating() async {
    try {
      final rating = await VotesRepository.fetchMyRating(widget.film.id);
      if (mounted && rating != null) {
        setState(() => _myRating = rating);
      }
    } catch (_) {
      // Ignore: rating stays at 0 if not signed in or table unavailable.
    }
  }

  Future<void> _rateFilm(double value) async {
    if (!SupabaseService.isSignedInPermanent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in with an account to rate films.')),
      );
      return;
    }
    setState(() => _myRating = value);
    try {
      await VotesRepository.submitVote(filmId: widget.film.id, rating: value);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save rating: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final film = widget.film;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 320,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FilmPoster(
                  seed: film.id,
                  imageUrl: film.posterUrl,
                  borderRadius: BorderRadius.zero,
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _circleButton(
                          icon: Icons.arrow_back,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        _circleButton(icon: Icons.bookmark_border),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Semantics(
                    button: true,
                    label: 'Watch Film',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(56),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FilmPlayerScreen(
                            filmId: film.id,
                            filmTitle: film.title,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: const BoxDecoration(
                                color: Colors.black45,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Watch Film',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    if (film.badge.isNotEmpty) _tag(film.badge, filled: true),
                    _tag(film.category),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  film.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.videocam_outlined, size: 16),
                    const SizedBox(width: 4),
                    Text(film.director),
                    const SizedBox(width: 14),
                    const Icon(Icons.location_on_outlined, size: 16),
                    const SizedBox(width: 4),
                    Text(film.country),
                    const SizedBox(width: 14),
                    const Icon(Icons.access_time, size: 16),
                    const SizedBox(width: 4),
                    Text(film.durationLabel),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.grey.shade300,
                      child: const Icon(Icons.person),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Directed by',
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          film.director,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Synopsis',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  film.synopsis.isNotEmpty
                      ? film.synopsis
                      : 'Synopsis coming soon.',
                  style: const TextStyle(color: Colors.grey, height: 1.4),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Audience Rating',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 6),
                          StarRating(rating: film.rating, size: 18),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${film.rating}',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${film.audienceVotes} votes',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lock_outline, size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'Jury Rating',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey),
                            ),
                            child: const Text(
                              'Locked',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'The official jury score is sealed until the awards '
                        'ceremony on May 24. Check back after the festival '
                        'closing to reveal the verdict.',
                        style: TextStyle(color: Colors.grey, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Your Rating',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                StarRating(rating: _myRating, size: 28, onChanged: _rateFilm),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => VotePaymentScreen(film: widget.film),
                      ),
                    ),
                    icon: const Icon(Icons.star_rounded, size: 18),
                    label: const Text('Vote for this Film'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add to Watchlist'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        backgroundColor: Colors.black45,
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _tag(String label, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? Colors.black : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: filled ? Colors.white : Colors.black87,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
