enum SortOrder { newest, oldest, highestRating, lowestRating }

class FilterState {
  const FilterState({
    this.query = '',
    this.category = 'all',
    this.minRating = 0,
    this.sortOrder = SortOrder.newest,
  });

  final String query;
  final String category;
  final int minRating;
  final SortOrder sortOrder;

  bool get isActive =>
      query.isNotEmpty ||
      category != 'all' ||
      minRating > 0 ||
      sortOrder != SortOrder.newest;

  FilterState copyWith({
    String? query,
    String? category,
    int? minRating,
    SortOrder? sortOrder,
  }) => FilterState(
    query: query ?? this.query,
    category: category ?? this.category,
    minRating: minRating ?? this.minRating,
    sortOrder: sortOrder ?? this.sortOrder,
  );
}
