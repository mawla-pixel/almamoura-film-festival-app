import 'package:flutter/material.dart';

import '../models/film.dart';
import '../services/film_catalog_service.dart';
import '../widgets/film_poster.dart';
import '../widgets/films_future_builder.dart';
import 'film_detail_screen.dart';

/// Screen 3: Home tab featuring highlighted, trending, and category
/// content plus quick actions.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                Icon(
                  Icons.theater_comedy_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ALMAMOURA',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(letterSpacing: 2),
                    ),
                    Text(
                      'Film Festival',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.wb_sunny_outlined),
                const SizedBox(width: 12),
                const Icon(Icons.nightlight_outlined),
              ],
            ),
          ),
          _sectionHeader(context, 'Featured Films'),
          SizedBox(
            height: 260,
            child: FilmsFutureBuilder(
              future: FilmCatalogService.fetchFeatured(),
              loadingHeight: 260,
              builder: (context, films) => ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: films.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, index) =>
                    _FeaturedCard(film: films[index]),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader(context, 'Trending Films'),
          SizedBox(
            height: 190,
            child: FilmsFutureBuilder(
              future: FilmCatalogService.fetchTrending(),
              loadingHeight: 190,
              builder: (context, films) => ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: films.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, index) =>
                    _TrendingCard(film: films[index]),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader(context, 'Browse by Category', showSeeAll: false),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 20,
              runSpacing: 12,
              children: const [
                _CategoryIcon(icon: Icons.memory, label: 'AI Films'),
                _CategoryIcon(
                  icon: Icons.movie_creation_outlined,
                  label: 'Short Films',
                ),
                _CategoryIcon(
                  icon: Icons.videocam_outlined,
                  label: 'Documentary Films',
                ),
                _CategoryIcon(
                  icon: Icons.auto_awesome,
                  label: 'Animation Films',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader(context, 'Festival Announcements', showSeeAll: false),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _AnnouncementCard(),
          ),
          const SizedBox(height: 24),
          _sectionHeader(context, 'Quick Actions', showSeeAll: false),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: const [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.star_rounded,
                    label: 'Vote',
                    caption: '0 cast',
                    filled: true,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.upload_outlined,
                    label: 'Submit Film',
                    caption: 'Open',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.menu_book_outlined,
                    label: 'Film Library',
                    caption: '240+',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext context,
    String title, {
    bool showSeeAll = true,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (showSeeAll)
            Text(
              'See all',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
        ],
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final Film film;
  const _FeaturedCard({required this.film});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => FilmDetailScreen(film: film))),
      child: SizedBox(
        width: 190,
        child: FilmPoster(
          seed: film.id,
          imageUrl: film.posterUrl,
          child: Stack(
            children: [
              Positioned(top: 12, left: 12, child: _Badge(text: film.badge)),
              const Positioned(
                top: 10,
                right: 10,
                child: Icon(
                  Icons.favorite_border,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${film.category.toUpperCase()} · ${film.year}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      film.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.how_to_vote_outlined,
                          color: Color(0xFFE0A82E),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${film.audienceVotes} votes · ${film.durationLabel}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  final Film film;
  const _TrendingCard({required this.film});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => FilmDetailScreen(film: film))),
      child: SizedBox(
        width: 130,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 130,
              width: 130,
              child: FilmPoster(seed: film.id, imageUrl: film.posterUrl),
            ),
            const SizedBox(height: 8),
            Text(
              film.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '${film.category} · ${film.durationLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  const _CategoryIcon({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 22),
        const SizedBox(height: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 110,
            width: double.infinity,
            child: Stack(
              children: [
                const Positioned.fill(child: FilmPoster(seed: 'announcement')),
                Positioned(left: 12, bottom: 12, child: _Badge(text: 'New')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Submissions Now Open for 2026',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Filmmakers worldwide can submit until March 15. '
                  'Winners screen on opening night at the Almamoura '
                  'Grand Theatre.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 10),
                Row(
                  children: const [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Colors.grey,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Posted 2 days ago',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String caption;
  final bool filled;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.caption,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: filled
                ? scheme.primary
                : scheme.primary.withValues(alpha: 0.08),
            foregroundColor: filled ? scheme.onPrimary : scheme.primary,
            child: Icon(icon),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            caption,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }
}
