import 'package:flutter/material.dart';

/// Interactive 5-star rating row used on the vote and film detail screens.
class StarRating extends StatelessWidget {
  final double rating;
  final double size;
  final ValueChanged<double>? onChanged;
  final Color? filledColor;
  final Color? emptyColor;

  const StarRating({
    super.key,
    required this.rating,
    this.size = 22,
    this.onChanged,
    this.filledColor,
    this.emptyColor,
  });

  @override
  Widget build(BuildContext context) {
    final filled = filledColor ?? const Color(0xFFE0A82E);
    final empty = emptyColor ?? Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final isFilled = rating >= starValue;
        final icon = Icon(
          isFilled ? Icons.star_rounded : Icons.star_border_rounded,
          size: size,
          color: isFilled ? filled : empty.withValues(alpha: 0.4),
        );
        if (onChanged == null) return icon;
        return GestureDetector(
          onTap: () => onChanged!(starValue.toDouble()),
          child: icon,
        );
      }),
    );
  }
}
