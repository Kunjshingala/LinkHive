import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../links/models/link_model.dart';
import '../../links/manager/link_manager.dart';

part 'inbox_event.dart';
part 'inbox_state.dart';

/// BLoC for the Inbox — the list of quick-saved (unorganized) links.
///
/// Like [LinkBloc], it subscribes to the Hive links box so the list stays in
/// sync automatically: organizing a link through the edit form flips its
/// `isQuickSaved` flag (removing it here) and deleting one drops it, both via
/// external box writes.
class InboxBloc extends Bloc<InboxEvent, InboxState> {
  final LinkManager _manager;

  /// Subscription to the Hive links box stream. Cancelled in [close].
  late final StreamSubscription<void> _boxSubscription;

  InboxBloc({required LinkManager manager})
    : _manager = manager,
      super(const InboxInitial()) {
    on<InboxLoadRequested>(_onLoadRequested);
    on<InboxLinkDeleted>(_onLinkDeleted);

    _boxSubscription = _manager.watchLinks().listen((_) {
      if (state is InboxLoaded) {
        add(const InboxLoadRequested(silent: true));
      }
    });
  }

  @override
  Future<void> close() {
    _boxSubscription.cancel();
    return super.close();
  }

  Future<void> _onLoadRequested(
    InboxLoadRequested event,
    Emitter<InboxState> emit,
  ) async {
    if (!event.silent) emit(const InboxLoading());
    try {
      emit(InboxLoaded(links: _manager.queryQuickLinks()));
    } catch (e) {
      emit(InboxError('Failed to load inbox: $e'));
    }
  }

  Future<void> _onLinkDeleted(
    InboxLinkDeleted event,
    Emitter<InboxState> emit,
  ) async {
    try {
      await _manager.deleteLink(event.linkId);
      // The box watch also refreshes, but emit immediately for a snappy UI.
      emit(InboxLoaded(links: _manager.queryQuickLinks()));
    } catch (e) {
      emit(InboxError('Failed to delete link: $e'));
    }
  }
}
