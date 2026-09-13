import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/sync_engine.dart';
import 'sync_status_event.dart';
import 'sync_status_state.dart';

class SyncStatusBloc extends Bloc<SyncStatusEvent, SyncStatusState> {
  final SyncEngine _syncEngine;
  late final StreamSubscription<SyncStatusEvent> _statusSubscription;

  SyncStatusBloc({required SyncEngine syncEngine})
    : _syncEngine = syncEngine,
      super(SyncStatusState(syncEngine.status)) {
    on<SyncStatusChanged>((event, emit) => emit(SyncStatusState(event.status)));
    _statusSubscription = _syncEngine.statusStream
        .map<SyncStatusEvent>(SyncStatusChanged.new)
        .listen(add);
  }

  @override
  Future<void> close() async {
    await _statusSubscription.cancel();
    return super.close();
  }
}
