import 'package:flutter/material.dart';

import '../models/film.dart';
import '../services/film_catalog_service.dart';
import '../widgets/film_poster.dart';
import 'film_detail_screen.dart';

class AdminCatalogScreen extends StatefulWidget {
  const AdminCatalogScreen({super.key});

  @override
  State<AdminCatalogScreen> createState() => _AdminCatalogScreenState();
}

class _AdminCatalogScreenState extends State<AdminCatalogScreen> {
  final _films = <Film>[];
  final _searchController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_reload);
    _loadPage(reset: true);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_reload)
      ..dispose();
    super.dispose();
  }

  void _reload() {
    _loadPage(reset: true);
  }

  Future<void> _loadPage({required bool reset}) async {
    if (reset) {
      if (_isLoading) return;
      setState(() {
        _isLoading = true;
        _error = null;
        _films.clear();
        _page = 0;
        _hasMore = true;
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final result = await FilmCatalogService.fetchAdminPage(
        page: _page,
        query: _searchController.text,
      );
      if (!mounted) return;
      setState(() {
        _films.addAll(result.films);
        _hasMore = result.hasMore;
        _page++;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Imported film catalog')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : RefreshIndicator(
              onRefresh: () => _loadPage(reset: true),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search imported films',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_films.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(child: Text('No imported films found.')),
                    )
                  else
                    ..._films.map(_filmTile),
                  if (_hasMore)
                    Center(
                      child: TextButton(
                        onPressed: _isLoadingMore
                            ? null
                            : () => _loadPage(reset: false),
                        child: Text(
                          _isLoadingMore ? 'Loading...' : 'Load more',
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _filmTile(Film film) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      leading: SizedBox(
        width: 48,
        height: 68,
        child: FilmPoster(
          seed: film.id,
          imageUrl: film.posterUrl,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      title: Text(film.title),
      subtitle: Text(
        '${film.publicationStatus} · ${film.visibility} · ${film.category}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => FilmDetailScreen(film: film))),
    );
  }
}
