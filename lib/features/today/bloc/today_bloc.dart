import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../links/manager/link_manager.dart';
import '../../links/models/link_model.dart';

part 'today_event.dart';
part 'today_state.dart';

/// BLoC for the "Today" focus screen — the Daily Resurface pull-back.
///
/// Shows exactly one link at a time ([LinkManager.currentPick]) with three
/// actions:
/// - **Open** — launches the URL and marks the link consumed.
/// - **Archive** — marks it consumed without opening (already handled
///   elsewhere, or decided it's not worth revisiting).
/// - **Snooze** — leaves it unread, but records it was shown so the spaced
///   pool doesn't offer it again immediately.
///
/// Both Open and Archive advance to the next candidate automatically.
///
/// What each action *means* lives in [LinkManager], not here. This bloc
/// decides when an action happens and what state to emit; the manager owns
/// the launch, the bookkeeping writes and their ordering, so the widget and
/// the link cards behave identically to this screen.
class TodayBloc extends Bloc<TodayEvent, TodayState> {
  final LinkManager _manager;

  TodayBloc({required LinkManager manager})
    : _manager = manager,
      super(const TodayInitial()) {
    on<TodayLoadRequested>(_onLoadRequested);
    on<TodayOpenRequested>(_onOpenRequested);
    on<TodayArchiveRequested>(_onArchiveRequested);
    on<TodaySnoozeRequested>(_onSnoozeRequested);
  }

  Future<void> _onLoadRequested(
    TodayLoadRequested event,
    Emitter<TodayState> emit,
  ) async {
    emit(const TodayLoading());
    await _emitCandidate(emit);
  }

  Future<void> _onOpenRequested(
    TodayOpenRequested event,
    Emitter<TodayState> emit,
  ) async {
    final current = state;
    if (current is! TodayLoaded) return;
    final url = event.url;
    if (event.keepOnly && url != null) {
      await _manager.keepOnlyVersion(current.link, url);
    }
    await _manager.openLink(current.link, url: url);
    await _emitCandidate(emit);
  }

  Future<void> _onArchiveRequested(
    TodayArchiveRequested event,
    Emitter<TodayState> emit,
  ) async {
    final current = state;
    if (current is! TodayLoaded) return;
    await _manager.archiveLink(current.link);
    await _emitCandidate(emit);
  }

  Future<void> _onSnoozeRequested(
    TodaySnoozeRequested event,
    Emitter<TodayState> emit,
  ) async {
    final current = state;
    if (current is! TodayLoaded) return;
    await _manager.snoozeLink(current.link);
    await _emitCandidate(emit);
  }

  Future<void> _emitCandidate(Emitter<TodayState> emit) async {
    final link = _manager.currentPick();
    emit(link == null ? const TodayEmpty() : TodayLoaded(link));
  }
}
