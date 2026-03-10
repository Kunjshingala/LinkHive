import 'package:equatable/equatable.dart';

import '../models/category_model.dart';
import '../models/link_model.dart';

sealed class LinkState extends Equatable {
  const LinkState();

  @override
  List<Object?> get props => [];
}

class LinkInitial extends LinkState {
  const LinkInitial();
}

class LinkLoading extends LinkState {
  const LinkLoading();
}

/// The primary loaded state for the Home screen.
///
/// [customCategories] holds the user-created [CategoryModel] list so the UI
/// rebuilds reactively whenever a category is added or deleted — no need to
/// call the repository directly from a widget.
class LinksLoaded extends LinkState {
  final List<LinkModel> links;
  final String activeCategory;
  final String activePriority;
  final String searchQuery;
  final bool hasReachedMax;
  final int offset;

  /// User-created categories, kept in state so the filter row and add-link
  /// screen rebuild automatically after any add/delete without touching the
  /// repository directly in a widget.
  final List<CategoryModel> customCategories;

  const LinksLoaded({
    required this.links,
    this.activeCategory = 'All',
    this.activePriority = 'All',
    this.searchQuery = '',
    this.hasReachedMax = false,
    this.offset = 20,
    this.customCategories = const [],
  });

  @override
  List<Object?> get props => [
    links,
    activeCategory,
    activePriority,
    searchQuery,
    hasReachedMax,
    offset,
    customCategories,
  ];
}

class LinkError extends LinkState {
  final String message;
  const LinkError(this.message);

  @override
  List<Object?> get props => [message];
}
