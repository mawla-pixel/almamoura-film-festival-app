import '../models/vote_bundle.dart';

class FestivalOptions {
  FestivalOptions._();

  static const voteBundles = <VoteBundle>[
    VoteBundle(
      id: 'single',
      votes: 1,
      label: '1 vote',
      description: 'Perfect for one favorite film',
      price: 18.5,
    ),
    VoteBundle(
      id: 'five',
      votes: 5,
      label: '5 votes',
      description: 'Vote across multiple categories',
      price: 92.5,
      isBestValue: true,
    ),
    VoteBundle(
      id: 'ten',
      votes: 10,
      label: '10 votes',
      description: 'For dedicated festival supporters',
      price: 185,
    ),
  ];

  static const voteCategoryFilters = <String>[
    'AI',
    'Short',
    'Documentary',
    'Animation',
  ];
}
