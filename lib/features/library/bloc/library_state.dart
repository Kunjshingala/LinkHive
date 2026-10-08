part of 'library_bloc.dart';

sealed class LibraryState extends Equatable {
  const LibraryState();

  @override
  List<Object?> get props => [];
}

class LibraryInitial extends LibraryState {
  const LibraryInitial();
}

class LibraryLoading extends LibraryState {
  const LibraryLoading();
}

class LibraryLoaded extends LibraryState {
  const LibraryLoaded({
    required this.stats,
    required this.sources,
    required this.categories,
  });

  final LibraryStats stats;

  /// Every source site, most links first. The overview shows the top few.
  final List<NamedCount> sources;

  /// Every category in use, most links first.
  final List<NamedCount> categories;

  @override
  List<Object?> get props => [stats, sources, categories];
}

class LibraryError extends LibraryState {
  const LibraryError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
