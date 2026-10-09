import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/category_suggester.dart';
import '../../../core/utils/url_canonical.dart';
import '../../links/manager/link_manager.dart';
import '../../links/models/link_model.dart';

class CategoryPickerState extends Equatable {
  const CategoryPickerState({
    required this.host,
    required this.suggested,
    required this.others,
    this.picked,
  });

  /// The one site every selected link comes from, or empty when they differ.
  final String host;

  /// Suggestions for [host]; empty when there is no single site.
  final List<String> suggested;

  /// Every other category to offer.
  final List<String> others;

  /// The category the sheet will add; starts on the top suggestion.
  final String? picked;

  CategoryPickerState copyWith({String? picked}) => CategoryPickerState(
    host: host,
    suggested: suggested,
    others: others,
    picked: picked ?? this.picked,
  );

  @override
  List<Object?> get props => [host, suggested, others, picked];
}

/// Drives the bulk "Add a category" sheet: suggests categories from the site
/// when every selected link comes from the same one.
class CategoryPickerCubit extends Cubit<CategoryPickerState> {
  CategoryPickerCubit({
    required LinkManager manager,
    required Iterable<String> selectedIds,
  }) : super(_initial(manager, selectedIds));

  static CategoryPickerState _initial(
    LinkManager manager,
    Iterable<String> selectedIds,
  ) {
    final hosts = selectedIds
        .map(manager.linkById)
        .whereType<LinkModel>()
        .map((l) => sourceHost(l.url))
        .toSet();
    final host = hosts.length == 1 ? hosts.single : '';
    final suggested = CategorySuggester.suggest(
      host: host,
      history: host.isEmpty ? const [] : manager.getCategoryCountsForHost(host),
    );
    return CategoryPickerState(
      host: host,
      suggested: suggested,
      others: manager
          .categoryOptions()
          .where((name) => !suggested.contains(name))
          .toList(),
      picked: suggested.isEmpty ? null : suggested.first,
    );
  }

  void pick(String name) => emit(state.copyWith(picked: name));
}
