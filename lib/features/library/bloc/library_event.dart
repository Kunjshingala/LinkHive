part of 'library_bloc.dart';

sealed class LibraryEvent extends Equatable {
  const LibraryEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the overview counts. [silent] skips the loading state, for reloads
/// triggered by link changes while the overview is already showing.
class LibraryLoadRequested extends LibraryEvent {
  const LibraryLoadRequested({this.silent = false});

  final bool silent;

  @override
  List<Object?> get props => [silent];
}

/// Pull-to-refresh: pushes local changes, pulls from the cloud, then reloads.
/// [completer] finishes when the refresh indicator can stop.
class LibrarySyncRequested extends LibraryEvent {
  const LibrarySyncRequested({this.completer});

  final Completer<void>? completer;

  @override
  List<Object?> get props => [completer];
}
