part of 'link_list_bloc.dart';

sealed class LinkListEvent extends Equatable {
  const LinkListEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the first page. [silent] keeps the list on screen and the number of
/// loaded links, for reloads triggered by link changes.
class LinkListLoadRequested extends LinkListEvent {
  const LinkListLoadRequested({this.silent = false});

  final bool silent;

  @override
  List<Object?> get props => [silent];
}

/// Replaces the quick chip, source, category or sort, and reloads from the
/// first page.
class LinkListQueryChanged extends LinkListEvent {
  const LinkListQueryChanged(this.query);

  final LinkQuery query;

  @override
  List<Object?> get props => [query];
}

/// Search typing. Debounced, so only the last keystroke in a burst reloads.
class LinkListSearchChanged extends LinkListEvent {
  const LinkListSearchChanged(this.search);

  final String search;

  @override
  List<Object?> get props => [search];
}

class LinkListNextPageRequested extends LinkListEvent {
  const LinkListNextPageRequested();
}

/// Pull-to-refresh: pushes local changes, pulls from the cloud, then reloads.
/// [completer] finishes when the refresh indicator can stop.
class LinkListSyncRequested extends LinkListEvent {
  const LinkListSyncRequested({this.completer});

  final Completer<void>? completer;

  @override
  List<Object?> get props => [completer];
}

/// Swipe right on one card: marks it read, or unread if it already is.
class LinkListReadToggled extends LinkListEvent {
  const LinkListReadToggled(this.link);

  final LinkModel link;

  @override
  List<Object?> get props => [link.id, link.isRead];
}

class LinkListLinkDeleted extends LinkListEvent {
  const LinkListLinkDeleted(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// The Select button: enters selection mode with nothing picked yet.
class LinkListSelectionStarted extends LinkListEvent {
  const LinkListSelectionStarted();
}

/// Long-press, or a tap while selecting: adds or removes one link. A
/// long-press outside selection mode also starts it.
class LinkListSelectionToggled extends LinkListEvent {
  const LinkListSelectionToggled(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// Selects every link matching the current query, not just the loaded pages.
class LinkListSelectAllRequested extends LinkListEvent {
  const LinkListSelectAllRequested();
}

/// Leaves selection mode.
class LinkListSelectionCleared extends LinkListEvent {
  const LinkListSelectionCleared();
}

class LinkListBulkMarkReadRequested extends LinkListEvent {
  const LinkListBulkMarkReadRequested();
}

class LinkListBulkCategoryAdded extends LinkListEvent {
  const LinkListBulkCategoryAdded(this.category);

  final String category;

  @override
  List<Object?> get props => [category];
}

/// [priority] is `'High'`, `'Normal'` or `'Low'`.
class LinkListBulkPriorityChanged extends LinkListEvent {
  const LinkListBulkPriorityChanged(this.priority);

  final String priority;

  @override
  List<Object?> get props => [priority];
}

class LinkListBulkDeleteRequested extends LinkListEvent {
  const LinkListBulkDeleteRequested();
}
