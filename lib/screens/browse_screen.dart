import 'dart:async';

import 'package:flutter/material.dart';

import '../models/film.dart';
import '../services/film_catalog_service.dart';
import '../widgets/film_poster.dart';
import 'film_detail_screen.dart';

/// Screen 4: Film Library / Browse tab with search, filters, sort tabs,
/// and a two-column film grid.
class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  int _sortIndex = 0;
  final _sortTabs = const ['Most Viewed', 'Highest Rated', 'Jury Picks'];
  final _favorites = <String>{};
  final _scrollController = ScrollController();
  final _films = <Film>[];
  var _page = 0;
  var _hasMore = true;
  var _isLoading = false;
  var _requestGeneration = 0;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadNextPageOnScroll);
    unawaited(_loadPage(reset: true));
  }

  Future<void> _refresh() async {
    await _loadPage(reset: true);
  }

  void _loadNextPageOnScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 500) {
      unawaited(_loadPage());
    }
  }

  Future<void> _loadPage({bool reset = false}) async {
    if ((_isLoading && !reset) || (!reset && !_hasMore)) return;
    final requestedPage = reset ? 0 : _page;
    final requestGeneration = ++_requestGeneration;
    setState(() {
      _isLoading = true;
      _loadError = null;
      if (reset) {
        _films.clear();
        _page = 0;
        _hasMore = true;
      }
    });
    try {
      final result = await FilmCatalogService.fetchPage(
        page: requestedPage,
        sort: _sortIndex == 0
            ? FilmCatalogSort.mostViewed
            : FilmCatalogSort.highestRated,
      );
      if (!mounted || requestGeneration != _requestGeneration) return;
      setState(() {
        final films = _sortIndex == 2
            ? result.films
                  .where(
                    (film) => film.publicationStatus.toLowerCase().contains(
                      'published',
                    ),
                  )
                  .toList()
            : result.films;
        _films.addAll(films);
        _page = requestedPage + 1;
        _hasMore = result.hasMore;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadNextPageOnScroll();
      });
    } catch (error) {
      debugPrint('Failed to load film library page: $error');
      if (!mounted || requestGeneration != _requestGeneration) return;
      setState(() => _loadError = error);
    } finally {
      if (mounted && requestGeneration == _requestGeneration) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadNextPageOnScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.theater_comedy_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Film Library',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: const [
                      _FilterChip(icon: Icons.sell_outlined, label: 'Category'),
                      SizedBox(width: 10),
                      _FilterChip(icon: Icons.public, label: 'Country'),
                      SizedBox(width: 10),
                      _FilterChip(icon: Icons.access_time, label: 'Duration'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: List.generate(_sortTabs.length, (index) {
                    final selected = _sortIndex == index;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _sortIndex = index);
                          unawaited(_loadPage(reset: true));
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _sortTabs[index],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _films.isEmpty && _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _films.isEmpty && _loadError != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        const Center(
                          child: Text('Could not load films from Supabase.'),
                        ),
                        Center(
                          child: TextButton(
                            onPressed: () => unawaited(_loadPage(reset: true)),
                            child: const Text('Try again'),
                          ),
                        ),
                      ],
                    )
                  : _films.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 80),
                        Center(child: Text('No films match your search.')),
                      ],
                    )
                  : GridView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                      itemCount:
                          _films.length +
                          (_hasMore || _loadError != null ? 1 : 0),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.62,
                          ),
                      itemBuilder: (context, index) {
                        if (index >= _films.length) {
                          if (_loadError != null) {
                            return Center(
                              child: TextButton(
                                onPressed: () => unawaited(_loadPage()),
                                child: const Text('Retry loading films'),
                              ),
                            );
                          }
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        final film = _films[index];
                        final isFav = _favorites.contains(film.id);
                        return _LibraryCard(
                          film: film,
                          isFavorite: isFav,
                          onFavoriteTap: () => setState(() {
                            if (isFav) {
                              _favorites.remove(film.id);
                            } else {
                              _favorites.add(film.id);
                            }
                          }),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FilterChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.15),
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down, size: 16),
        ],
      ),
    );
  }
}

class _LibraryCard extends StatelessWidget {
  final Film film;
  final bool isFavorite;
  final VoidCallback onFavoriteTap;

  const _LibraryCard({
    required this.film,
    required this.isFavorite,
    required this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => FilmDetailScreen(film: film))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: FilmPoster(
              seed: film.id,
              imageUrl: film.posterUrl,
              child: Stack(
                children: [
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        film.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onFavoriteTap,
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.white,
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: isFavorite ? Colors.red : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            film.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            'Dir. ${film.director}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${film.countryFlag} ${film.country}',
                style: const TextStyle(fontSize: 12),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.how_to_vote_outlined,
                    color: Color(0xFFE0A82E),
                    size: 14,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${film.audienceVotes} votes',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
