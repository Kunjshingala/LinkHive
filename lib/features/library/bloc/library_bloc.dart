import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/sync_engine.dart';
import '../../links/manager/link_manager.dart';

part 'library_event.dart';
part 'library_state.dart';

/// The Library overview: count tiles, sources and categories.
///
/// Reloads silently whenever links change, so counts stay current after
/// edits made in the list, the Add form, Today or a share.
class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  final LinkManager _manager;
  final SyncEngine? _syncEngine;

  /// Subscription to the links box. Cancelled in [close].
  late final StreamSubscription<void> _boxSubscription;

  /// Shortest time the refresh spinner shows, so a fast sync doesn't flicker.
  static const _minRefreshDuration = Duration(milliseconds: 500);

  LibraryBloc({required LinkManager manager, SyncEngine? syncEngine})
    : _manager = manager,
      _syncEngine = syncEngine,
      super(const LibraryInitial()) {
    on<LibraryLoadRequested>(_onLoadRequested);
    on<LibrarySyncRequested>(_onSyncRequested);

    _boxSubscription = _manager.watchLinks().listen((_) {
      if (state is LibraryLoaded) add(const LibraryLoadRequested(silent: true));
    });
  }

  @override
  Future<void> close() {
    _boxSubscription.cancel();
    return super.close();
  }

  Future<void> _onLoadRequested(
    LibraryLoadRequested event,
    Emitter<LibraryState> emit,
  ) async {
    if (!event.silent) emit(const LibraryLoading());
    try {
      emit(_loaded());
    } catch (e) {
      emit(LibraryError(message: e.toString()));
    }
  }

  Future<void> _onSyncRequested(
    LibrarySyncRequested event,
    Emitter<LibraryState> emit,
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
      emit(_loaded());
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed < _minRefreshDuration) {
        await Future<void>.delayed(_minRefreshDuration - elapsed);
      }
    } catch (e) {
      emit(LibraryError(message: e.toString()));
    } finally {
      final completer = event.completer;
      if (completer != null && !completer.isCompleted) completer.complete();
    }
  }

  LibraryLoaded _loaded() => LibraryLoaded(
    stats: _manager.getLibraryStats(),
    sources: _manager.getSourceCounts(),
    categories: _manager.getCategoryCounts(),
  );
}
