import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';

import '../../../core/services/sync_engine.dart';
import '../../links/manager/link_manager.dart';
import '../../links/models/link_model.dart';

part 'link_list_event.dart';
part 'link_list_state.dart';

/// The Links tab: every saved link, narrowed by search, a quick chip, a
/// source and a category, in one of five orders. Paged, with bulk selection
/// and pull-to-refresh sync.
///
/// Reloads silently whenever links change, so swipes, bulk actions and edits
/// made elsewhere show up without a spinner.
class LinkListBloc extends Bloc<LinkListEvent, LinkListState> {
  final LinkManager _manager;
  final SyncEngine? _syncEngine;

  /// Subscription to the links box. Cancelled in [close].
  late final StreamSubscription<void> _boxSubscription;

  static const pageSize = 20;

  /// Shortest time the refresh spinner shows, so a fast sync doesn't flicker.
  static const _minRefreshDuration = Duration(milliseconds: 500);

  LinkListBloc({required LinkManager manager, SyncEngine? syncEngine})
    : _manager = manager,
      _syncEngine = syncEngine,
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
    on<LinkListSyncRequested>(_onSyncRequested);
    on<LinkListReadToggled>(_onReadToggled);
    on<LinkListLinkDeleted>(_onLinkDeleted);
    on<LinkListSelectionStarted>(_onSelectionStarted);
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
    return current is LinkListLoaded ? current.query : const LinkQuery();
  }

  void _onLoadRequested(
    LinkListLoadRequested event,
    Emitter<LinkListState> emit,
  ) {
    final current = state;
    if (event.silent && current is LinkListLoaded) {
      _guard(emit, () => _emitReloaded(emit, current));
      return;
    }
    emit(const LinkListLoading());
    _emitFirstPage(emit, _query);
  }

  void _onQueryChanged(
    LinkListQueryChanged event,
    Emitter<LinkListState> emit,
  ) => _emitFirstPage(emit, event.query);

  void _onSearchChanged(
    LinkListSearchChanged event,
    Emitter<LinkListState> emit,
  ) => _emitFirstPage(emit, _query.copyWith(search: event.search));

  /// Loads page one of [query], keeping selection mode if it was on.
  void _emitFirstPage(Emitter<LinkListState> emit, LinkQuery query) {
    final current = state;
    _guard(emit, () {
      final links = _manager.findLinks(query, limit: pageSize);
      final total = _manager.countLinks(query);
      emit(
        _withOverview(
          LinkListLoaded(
            query: query,
            links: links,
            total: total,
            hasReachedMax: links.length >= total,
            isSelecting: current is LinkListLoaded && current.isSelecting,
          ),
        ),
      );
    });
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
      _withOverview(
        current.copyWith(
          links: links,
          total: total,
          hasReachedMax: links.length >= total,
          selectedIds: selected,
        ),
      ),
    );
  }

  /// [loaded] with the counts behind the chips, sheets and site headers.
  LinkListLoaded _withOverview(LinkListLoaded loaded) => loaded.copyWith(
    stats: _manager.getLibraryStats(),
    sources: _manager.getSourceCounts(),
    categories: _manager.getCategoryCounts(),
    siteCounts: loaded.query.sort == LinkSort.site
        ? {
            for (final c in _manager.getSourceCounts(within: loaded.query))
              c.name: c.count,
          }
        : const {},
  );

  void _guard(Emitter<LinkListState> emit, void Function() body) {
    try {
      body();
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

  Future<void> _onSyncRequested(
    LinkListSyncRequested event,
    Emitter<LinkListState> emit,
  ) async {
    final startedAt = DateTime.now();
    try {
      // Push and pull stay one serialized operation when the engine is wired.
      final engine = _syncEngine;
      if (engine != null) {
        await engine.requestSync(pull: true);
      } else {
        await _manager.syncPendingLinks();
        await _manager.pullFromCloud();
      }
      final current = state;
      if (current is LinkListLoaded) {
        _emitReloaded(emit, current);
      } else {
        _emitFirstPage(emit, _query);
      }
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed < _minRefreshDuration) {
        await Future<void>.delayed(_minRefreshDuration - elapsed);
      }
    } catch (e) {
      emit(LinkListError(message: e.toString()));
    } finally {
      final completer = event.completer;
      if (completer != null && !completer.isCompleted) completer.complete();
    }
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

  void _onSelectionStarted(
    LinkListSelectionStarted event,
    Emitter<LinkListState> emit,
  ) {
    final current = state;
    if (current is LinkListLoaded) emit(current.copyWith(isSelecting: true));
  }

  void _onSelectionToggled(
    LinkListSelectionToggled event,
    Emitter<LinkListState> emit,
  ) {
    final current = state;
    if (current is! LinkListLoaded) return;
    final selected = {...current.selectedIds};
    if (!selected.remove(event.id)) selected.add(event.id);
    emit(current.copyWith(isSelecting: true, selectedIds: selected));
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
    if (current is LinkListLoaded) {
      emit(current.copyWith(isSelecting: false, selectedIds: {}));
    }
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
    if (current is! LinkListLoaded || current.selectedIds.isEmpty) return;
    try {
      await action(current.selectedIds);
      final latest = state;
      if (latest is LinkListLoaded) {
        _emitReloaded(
          emit,
          latest.copyWith(isSelecting: false, selectedIds: {}),
        );
      }
    } catch (e) {
      emit(LinkListError(message: e.toString()));
    }
  }
}
