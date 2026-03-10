import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

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
  static const _limit = 20;

  /// Subscription to the Hive links box stream.
  /// Cancelled in [close] to avoid memory leaks.
  late final StreamSubscription<void> _boxSubscription;

  LinkBloc({required LinkRepository repository}) : _repository = repository, super(const LinkInitial()) {
    on<LinkLoadRequested>(_onLoadRequested);
    on<LinkLoadNextPageRequested>(_onLoadNextPageRequested);
    on<LinkSearchChanged>(_onSearchChanged);
    on<LinkCategoryFilterChanged>(_onCategoryFilterChanged);
    on<LinkPriorityFilterChanged>(_onPriorityFilterChanged);
    on<LinkDeleteRequested>(_onDeleteRequested);
    on<LinkSyncRequested>(_onSyncRequested);
    on<LinkCustomCategoryAdded>(_onCustomCategoryAdded);
    on<LinkCustomCategoryDeleted>(_onCustomCategoryDeleted);

    // Subscribe to the Hive box stream so any external write (e.g. AddLinkBloc
    // saving a link on a different route) triggers a reload automatically.
    _boxSubscription = _repository.watchLinksBox().listen((_) {
      // Only reload when the list is visible. Ignore duplicate events that
      // arrive while a reload is already in progress (LinkLoading state).
      if (state is LinksLoaded) {
        add(const LinkLoadRequested());
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

  Future<void> _onLoadRequested(LinkLoadRequested event, Emitter<LinkState> emit) async {
    emit(const LinkLoading());
    try {
      final links = _repository.queryLinks(limit: _limit, offset: 0);
      emit(
        LinksLoaded(
          links: links,
          hasReachedMax: links.length < _limit,
          offset: links.length,
          customCategories: _customCategories,
        ),
      );
    } catch (e) {
      emit(LinkError('Failed to load links: $e'));
    }
  }

  Future<void> _onLoadNextPageRequested(LinkLoadNextPageRequested event, Emitter<LinkState> emit) async {
    final current = state;
    if (current is! LinksLoaded || current.hasReachedMax) return;

    try {
      final nextLinks = _repository.queryLinks(
        query: current.searchQuery,
        category: current.activeCategory,
        priority: current.activePriority,
        limit: _limit,
        offset: current.offset,
      );

      nextLinks.isEmpty
          ? emit(current.copyWith(hasReachedMax: true))
          : emit(
              current.copyWith(
                links: List.of(current.links)..addAll(nextLinks),
                hasReachedMax: nextLinks.length < _limit,
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
    final links = _repository.queryLinks(query: event.query, category: cat, priority: prio, limit: _limit, offset: 0);
    emit(
      LinksLoaded(
        links: links,
        activeCategory: cat,
        activePriority: prio,
        searchQuery: event.query,
        hasReachedMax: links.length < _limit,
        offset: links.length,
        customCategories: _customCategories,
      ),
    );
  }

  void _onCategoryFilterChanged(LinkCategoryFilterChanged event, Emitter<LinkState> emit) {
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
      ),
    );
  }

  void _onPriorityFilterChanged(LinkPriorityFilterChanged event, Emitter<LinkState> emit) {
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
      ),
    );
  }

  Future<void> _onDeleteRequested(LinkDeleteRequested event, Emitter<LinkState> emit) async {
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
        emit(current.copyWith(links: links, offset: links.length, hasReachedMax: links.length < current.offset));
      } else {
        add(const LinkLoadRequested());
      }
    } catch (e) {
      emit(LinkError('Failed to delete link: $e'));
    }
  }

  Future<void> _onSyncRequested(LinkSyncRequested event, Emitter<LinkState> emit) async {
    final current = state;
    if (current is! LinksLoaded) {
      emit(const LinkLoading());
    }
    try {
      final startTime = DateTime.now();

      // 1. Send local changes to cloud
      await _repository.syncPendingLinks();
      // 2. Fetch remote changes
      await _repository.pullFromCloud();

      // 3. Reload local links, preserving current filters if possible
      String query = '';
      String cat = 'All';
      String prio = 'All';

      if (current is LinksLoaded) {
        query = current.searchQuery;
        cat = current.activeCategory;
        prio = current.activePriority;
      }

      final links = _repository.queryLinks(query: query, category: cat, priority: prio, limit: _limit, offset: 0);

      emit(
        LinksLoaded(
          links: links,
          activeCategory: cat,
          activePriority: prio,
          searchQuery: query,
          hasReachedMax: links.length < _limit,
          offset: links.length,
          customCategories: _customCategories, // refresh after cloud pull
        ),
      );

      // Ensure the spinner shows for at least half a second for UX
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed.inMilliseconds < 500) {
        await Future.delayed(Duration(milliseconds: 500 - elapsed.inMilliseconds));
      }
    } catch (e) {
      emit(LinkError('Failed to sync links: $e'));
    } finally {
      if (!(event.completer?.isCompleted ?? true)) {
        event.completer?.complete();
      }
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
  Future<void> _onCustomCategoryAdded(LinkCustomCategoryAdded event, Emitter<LinkState> emit) async {
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
    } catch (e) {
      emit(LinkError('Failed to add category: $e'));
    }
  }

  /// Handles [LinkCustomCategoryDeleted].
  ///
  /// Removes the category from the repository (Hive + Firestore), then
  /// re-emits [LinksLoaded] with the updated list. If the deleted category was
  /// the active filter, the filter is reset to 'All' and the link list reloads.
  Future<void> _onCustomCategoryDeleted(LinkCustomCategoryDeleted event, Emitter<LinkState> emit) async {
    try {
      await _repository.deleteCategory(event.categoryId);
      final current = state;
      if (current is LinksLoaded) {
        // If the deleted category was active, reset filter and reload links.
        final deletedName = current.customCategories
            .where((c) => c.id == event.categoryId)
            .map((c) => c.name)
            .firstOrNull;

        final newCategory = (deletedName != null && current.activeCategory == deletedName)
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
    int? offset,
    List<CategoryModel>? customCategories,
  }) {
    return LinksLoaded(
      links: links ?? this.links,
      activeCategory: activeCategory ?? this.activeCategory,
      activePriority: activePriority ?? this.activePriority,
      searchQuery: searchQuery ?? this.searchQuery,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      offset: offset ?? this.offset,
      customCategories: customCategories ?? this.customCategories,
    );
  }
}
