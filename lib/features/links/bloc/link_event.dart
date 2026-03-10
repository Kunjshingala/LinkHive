import 'dart:async';
import 'package:equatable/equatable.dart';

sealed class LinkEvent extends Equatable {
  const LinkEvent();

  @override
  List<Object?> get props => [];
}

class LinkLoadRequested extends LinkEvent {
  const LinkLoadRequested();
}

class LinkSearchChanged extends LinkEvent {
  final String query;
  const LinkSearchChanged(this.query);

  @override
  List<Object?> get props => [query];
}

class LinkCategoryFilterChanged extends LinkEvent {
  final String category;
  const LinkCategoryFilterChanged(this.category);

  @override
  List<Object?> get props => [category];
}

class LinkPriorityFilterChanged extends LinkEvent {
  final String priority;
  const LinkPriorityFilterChanged(this.priority);

  @override
  List<Object?> get props => [priority];
}

class LinkLoadNextPageRequested extends LinkEvent {
  const LinkLoadNextPageRequested();
}

class LinkDeleteRequested extends LinkEvent {
  final String linkId;
  const LinkDeleteRequested(this.linkId);

  @override
  List<Object?> get props => [linkId];
}

class LinkSyncRequested extends LinkEvent {
  final Completer<void>? completer;
  const LinkSyncRequested({this.completer});

  @override
  List<Object?> get props => [completer];
}

/// Fired when the user confirms a new custom-category name in the "New Category"
/// dialog. The BLoC persists it via the repository (Hive + Firestore) and
/// re-emits [LinksLoaded] with the updated [LinksLoaded.customCategories] list.
class LinkCustomCategoryAdded extends LinkEvent {
  /// The display name the user typed (e.g. "Gaming", "मेरे लेख").
  /// Stored and shown as-is — no translation needed because the user authored it.
  final String name;
  const LinkCustomCategoryAdded(this.name);

  @override
  List<Object?> get props => [name];
}

/// Fired when the user confirms deletion of a custom category.
/// The BLoC removes it from Hive and Firestore, then re-emits with the
/// updated [LinksLoaded.customCategories] list and resets the active category
/// filter to 'All' if it was the deleted one.
class LinkCustomCategoryDeleted extends LinkEvent {
  /// The [CategoryModel.id] of the category to delete.
  final String categoryId;
  const LinkCustomCategoryDeleted(this.categoryId);

  @override
  List<Object?> get props => [categoryId];
}
