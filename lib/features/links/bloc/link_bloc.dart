import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';

import '../../../core/services/sync_engine.dart';
import '../../../core/utils/utils.dart';
import '../models/link_model.dart';
import '../models/category_model.dart';
import '../repository/link_repository.dart';
import 'link_event.dart';
import 'link_state.dart';

/// BLoC for the link list in HomeScreen.
/// Handles load, search, filter, delete, and custom category CRUD.
///
/// ## Reactive Hive Subscription
/// On construction this BLoC subscribes to the Hive links box via
/// [LinkRepository.watchLinksBox]. Any external write to the box — including
/// writes from [AddLinkBloc] running on a different route — will trigger a
/// [LinkLoadRequested] so the home list always stays up-to-date without
/// needing cross-route `await context.push(...)` hacks.
class LinkBloc extends Bloc<LinkEvent, LinkState> {
  final LinkRepository _repository;
  final SyncEngine? _syncEngine;
  static const _limit = 20;

  EventTransformer<T> _debounce<T>(Duration duration) {
    return (events, mapper) => events.debounceTime(duration).switchMap(mapper);
  }

  EventTransformer<T> _droppable<T>() {
    return (events, mapper) => events.exhaustMap(mapper);
  }

  /// Subscription to the Hive links box stream.
  /// Cancelled in [close] to avoid memory leaks.
  late final StreamSubscription<void> _boxSubscription;

  LinkBloc({required LinkRepository repository, SyncEngine? syncEngine})
    : _repository = repository,
      _syncEngine = syncEngine,
      super(const LinkInitial()) {
    on<LinkLoadRequested>(_onLoadRequested);
    on<LinkLoadNextPageRequested>(
      _onLoadNextPageRequested,
      transformer: _droppable(),
    );
    on<LinkSearchChanged>(
      _onSearchChanged,
      transformer: _debounce(const Duration(milliseconds: 300)),
    );
    on<LinkCategoryFilterChanged>(_onCategoryFilterChanged);
    on<LinkPriorityFilterChanged>(_onPriorityFilterChanged);
    on<LinkDeleteRequested>(_onDeleteRequested);
    on<LinkSyncRequested>(_onSyncRequested);
    on<LinkCustomCategoryAdded>(_onCustomCategoryAdded);
    on<LinkCustomCategoryDeleted>(_onCustomCategoryDeleted);
    on<LinkMarkAsRead>(_onMarkAsRead);
    on<LinkMarkAsUnread>(_onMarkAsUnread);

    // Subscribe to the Hive box stream so any external write (e.g. AddLinkBloc
    // saving a link on a different route) triggers a reload automatically.
    // Uses silent:true to avoid the LinkLoading flash on small updates like
    // markLinkAsRead.
    _boxSubscription = _repository.watchLinksBox().listen((_) {
      if (state is LinksLoaded) {
        add(const LinkLoadRequested(silent: true));
      }
    });
  }

