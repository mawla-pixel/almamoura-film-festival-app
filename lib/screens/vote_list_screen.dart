import 'dart:async';

import 'package:flutter/material.dart';

import '../data/festival_options.dart';
import '../models/film.dart';
import '../services/film_catalog_service.dart';
import '../services/supabase_service.dart';
import '../widgets/film_poster.dart';
import 'vote_payment_screen.dart';

/// Paid audience ballot with public completed-vote totals for each film.
class VoteListScreen extends StatefulWidget {
  const VoteListScreen({super.key});

  @override
  State<VoteListScreen> createState() => _VoteListScreenState();
}

class _VoteListScreenState extends State<VoteListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _films = <Film>[];
  String _query = '';
  String? _selectedCategory;
  Timer? _searchDebounce;
  var _page = 0;
  var _hasMore = true;
  var _isLoading = false;
  var _requestGeneration = 0;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_loadNextPageOnScroll);
    unawaited(_loadPage(reset: true));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController
      ..removeListener(_loadNextPageOnScroll)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _query = _searchController.text.trim());
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_loadPage(reset: true)),
    );
  }

  void _loadNextPageOnScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 500) {
      unawaited(_loadPage());
    }
  }

  Future<void> _refresh() => _loadPage(reset: true);

  Future<void> _loadPage({bool reset = false}) async {
    if (_isLoading && !reset) return;
    if (!reset && !_hasMore) return;
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
      final result = await FilmCatalogService.fetchVoteBallot(
        page: requestedPage,
        query: _query,
        category: _selectedCategory,
      );
      if (!mounted || requestGeneration != _requestGeneration) return;
      setState(() {
        _films.addAll(result.films);
        _page = requestedPage + 1;
        _hasMore = result.hasMore;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadNextPageOnScroll();
      });
    } catch (error) {
      debugPrint('Failed to load vote ballot page: $error');
      if (!mounted || requestGeneration != _requestGeneration) return;
      setState(() => _loadError = error);
    } finally {
      if (mounted && requestGeneration == _requestGeneration) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _voteForFilm(Film film) async {
    if (!SupabaseService.isSignedInPermanent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in with an account before purchasing votes.'),
        ),
      );
      return;
    }

    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => VotePaymentScreen(film: film)),
    );
    if (!mounted) return;
    if (completed == true) {
      await _loadPage(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = SupabaseService.isSignedInPermanent;
    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFCEFD2), Color(0xFFFBF3E3)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ALMAMOURA FILM FESTIVAL',
                  style: TextStyle(
                    letterSpacing: 2,
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Vote for your favorites',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search films...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _searchController.clear,
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _categoryChip('All', null),
                      ...FestivalOptions.voteCategoryFilters.map(
                        (category) => _categoryChip(category, category),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!signedIn)
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: const Text(
                'Sign in to purchase votes. Completed vote totals are public.',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
          const Divider(height: 1),
          Expanded(
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
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      itemCount:
                          _films.length +
                          (_hasMore || _loadError != null ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
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
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        final film = _films[index];
                        return _FilmVoteCard(
                          film: film,
                          canVote: signedIn,
                          onVote: () => _voteForFilm(film),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String label, String? category) {
    final selected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => _selectedCategory = category);
          unawaited(_loadPage(reset: true));
        },
      ),
    );
  }
}

class _FilmVoteCard extends StatelessWidget {
  final Film film;
  final bool canVote;
  final VoidCallback onVote;

  const _FilmVoteCard({
    required this.film,
    required this.canVote,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            height: 84,
            child: FilmPoster(seed: film.id, imageUrl: film.posterUrl),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  film.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  film.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  '${film.audienceVotes} ${film.audienceVotes == 1 ? 'vote' : 'votes'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonal(
                    onPressed: canVote ? onVote : null,
                    child: const Text('Vote for this film'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
