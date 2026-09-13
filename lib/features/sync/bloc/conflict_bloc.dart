import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/utils.dart';
import '../../links/repository/link_repository.dart';
import 'conflict_event.dart';
import 'conflict_state.dart';

class ConflictBloc extends Bloc<ConflictEvent, ConflictState> {
  final LinkRepository _repository;

  ConflictBloc({required LinkRepository repository})
    : _repository = repository,
      super(const ConflictInitial()) {
    on<ConflictLoadRequested>(_onLoad);
    on<ConflictKeepLocalRequested>(_onKeepLocal);
    on<ConflictKeepCloudRequested>(_onKeepCloud);
    add(const ConflictLoadRequested());
  }

  void _onLoad(ConflictLoadRequested event, Emitter<ConflictState> emit) {
    emit(ConflictLoaded(_repository.conflicts));
  }

  Future<void> _onKeepLocal(
    ConflictKeepLocalRequested event,
    Emitter<ConflictState> emit,
  ) async {
    await _resolve(
      emit,
      () => _repository.resolveConflictKeepLocal(event.conflictId),
    );
  }

  Future<void> _onKeepCloud(
    ConflictKeepCloudRequested event,
    Emitter<ConflictState> emit,
  ) async {
    await _resolve(
      emit,
      () => _repository.resolveConflictKeepCloud(event.conflictId),
    );
  }

  Future<void> _resolve(
    Emitter<ConflictState> emit,
    Future<void> Function() action,
  ) async {
    emit(const ConflictLoading());
    try {
      await action();
      emit(ConflictLoaded(_repository.conflicts));
    } catch (error) {
      printLog(tag: 'ConflictBloc', msg: 'Conflict resolution failed: $error');
      emit(ConflictError('Conflict resolution failed: $error'));
    }
  }
}
