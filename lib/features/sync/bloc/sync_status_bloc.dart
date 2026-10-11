import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/sync_engine.dart';
import 'sync_status_event.dart';
import 'sync_status_state.dart';

class SyncStatusBloc extends Bloc<SyncStatusEvent, SyncStatusState> {
  late final StreamSubscription<SyncStatusEvent> _statusSubscription;

  SyncStatusBloc({required SyncEngine syncEngine})
    : super(SyncStatusState(syncEngine.snapshot)) {
    on<SyncStatusChanged>(
      (event, emit) => emit(SyncStatusState(event.snapshot)),
    );
    _statusSubscription = syncEngine
        .watch()
        .map<SyncStatusEvent>(SyncStatusChanged.new)
        .listen(add);
  }

  @override
  Future<void> close() async {
    await _statusSubscription.cancel();
    return super.close();
  }
}
