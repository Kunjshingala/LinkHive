import '../../../core/services/sync_status.dart';

/// What the account session needs from the local data.
///
/// A narrow contract, so signing out only touches what it has to.
/// `LinkRepository` implements it.
abstract interface class LocalDataStore {
  /// What has not reached the cloud yet.
  UnsyncedSummary unsyncedSummary();

  /// Clears all sync state: links, categories, the queue, tombstones,
  /// conflicts, the pull cursor and the recorded owner. Theme and language are
  /// not sync state and stay.
  Future<void> clearLocalData();

  /// Deletes the signed-in account's data from the cloud. Irreversible.
  Future<void> clearRemoteData();

  /// True while a wipe is in progress, or was interrupted before it finished.
  bool get isWipePending;

  Future<void> setWipePending(bool pending);
}
