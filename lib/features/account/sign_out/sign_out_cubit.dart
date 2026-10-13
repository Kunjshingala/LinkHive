import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/account_session_service.dart';
import '../../../core/services/sync_status.dart';

/// The live sync state behind the sign-out sheet.
///
/// While the sheet is open it follows the sync engine, so the user always sees
/// what signing out would lose right now, and sees it change as sync runs.
class SignOutCubit extends Cubit<SyncSnapshot> {
  SignOutCubit({required AccountSessionService sessionService})
    : _sessionService = sessionService,
      super(sessionService.syncSnapshot) {
    _subscription = _sessionService.watchSync().listen(emit);
    if (!state.unsynced.isEmpty) unawaited(syncNow());
  }

  final AccountSessionService _sessionService;
  late final StreamSubscription<SyncSnapshot> _subscription;

  /// Asks for one sync. The result shows up through the snapshot.
  Future<void> syncNow() => _sessionService.requestSync();

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
