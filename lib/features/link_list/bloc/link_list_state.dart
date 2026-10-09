part of 'link_list_bloc.dart';

sealed class LinkListState extends Equatable {
  const LinkListState();

  @override
  List<Object?> get props => [];
}

class LinkListInitial extends LinkListState {
  const LinkListInitial();
}

class LinkListLoading extends LinkListState {
  const LinkListLoading();
}

class LinkListLoaded extends LinkListState {
  const LinkListLoaded({
    required this.query,
    required this.links,
    required this.total,
    this.hasReachedMax = false,
    this.stats = const LibraryStats(),
    this.sources = const [],
    this.categories = const [],
    this.siteCounts = const {},
    this.isSelecting = false,
    this.selectedIds = const {},
  });

  final LinkQuery query;

  /// The pages loaded so far.
  final List<LinkModel> links;

  /// How many links match [query] across all pages.
  final int total;

  final bool hasReachedMax;

  /// Counts for the quick chips and "No category".
  final LibraryStats stats;

  /// Every source site with its count, for the Source sheet.
  final List<NamedCount> sources;

  /// Every category in use with its count, for the Category sheet.
  final List<NamedCount> categories;

  /// Links per site within [query], for the group headers when sorting by
  /// site. Empty for other sorts.
  final Map<String, int> siteCounts;

  /// Bulk selection mode: on from the Select button or a long-press, even
  /// before anything is picked.
  final bool isSelecting;

  /// Links picked in bulk selection.
  final Set<String> selectedIds;

  LinkListLoaded copyWith({
    LinkQuery? query,
    List<LinkModel>? links,
    int? total,
    bool? hasReachedMax,
    LibraryStats? stats,
    List<NamedCount>? sources,
    List<NamedCount>? categories,
    Map<String, int>? siteCounts,
    bool? isSelecting,
    Set<String>? selectedIds,
  }) => LinkListLoaded(
    query: query ?? this.query,
    links: links ?? this.links,
    total: total ?? this.total,
    hasReachedMax: hasReachedMax ?? this.hasReachedMax,
    stats: stats ?? this.stats,
    sources: sources ?? this.sources,
    categories: categories ?? this.categories,
    siteCounts: siteCounts ?? this.siteCounts,
    isSelecting: isSelecting ?? this.isSelecting,
    selectedIds: selectedIds ?? this.selectedIds,
  );

  @override
  List<Object?> get props => [
    query,
    links,
    total,
    hasReachedMax,
    stats,
    sources,
    categories,
    siteCounts,
    isSelecting,
    selectedIds,
  ];
}

class LinkListError extends LinkListState {
  const LinkListError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
