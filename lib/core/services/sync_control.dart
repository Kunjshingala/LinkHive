import 'sync_status.dart';

/// What the account session needs from the sync engine.
///
/// A narrow contract, so signing out cannot reach into the engine's other
/// parts. `SyncEngine` implements it.
abstract interface class SyncControl {
  /// Asks for a sync run. A pull requested during a push-only run is queued.
  Future<void> requestSync({bool pull = false});

  /// Refuses new sync runs, for example while the phone is being wiped.
  void pause();

  /// Accepts sync runs again.
  void resume();

  /// What the UI shows about sync right now.
  SyncSnapshot get snapshot;

  /// A new snapshot whenever something it shows changes.
  Stream<SyncSnapshot> watch();
}