  @override
  Future<void> close() {
    _boxSubscription.cancel();
    return super.close();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  /// Reads the current custom categories from the repository.
  List<CategoryModel> get _customCategories => _repository.getCategories();

  // ─── Existing Handlers ────────────────────────────────────────────────────

  Future<void> _onLoadRequested(
    LinkLoadRequested event,
    Emitter<LinkState> emit,
  ) async {
    if (!event.silent) emit(const LinkLoading());
    try {
      final links = _repository.queryLinks(limit: _limit, offset: 0);
      emit(
        LinksLoaded(
          links: links,
          hasReachedMax: links.length < _limit,
          offset: links.length,
          customCategories: _customCategories,
          upNextLinks: _repository.getUpNextLinks(),
          unreadCount: _repository.unreadCount,
          quickCount: _repository.quickCount,
        ),
      );
    } catch (e) {
      emit(LinkError('Failed to load links: $e'));
    }
  }

  Future<void> _onLoadNextPageRequested(
    LinkLoadNextPageRequested event,
    Emitter<LinkState> emit,
  ) async {
    final current = state;
    if (current is! LinksLoaded ||
        current.hasReachedMax ||
        current.isLoadingMore) {
      return;
    }

    final loadingState = current.copyWith(isLoadingMore: true);
    emit(loadingState);

    try {
      final nextLinks = _repository.queryLinks(
        query: current.searchQuery,
        category: current.activeCategory,
        priority: current.activePriority,
        limit: _limit,
        offset: current.offset,
      );

      nextLinks.isEmpty
          ? emit(
              loadingState.copyWith(hasReachedMax: true, isLoadingMore: false),
            )
          : emit(
              loadingState.copyWith(
                links: List.of(current.links)..addAll(nextLinks),
                hasReachedMax: nextLinks.length < _limit,
                isLoadingMore: false,
                offset: current.offset + nextLinks.length,
              ),
            );
    } catch (e) {
      emit(LinkError('Failed to load more links: $e'));
    }
  }

  void _onSearchChanged(LinkSearchChanged event, Emitter<LinkState> emit) {
    final current = state;
    final cat = current is LinksLoaded ? current.activeCategory : 'All';
    final prio = current is LinksLoaded ? current.activePriority : 'All';
    final links = _repository.queryLinks(
      query: event.query,
      category: cat,
      priority: prio,
      limit: _limit,
      offset: 0,
    );
    emit(
      LinksLoaded(
        links: links,
        activeCategory: cat,
        activePriority: prio,
        searchQuery: event.query,
        hasReachedMax: links.length < _limit,
        offset: links.length,
        customCategories: _customCategories,
        upNextLinks: event.query.trim().isEmpty && cat == 'All' && prio == 'All'
            ? _repository.getUpNextLinks()
            : const [],
        unreadCount: _repository.unreadCount,
        quickCount: _repository.quickCount,
      ),
    );
  }

  void _onCategoryFilterChanged(
    LinkCategoryFilterChanged event,
    Emitter<LinkState> emit,
  ) {
    final current = state;
    final query = current is LinksLoaded ? current.searchQuery : '';
    final prio = current is LinksLoaded ? current.activePriority : 'All';
    final links = _repository.queryLinks(
      query: query,
      category: event.category,
      priority: prio,
      limit: _limit,
      offset: 0,
    );
    emit(
      LinksLoaded(
        links: links,
        activeCategory: event.category,
        activePriority: prio,
        searchQuery: query,
        hasReachedMax: links.length < _limit,
        offset: links.length,
        customCategories: _customCategories,
        upNextLinks: event.category == 'All' && prio == 'All' && query.trim().isEmpty
            ? _repository.getUpNextLinks()
            : const [],
        unreadCount: _repository.unreadCount,
        quickCount: _repository.quickCount,
      ),
    );
  }

  void _onPriorityFilterChanged(
    LinkPriorityFilterChanged event,
    Emitter<LinkState> emit,
  ) {
    final current = state;
    final query = current is LinksLoaded ? current.searchQuery : '';
    final cat = current is LinksLoaded ? current.activeCategory : 'All';
    final links = _repository.queryLinks(
      query: query,
      category: cat,
      priority: event.priority,
      limit: _limit,
      offset: 0,
    );
    emit(
      LinksLoaded(
        links: links,
        activeCategory: cat,
        activePriority: event.priority,
        searchQuery: query,
        hasReachedMax: links.length < _limit,
        offset: links.length,
        customCategories: _customCategories,
        upNextLinks: cat == 'All' && event.priority == 'All' && query.trim().isEmpty
            ? _repository.getUpNextLinks()
            : const [],
        unreadCount: _repository.unreadCount,
        quickCount: _repository.quickCount,
      ),
    );
  }

  Future<void> _onDeleteRequested(
    LinkDeleteRequested event,
    Emitter<LinkState> emit,
  ) async {
    try {
      await _repository.deleteLink(event.linkId);
      final current = state;
      if (current is LinksLoaded) {
        final links = _repository.queryLinks(
          query: current.searchQuery,
          category: current.activeCategory,
          priority: current.activePriority,
          limit: current.offset,
          offset: 0,
        );
        emit(
          current.copyWith(
            links: links,
            offset: links.length,
            hasReachedMax: links.length < current.offset,
          ),
        );
      } else {
        add(const LinkLoadRequested());
      }
    } catch (e) {
      emit(LinkError('Failed to delete link: $e'));
    }
  }

  Future<void> _onSyncRequested(
    LinkSyncRequested event,
    Emitter<LinkState> emit,
  ) async {
    final current = state;
    if (current is! LinksLoaded) {
      emit(const LinkLoading());
    }
    try {
      final startTime = DateTime.now();

      // Push and pull remain one serialized operation when the engine is wired.
      if (_syncEngine != null) {
        await _syncEngine.requestSync(pull: true);
      } else {
        await _repository.syncPendingLinks();
        await _repository.pullFromCloud();
      }

      // 3. Reload local links, preserving current filters if possible
      String query = '';
      String cat = 'All';
      String prio = 'All';

      if (current is LinksLoaded) {
        query = current.searchQuery;
        cat = current.activeCategory;
        prio = current.activePriority;
      }

      final links = _repository.queryLinks(
        query: query,
        category: cat,
        priority: prio,
        limit: _limit,
        offset: 0,
      );

      emit(
        LinksLoaded(
          links: links,
          activeCategory: cat,
          activePriority: prio,
          searchQuery: query,
          hasReachedMax: links.length < _limit,
          offset: links.length,
          customCategories: _customCategories,
          upNextLinks: _repository.getUpNextLinks(),
          unreadCount: _repository.unreadCount,
          quickCount: _repository.quickCount,
        ),
      );

      // Ensure the spinner shows for at least half a second for UX
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed.inMilliseconds < 500) {
        await Future.delayed(
          Duration(milliseconds: 500 - elapsed.inMilliseconds),
        );
      }
    } catch (e) {
      emit(LinkError('Failed to sync links: $e'));
    } finally {
      if (!(event.completer?.isCompleted ?? true)) {
        event.completer?.complete();
      }
    }
  }

