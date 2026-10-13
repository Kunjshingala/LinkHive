import '../../features/links/repository/local_data_store.dart';
import '../utils/utils.dart';
import 'auth_service.dart';
import 'sync_control.dart';
import 'sync_status.dart';

/// How a sign-out or a wipe ended, when it did not fail.
enum SessionActionResult {
  /// The action was carried out.
  completed,

  /// More unsynced work exists than the user was shown, for example a link was
  /// saved while the confirmation was open. Nothing was changed: show the
  /// current state and ask again.
  needsReconfirmation,
}

/// Sequences every change of whose data is on this phone: signing out, and the
/// "Delete local data" action. See `.ai/context/sync-contract.md`.
///
/// ```
///  count unsynced work again; more than the user confirmed -> stop, change nothing
///  pause sync (no new runs)
///  wipe-pending marker on
///  [delete cloud data]            sign-out only, when the user asked for it
///  wipe all sync state            a run still waiting on the cloud stops writing
///  [sign out]                     sign-out only
///  marker off
///  resume sync                    always, also when a step above failed
/// ```
///
/// If the app dies between the marker and its removal, [recoverInterruptedWipe]
/// finishes the wipe at the next launch, before the first sync.
class AccountSessionService {
  AccountSessionService({
    required AuthService authService,
    required SyncControl sync,
    required LocalDataStore store,
  }) : _authService = authService,
       _sync = sync,
       _store = store;

  final AuthService _authService;
  final SyncControl _sync;
  final LocalDataStore _store;

  /// What a sign-out or wipe right now would lose.
  UnsyncedSummary unsyncedSummary() => _store.unsyncedSummary();

  /// The live sync state, for the sign-out sheet.
  SyncSnapshot get syncSnapshot => _sync.snapshot;

  Stream<SyncSnapshot> watchSync() => _sync.watch();

  /// Asks for one sync, for example when the sign-out sheet opens. Failures are
  /// shown through the sync status, not thrown.
  Future<void> requestSync() async {
    try {
      await _sync.requestSync();
    } catch (error) {
      printLog(tag: 'AccountSession', msg: 'Sync request failed: $error');
    }
  }

  /// Signs out and removes this phone's copy of the data.
  ///
  /// [confirmed] is what the user was shown. [clearRemote] also deletes the
  /// account's data in the cloud, which cannot be undone.
  ///
  /// Throws if a step fails. Sync is resumed and the wipe marker stays set
  /// until the sequence has finished, so a retry or the next launch completes
  /// it.
  Future<SessionActionResult> signOut({
    required UnsyncedSummary confirmed,
    bool clearRemote = false,
  }) {
    return _wipe(confirmed: confirmed, clearRemote: clearRemote, signOut: true);
  }

  /// Removes this phone's copy of the data and stays signed in. The next sync
  /// brings back everything that reached the cloud.
  Future<SessionActionResult> wipeLocalData({
    required UnsyncedSummary confirmed,
  }) {
    return _wipe(confirmed: confirmed, clearRemote: false, signOut: false);
  }

  /// Deletes the account's data in the cloud and this phone's copy, and stays
  /// signed in. The cloud data cannot be brought back.
  ///
  /// The phone's copy goes too: kept alone, it would no longer match the
  /// cloud, and edits to it would fail to sync.
  Future<SessionActionResult> deleteCloudData({
    required UnsyncedSummary confirmed,
  }) {
    return _wipe(confirmed: confirmed, clearRemote: true, signOut: false);
  }

  /// Finishes a wipe that was interrupted, for example by the app being
  /// killed. Call it at launch, before the first sync.
  Future<void> recoverInterruptedWipe() async {
    if (!_store.isWipePending) return;
    printLog(tag: 'AccountSession', msg: 'Finishing an interrupted wipe');
    await _store.clearLocalData();
    await _store.setWipePending(false);
  }

  Future<SessionActionResult> _wipe({
    required UnsyncedSummary confirmed,
    required bool clearRemote,
    required bool signOut,
  }) async {
    if (_store.unsyncedSummary().hasMoreThan(confirmed)) {
      return SessionActionResult.needsReconfirmation;
    }

    _sync.pause();
    try {
      await _store.setWipePending(true);
      if (clearRemote) await _store.clearRemoteData();
      await _store.clearLocalData();
      if (signOut) await _authService.signOut();
      await _store.setWipePending(false);
      return SessionActionResult.completed;
    } finally {
      _sync.resume();
    }
  }
}
