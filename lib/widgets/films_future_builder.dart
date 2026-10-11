import 'package:flutter/material.dart';


import '../models/film.dart';

/// Loads a list of [Film]s via [future], showing a loading spinner while
/// pending. Errors are represented by an empty result so the caller can show
/// a real empty/error state instead of silently displaying stale demo data.
class FilmsFutureBuilder extends StatelessWidget {
  final Future<List<Film>> future;
  final Widget Function(BuildContext context, List<Film> films) builder;
  final double? loadingHeight;

  const FilmsFutureBuilder({
    super.key,
    required this.future,
    required this.builder,
    this.loadingHeight,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Film>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: loadingHeight ?? 120,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (snapshot.hasError) {
          debugPrint('Failed to load film catalogue: ${snapshot.error}');
          return SizedBox(
            height: loadingHeight ?? 120,
            child: Center(
              child: Text(
                'Could not load films. Please try again.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return builder(context, snapshot.data ?? const []);
      },
    );
  }
}
