import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';

import '../../../links/manager/link_manager.dart';
import '../../../links/models/link_model.dart';

part 'link_list_event.dart';
part 'link_list_state.dart';

/// One Library list: a [LinkQuery] (source, category, smart list or search),
/// paged, with bulk selection.
///
/// Reloads silently whenever links change, so swipes, bulk actions and edits
/// made elsewhere show up without a spinner.
class LinkListBloc extends Bloc<LinkListEvent, LinkListState> {
  final LinkManager _manager;
  final LinkQuery _initialQuery;

  /// Subscription to the links box. Cancelled in [close].
  late final StreamSubscription<void> _boxSubscription;

  static const pageSize = 20;

  LinkListBloc({required LinkManager manager, required LinkQuery query})
    : _manager = manager,
      _initialQuery = query,
      super(const LinkListInitial()) {
    on<LinkListLoadRequested>(_onLoadRequested);
    on<LinkListQueryChanged>(_onQueryChanged);
    on<LinkListSearchChanged>(
      _onSearchChanged,
      transformer: (events, mapper) => events
          .debounceTime(const Duration(milliseconds: 300))
          .switchMap(mapper),
    );
    on<LinkListNextPageRequested>(_onNextPageRequested);
    on<LinkListReadToggled>(_onReadToggled);
    on<LinkListLinkDeleted>(_onLinkDeleted);
    on<LinkListSelectionToggled>(_onSelectionToggled);
    on<LinkListSelectAllRequested>(_onSelectAllRequested);
    on<LinkListSelectionCleared>(_onSelectionCleared);
    on<LinkListBulkMarkReadRequested>(_onBulkMarkRead);
    on<LinkListBulkCategoryAdded>(_onBulkCategoryAdded);
    on<LinkListBulkPriorityChanged>(_onBulkPriorityChanged);
    on<LinkListBulkDeleteRequested>(_onBulkDelete);

    _boxSubscription = _manager.watchLinks().listen((_) {
      if (state is LinkListLoaded) {
        add(const LinkListLoadRequested(silent: true));
      }
    });
  }

  @override
  Future<void> close() {
    _boxSubscription.cancel();
    return super.close();
  }

  LinkQuery get _query {
    final current = state;
    return current is LinkListLoaded ? current.query : _initialQuery;
  }

  void _onLoadRequested(
    LinkListLoadRequested event,
    Emitter<LinkListState> emit,
  ) {
    final current = state;
    if (event.silent && current is LinkListLoaded) {
      try {
        _emitReloaded(emit, current);
      } catch (e) {
        emit(LinkListError(message: e.toString()));
      }
      return;
    }
    emit(const LinkListLoading());
    _emitFirstPage(emit, _query);
  }

  /// Reloads [current] in place: keeps as many links as were loaded, so the
  /// scroll position survives, and drops selected links that are gone or no
  /// longer match.
  void _emitReloaded(Emitter<LinkListState> emit, LinkListLoaded current) {
    final total = _manager.countLinks(current.query);
    final count = current.links.length < pageSize
        ? pageSize
        : current.links.length;
    final links = _manager.findLinks(current.query, limit: count);
    var selected = current.selectedIds;
    if (selected.isNotEmpty) {
      final matching = _manager
          .findLinks(current.query, limit: total)
          .map((l) => l.id)
          .toSet();
      selected = selected.where(matching.contains).toSet();
    }
    emit(
      current.copyWith(
        links: links,
        total: total,
        hasReachedMax: links.length >= total,
        selectedIds: selected,
      ),
    );
  }

  void _onQueryChanged(
    LinkListQueryChanged event,
    Emitter<LinkListState> emit,
  ) => _emitFirstPage(emit, event.query);

  void _onSearchChanged(
    LinkListSearchChanged event,
    Emitter<LinkListState> emit,
  ) => _emitFirstPage(emit, _query.copyWith(search: event.search));

  void _emitFirstPage(Emitter<LinkListState> emit, LinkQuery query) {
    try {
      final links = _manager.findLinks(query, limit: pageSize);
      final total = _manager.countLinks(query);
      emit(
        LinkListLoaded(
          query: query,
          links: links,
          total: total,
          hasReachedMax: links.length >= total,
        ),
      );
    } catch (e) {
      emit(LinkListError(message: e.toString()));
    }
  }

  void _onNextPageRequested(
    LinkListNextPageRequested event,
    Emitter<LinkListState> emit,
  ) {
    final current = state;
    if (current is! LinkListLoaded || current.hasReachedMax) return;
    final next = _manager.findLinks(
      current.query,
      limit: pageSize,
      offset: current.links.length,
    );
    final links = [...current.links, ...next];
    emit(
      current.copyWith(
        links: links,
        hasReachedMax: next.isEmpty || links.length >= current.total,
      ),
    );
  }

  Future<void> _onReadToggled(
    LinkListReadToggled event,
    Emitter<LinkListState> emit,
  ) => event.link.isRead
      ? _manager.markAsUnread(event.link.id)
      : _manager.markAsRead(event.link.id);

  Future<void> _onLinkDeleted(
    LinkListLinkDeleted event,
    Emitter<LinkListState> emit,
  ) => _manager.deleteLink(event.id);

  void _onSelectionToggled(
    LinkListSelectionToggled event,
    Emitter<LinkListState> emit,
  ) {
    final current = state;
    if (current is! LinkListLoaded) return;
    final selected = {...current.selectedIds};
    if (!selected.remove(event.id)) selected.add(event.id);
    emit(current.copyWith(selectedIds: selected));
  }

  void _onSelectAllRequested(
    LinkListSelectAllRequested event,
    Emitter<LinkListState> emit,
  ) {
    final current = state;
    if (current is! LinkListLoaded) return;
    final all = _manager.findLinks(current.query, limit: current.total);
    emit(current.copyWith(selectedIds: all.map((l) => l.id).toSet()));
  }

  void _onSelectionCleared(
    LinkListSelectionCleared event,
    Emitter<LinkListState> emit,
  ) {
    final current = state;
    if (current is LinkListLoaded) emit(current.copyWith(selectedIds: {}));
  }

  Future<void> _onBulkMarkRead(
    LinkListBulkMarkReadRequested event,
    Emitter<LinkListState> emit,
  ) => _applyToSelection(emit, _manager.markLinksRead);

  Future<void> _onBulkCategoryAdded(
    LinkListBulkCategoryAdded event,
    Emitter<LinkListState> emit,
  ) => _applyToSelection(
    emit,
    (ids) => _manager.addCategoryToLinks(ids, event.category),
  );

  Future<void> _onBulkPriorityChanged(
    LinkListBulkPriorityChanged event,
    Emitter<LinkListState> emit,
  ) => _applyToSelection(
    emit,
    (ids) => _manager.setPriorityForLinks(ids, event.priority),
  );

  Future<void> _onBulkDelete(
    LinkListBulkDeleteRequested event,
    Emitter<LinkListState> emit,
  ) => _applyToSelection(emit, _manager.deleteLinks);

  /// Runs [action] on the selected links, then leaves selection mode and
  /// reloads.
  Future<void> _applyToSelection(
    Emitter<LinkListState> emit,
    Future<void> Function(Set<String> ids) action,
  ) async {
    final current = state;
    if (current is! LinkListLoaded || !current.isSelecting) return;
    try {
      await action(current.selectedIds);
      final latest = state;
      if (latest is LinkListLoaded) {
        _emitReloaded(emit, latest.copyWith(selectedIds: {}));
      }
    } catch (e) {
      emit(LinkListError(message: e.toString()));
    }
  }
}
