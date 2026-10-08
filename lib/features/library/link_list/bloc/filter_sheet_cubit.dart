import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../links/manager/link_manager.dart';

/// The filter sheet's draft: the query being built and how many links it
/// matches right now. Nothing changes in the list until the sheet is applied.
class FilterSheetState extends Equatable {
  const FilterSheetState({
    required this.query,
    required this.matchCount,
    required this.categories,
    required this.sources,
  });

  final LinkQuery query;
  final int matchCount;

  /// Category names to offer, from [LinkManager.categoryOptions].
  final List<String> categories;

  /// Top source sites to offer, plus the selected one if it isn't a top one.
  final List<String> sources;

  @override
  List<Object?> get props => [query, matchCount, categories, sources];
}

/// Drives the filter sheet: toggles categories, priorities and one source,
/// and keeps the live match count current.
class FilterSheetCubit extends Cubit<FilterSheetState> {
  FilterSheetCubit({
    required LinkManager manager,
    required LinkQuery initial,
    required LinkQuery scope,
  }) : this._(manager, scope, _topSourcesOf(manager), initial);

  FilterSheetCubit._(
    this._manager,
    this._scope,
    this._topSources,
    LinkQuery initial,
  ) : super(
        FilterSheetState(
          query: initial,
          matchCount: _manager.countLinks(initial),
          categories: _manager.categoryOptions(),
          sources: _sourcesFor(initial, _topSources),
        ),
      );

  final LinkManager _manager;

  /// What the list was opened with; [reset] returns to it.
  final LinkQuery _scope;
  final List<String> _topSources;

  static const maxSources = 8;

  static List<String> _topSourcesOf(LinkManager manager) => manager
      .getSourceCounts()
      .take(maxSources)
      .map((s) => s.name)
      .toList();

  /// The top sources, plus the selected one if it isn't among them.
  static List<String> _sourcesFor(LinkQuery query, List<String> top) {
    final host = query.host;
    return host == null || top.contains(host) ? top : [...top, host];
  }

  void toggleCategory(String name) {
    final next = {...state.query.categories};
    if (!next.remove(name)) next.add(name);
    _update(state.query.copyWith(categories: next));
  }

  /// [priority] is `'High'`, `'Normal'` or `'Low'`.
  void togglePriority(String priority) {
    final next = {...state.query.priorities};
    if (!next.remove(priority)) next.add(priority);
    _update(state.query.copyWith(priorities: next));
  }

  void toggleSource(String host) => _update(
    state.query.host == host
        ? state.query.copyWith(clearHost: true)
        : state.query.copyWith(host: host),
  );

  /// Back to the list's scope, keeping the read tab, sort and search.
  void reset() => _update(
    _scope.copyWith(
      readFilter: state.query.readFilter,
      sort: state.query.sort,
      search: state.query.search,
    ),
  );

  void _update(LinkQuery query) => emit(
    FilterSheetState(
      query: query,
      matchCount: _manager.countLinks(query),
      categories: state.categories,
      sources: _sourcesFor(query, _topSources),
    ),
  );
}
