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
    this.selectedIds = const {},
  });

  final LinkQuery query;

  /// The pages loaded so far.
  final List<LinkModel> links;

  /// How many links match [query] across all pages.
  final int total;

  final bool hasReachedMax;

  /// Links picked in bulk selection. Empty means not selecting.
  final Set<String> selectedIds;

  bool get isSelecting => selectedIds.isNotEmpty;

  LinkListLoaded copyWith({
    LinkQuery? query,
    List<LinkModel>? links,
    int? total,
    bool? hasReachedMax,
    Set<String>? selectedIds,
  }) => LinkListLoaded(
    query: query ?? this.query,
    links: links ?? this.links,
    total: total ?? this.total,
    hasReachedMax: hasReachedMax ?? this.hasReachedMax,
    selectedIds: selectedIds ?? this.selectedIds,
  );

  @override
  List<Object?> get props => [query, links, total, hasReachedMax, selectedIds];
}

class LinkListError extends LinkListState {
  const LinkListError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