  // ─── Mark As Read ──────────────────────────────────────────────────────────

  Future<void> _onMarkAsRead(
    LinkMarkAsRead event,
    Emitter<LinkState> emit,
  ) async {
    try {
      await _repository.markLinkAsRead(event.linkId);
      final current = state;
      if (current is LinksLoaded) {
        // Optimistically update the link in the list and refresh the strip.
        final updatedLinks = current.links
            .map((l) => l.id == event.linkId ? l.copyWith(isRead: true) : l)
            .toList();
        emit(current.copyWith(
          links: updatedLinks,
          upNextLinks: _repository.getUpNextLinks(),
          unreadCount: _repository.unreadCount,
        ));
      }
    } catch (e) {
      printLog(tag: 'LinkBloc', msg: 'Failed to mark link as read: $e');
    }
  }

  Future<void> _onMarkAsUnread(
    LinkMarkAsUnread event,
    Emitter<LinkState> emit,
  ) async {
    try {
      await _repository.markLinkAsUnread(event.linkId);
      final current = state;
      if (current is LinksLoaded) {
        // Optimistically update the link in the list and refresh the strip.
        final updatedLinks = current.links
            .map((l) => l.id == event.linkId ? l.copyWith(isRead: false) : l)
            .toList();
        emit(current.copyWith(
          links: updatedLinks,
          upNextLinks: _repository.getUpNextLinks(),
          unreadCount: _repository.unreadCount,
        ));
      }
    } catch (e) {
      printLog(tag: 'LinkBloc', msg: 'Failed to mark link as unread: $e');
    }
  }

  // ─── Custom Category Handlers ──────────────────────────────────────────────

  /// Handles [LinkCustomCategoryAdded].
  ///
  /// Creates a new [CategoryModel] via the repository (which persists it in
  /// Hive and optionally pushes it to Firestore for authenticated users), then
  /// re-emits the current [LinksLoaded] with the refreshed [customCategories]
  /// list so the UI updates instantly.
  ///
  /// Silently ignores blank names — the UI should validate before dispatching.
  Future<void> _onCustomCategoryAdded(
    LinkCustomCategoryAdded event,
    Emitter<LinkState> emit,
  ) async {
    final trimmed = event.name.trim();
    if (trimmed.isEmpty) return;

    try {
      await _repository.addCategory(
        CategoryModel(id: '', name: trimmed), // repository generates the UUID
      );
      final current = state;
      if (current is LinksLoaded) {
        emit(current.copyWith(customCategories: _customCategories));
      }
    } on CategoryAlreadyExistsException {
      emit(const LinkError('', code: LinkErrorCode.duplicateCategory));
    } catch (e) {
      emit(LinkError('Failed to add category: $e'));
    }
  }

  /// Handles [LinkCustomCategoryDeleted].
  ///
  /// Removes the category from the repository (Hive + Firestore), then
  /// re-emits [LinksLoaded] with the updated list. If the deleted category was
  /// the active filter, the filter is reset to 'All' and the link list reloads.
  Future<void> _onCustomCategoryDeleted(
    LinkCustomCategoryDeleted event,
    Emitter<LinkState> emit,
  ) async {
    try {
      await _repository.deleteCategory(event.categoryId);
      final current = state;
      if (current is LinksLoaded) {
        // If the deleted category was active, reset filter and reload links.
        final deletedName = current.customCategories
            .where((c) => c.id == event.categoryId)
            .map((c) => c.name)
            .firstOrNull;

        final newCategory =
            (deletedName != null && current.activeCategory == deletedName)
            ? 'All'
            : current.activeCategory;

        final links = _repository.queryLinks(
          query: current.searchQuery,
          category: newCategory,
          priority: current.activePriority,
          limit: _limit,
          offset: 0,
        );

        emit(
          current.copyWith(
            links: links,
            activeCategory: newCategory,
            offset: links.length,
            hasReachedMax: links.length < _limit,
            customCategories: _customCategories,
          ),
        );
      }
    } catch (e) {
      emit(LinkError('Failed to delete category: $e'));
    }
  }
}

extension on LinksLoaded {
  LinksLoaded copyWith({
    List<LinkModel>? links,
    String? activeCategory,
    String? activePriority,
    String? searchQuery,
    bool? hasReachedMax,
    bool? isLoadingMore,
    int? offset,
    List<CategoryModel>? customCategories,
    List<LinkModel>? upNextLinks,
    int? unreadCount,
    int? quickCount,
  }) {
    return LinksLoaded(
      links: links ?? this.links,
      activeCategory: activeCategory ?? this.activeCategory,
      activePriority: activePriority ?? this.activePriority,
      searchQuery: searchQuery ?? this.searchQuery,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      offset: offset ?? this.offset,
      customCategories: customCategories ?? this.customCategories,
      upNextLinks: upNextLinks ?? this.upNextLinks,
      unreadCount: unreadCount ?? this.unreadCount,
      quickCount: quickCount ?? this.quickCount,
    );
  }
}
