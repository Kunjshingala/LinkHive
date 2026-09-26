import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/utils.dart';
import '../../links/models/link_model.dart';
import '../../links/repository/link_repository.dart';

part 'today_event.dart';
part 'today_state.dart';

/// BLoC for the "Today" focus screen — the Daily Resurface pull-back.
///
/// Shows exactly one link at a time
/// ([LinkRepository.getResurfaceCandidate]) with three actions:
/// - **Open** — launches the URL and marks the link read (consumed).
/// - **Archive** — marks it read without opening (already handled elsewhere,
///   or decided it's not worth revisiting).
/// - **Snooze** — leaves it unread; [LinkRepository.markResurfaced] still
///   records it was shown, so the spaced pool doesn't offer it again
///   immediately.
///
/// Both Open and Archive advance to the next candidate automatically.
class TodayBloc extends Bloc<TodayEvent, TodayState> {
  final LinkRepository _repository;

  TodayBloc({required LinkRepository repository})
    : _repository = repository,
      super(const TodayInitial()) {
    on<TodayLoadRequested>(_onLoadRequested);
    on<TodayOpenRequested>(_onOpenRequested);
    on<TodayArchiveRequested>(_onArchiveRequested);
    on<TodaySnoozeRequested>(_onSnoozeRequested);
  }

  Future<void> _onLoadRequested(TodayLoadRequested event, Emitter<TodayState> emit) async {
    emit(const TodayLoading());
    await _emitCandidate(emit);
  }

  Future<void> _onOpenRequested(TodayOpenRequested event, Emitter<TodayState> emit) async {
    final current = state;
    if (current is! TodayLoaded) return;
    try {
      final uri = Uri.tryParse(current.link.url);
      if (uri != null) {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched) showSnackBar('Could not open ${current.link.url}');
      }
    } catch (_) {
      showSnackBar('Could not open ${current.link.url}');
    }
    await _repository.markLinkAsRead(current.link.id);
    await _repository.markResurfaced(current.link.id);
    await _emitCandidate(emit);
  }

  Future<void> _onArchiveRequested(TodayArchiveRequested event, Emitter<TodayState> emit) async {
    final current = state;
    if (current is! TodayLoaded) return;
    await _repository.markLinkAsRead(current.link.id);
    await _repository.markResurfaced(current.link.id);
    await _emitCandidate(emit);
  }

  Future<void> _onSnoozeRequested(TodaySnoozeRequested event, Emitter<TodayState> emit) async {
    final current = state;
    if (current is! TodayLoaded) return;
    // Record it was shown (so the spaced pool moves on) but leave it unread.
    await _repository.markResurfaced(current.link.id);
    await _emitCandidate(emit);
  }

  Future<void> _emitCandidate(Emitter<TodayState> emit) async {
    final link = _repository.getResurfaceCandidate();
    emit(link == null ? const TodayEmpty() : TodayLoaded(link));
  }
}
