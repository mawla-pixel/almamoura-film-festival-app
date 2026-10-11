import 'package:flutter/material.dart';

/// Deterministic gradient placeholder standing in for a film poster image,
/// since no real film stills are bundled with this prototype.
class FilmPoster extends StatelessWidget {
  final String seed;
  final String? imageUrl;
  final BorderRadius? borderRadius;
  final Widget? child;

  const FilmPoster({
    super.key,
    required this.seed,
    this.imageUrl,
    this.borderRadius,
    this.child,
  });

  static const _palettes = <List<Color>>[
    [Color(0xFF3A2E39), Color(0xFF1B1620)],
    [Color(0xFF264653), Color(0xFF102027)],
    [Color(0xFFB08968), Color(0xFF3E2723)],
    [Color(0xFF5C4033), Color(0xFF241A15)],
    [Color(0xFF2B2D42), Color(0xFF121319)],
    [Color(0xFF6B4226), Color(0xFF2A1D14)],
  ];

  @override
  Widget build(BuildContext context) {
    final posterUrl = imageUrl;
    final index =
        seed.codeUnits.fold<int>(0, (a, b) => a + b) % _palettes.length;
    final colors = _palettes[index];
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          if (posterUrl != null && posterUrl.isNotEmpty)
            Image.network(
              posterUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ?child,
        ],
      ),
    );
  }
}
