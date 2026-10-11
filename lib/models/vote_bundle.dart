/// A purchasable bundle of votes shown on the vote checkout screen.
class VoteBundle {
  final String id;
  final int votes;
  final String label;
  final String description;
  final double price;
  final bool isBestValue;

  const VoteBundle({
    required this.id,
    required this.votes,
    required this.label,
    required this.description,
    required this.price,
    this.isBestValue = false,
  });

  String get priceLabel => 'AED ${price.toStringAsFixed(2)}';
}
