import '../../../core/models/sync_operation.dart';
import '../../../core/services/sync_status.dart';
import '../models/category_model.dart';
import '../models/link_model.dart';

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

  /// True while a wipe is in progress, or was interrupted before it finished.
  bool get isWipePending;

  Future<void> setWipePending(bool pending);
}

/// Marks one sync run. It goes stale when the phone is wiped, and a stale run
/// can no longer write anything locally.
class SyncRunToken {
  const SyncRunToken(this.generation);

  /// The store's wipe count when the run began.
  final int generation;
}

/// What `CloudSyncService` may touch in the local data during a push or pull.
///
/// Every write takes the run's token, checks it right before the write starts,
/// and returns false without writing once the phone was wiped. The caller then
/// stops the run. Reads need no token. `LinkRepository` implements it.
abstract interface class SyncStore {
  /// Makes sure the local data belongs to [uid], then starts a run:
  /// * same owner: nothing to do;
  /// * no owner (a guest, or an install from before owners were recorded):
  ///   keep the data, reset the pull cursor once so the first pull is a full
  ///   fetch, and record [uid] as the owner;
  /// * a different owner: wipe all sync state and record [uid] as the owner.
  ///
  /// Returns null if another wipe happened meanwhile.
  Future<SyncRunToken?> beginRun(String uid);

  /// Whether no wipe happened since [run] began.
  bool isCurrentRun(SyncRunToken run);

  // ─── Reads ────────────────────────────────────────────────────────────────

  /// Queued operations whose next attempt is due at [nowMs], oldest first.
  List<SyncOperation> dueOperations(int nowMs);

  /// Whether [operation] is still the queued one, unchanged since its upload
  /// started. An edit or delete queued meanwhile replaces or removes it.
  bool isStillInFlight(SyncOperation operation);

  LinkModel? getLinkById(String id);

  /// What the cloud held for link [id] at the last sync.
  LinkModel? getBaseLinkById(String id);

  bool hasPendingOperation(String entityType, String entityId);

  /// Whether [entityId] was deleted on this phone.
  bool hasLocalTombstone(String entityType, String entityId);

  /// When the last successful pull finished, in milliseconds since the epoch.
  int? get lastPulledAt;

  // ─── Unfinished cloud delete ──────────────────────────────────────────────
  //
  // Not sync state of a run: it outlives wipes and is not guarded.

  /// The uid whose "Delete cloud data" has not finished, or null.
  String? get cloudDeletePendingFor;

  Future<void> setCloudDeletePendingFor(String? uid);

  // ─── Guarded writes ───────────────────────────────────────────────────────

  Future<bool> putOperation(SyncRunToken run, SyncOperation operation);

  /// Records that [operation] reached the cloud, without losing a change
  /// queued while its upload waited.
  Future<bool> finishPushed(SyncRunToken run, SyncOperation operation);

  /// Stores [cloudLink] as both the local link and its base.
  Future<bool> putCloudLink(SyncRunToken run, LinkModel cloudLink);

  /// Stores [merged] locally and [cloudLink] as its base, and queues the merge
  /// when it kept local edits.
  Future<bool> applyMerge(SyncRunToken run, LinkModel merged, LinkModel cloudLink);

  /// Removes link [id] and its base.
  Future<bool> removeLink(SyncRunToken run, String id);

  Future<bool> removeBaseLink(SyncRunToken run, String id);

  Future<bool> saveConflict(
    SyncRunToken run, {
    required String linkId,
    required LinkModel base,
    required LinkModel local,
    required LinkModel? cloud,
    required List<String> fields,
  });

  Future<bool> putCategory(SyncRunToken run, CategoryModel category);

  Future<bool> removeCategory(SyncRunToken run, String id);

  /// Forgets when the last pull finished, so this pull fetches everything.
  Future<bool> resetPullCursor(SyncRunToken run);

  Future<bool> writePullCursor(SyncRunToken run, int timestampMs);
}
