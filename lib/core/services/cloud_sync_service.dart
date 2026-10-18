import 'package:firebase_auth/firebase_auth.dart';

import '../../features/links/models/category_model.dart';
import '../../features/links/models/link_model.dart';
import '../../features/links/repository/local_data_store.dart';
import '../models/sync_operation.dart';
import '../utils/sync_backoff.dart';
import '../utils/sync_merge_helper.dart';
import '../utils/utils.dart';
import 'firebase_firestore_service.dart';
import 'sync_status.dart';

/// What the account session needs to delete the account's cloud data.
///
/// A narrow contract, so the session reaches nothing else of the sync layer.
/// [CloudSyncService] implements it.
abstract interface class RemoteDataStore {
  /// Deletes the signed-in account's data from the cloud. Irreversible.
  Future<void> clearRemoteData();
}

/// The only class that talks to Firestore for links and categories: pushes
/// the outbox, pulls what changed, and merges it into the local data.
///
/// `SyncService` decides when to sync and `SyncEngine` runs one sync at a
/// time; this class does the work of one push or pull. It reads and writes the
/// phone only through [SyncStore], whose writes stop once the phone is wiped.
class CloudSyncService implements RemoteDataStore {
  CloudSyncService({
    required FirebaseFirestoreService firebaseService,
    required SyncStore store,
    String? Function()? uidProvider,
  }) : _firebaseService = firebaseService,
       _store = store,
       _uidProvider = uidProvider ?? (() => FirebaseAuth.instance.currentUser?.uid);

  final FirebaseFirestoreService _firebaseService;
  final SyncStore _store;
  final String? Function() _uidProvider;

  static const _tag = 'CloudSyncService';

  // 60-second overlap so records written near the cursor boundary are never
  // missed due to clock skew between the client and Firestore servers.
  static const int _pullOverlapMs = 60 * 1000;

  /// Why the last attempt to push a queued write failed, or null if none did.
  /// Reset when a push starts; lives in memory only.
  SyncFailure? _lastFailure;

  /// Why the last push attempt failed, or null if none did since it started.
  SyncFailure? get lastFailure => _lastFailure;

  /// Sends the queued writes to the cloud, oldest first.
  Future<void> push() async {
    final uid = _uidProvider();
    if (uid == null) return;
    if (!await _push(uid)) _logStopped();
  }

  /// Fetches what changed in the cloud and reconciles it with the phone.
  ///
  /// Uses an incremental cursor: the first pull fetches everything; later
  /// pulls fetch only records synced within the overlap window of the last
  /// pull. [full] forgets the cursor first, to fetch everything again.
  Future<void> pull({bool full = false}) async {
    final uid = _uidProvider();
    if (uid == null) return;
    if (!await _pull(uid, full: full)) _logStopped();
  }

  @override
  Future<void> clearRemoteData() async {
    final uid = _uidProvider();
    if (uid == null) return;
    await _firebaseService.clearUserData(uid);
    printLog(tag: _tag, msg: 'Cleared remote data for uid=$uid');
  }

  void _logStopped() => printLog(tag: _tag, msg: 'Run stopped: local data was wiped');

  // ─── Push ──────────────────────────────────────────────────────────────────

  /// Returns false when the run stopped because the phone was wiped.
  Future<bool> _push(String uid) async {
    final run = await _store.beginRun(uid);
    if (run == null) return false;
    _lastFailure = null;

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final operation in _store.dueOperations(now)) {
      final processingOperation = operation.copyWith(state: SyncOperation.processing);
      if (!await _store.putOperation(run, processingOperation)) return false;
      try {
        await _send(uid, processingOperation);
        if (!await _store.finishPushed(run, processingOperation)) return false;
      } catch (e) {
        if (!_store.isCurrentRun(run)) return false;
        _lastFailure = SyncFailure.fromError(e);
        // A change queued while this upload waited replaced the operation;
        // writing the failed one back would drop that newer change.
        if (!_store.isStillInFlight(processingOperation)) continue;
        final attemptCount = processingOperation.attemptCount + 1;
        final retryAt = now + SyncBackoff.delayForAttempt(attemptCount).inMilliseconds;
        final failed = processingOperation.copyWith(
          state: SyncOperation.failed,
          attemptCount: attemptCount,
          nextAttemptAt: retryAt,
          lastError: e.toString(),
        );
        if (!await _store.putOperation(run, failed)) return false;
        printLog(tag: _tag, msg: 'Syncing operation failed: $e');
      }
    }
    return true;
  }

  Future<void> _send(String uid, SyncOperation operation) async {
    if (operation.entityType == SyncOperation.linkEntity) {
      if (operation.operationType == SyncOperation.delete) {
        await _firebaseService.deleteLink(uid, operation.entityId);
        return;
      }

      final link = LinkModel.fromFirestore(operation.entityId, operation.payload);
      if (operation.operationType == SyncOperation.create) {
        await _firebaseService.saveLink(uid, link);
      } else {
        await _firebaseService.updateLink(uid, link);
      }
      return;
    }

    if (operation.entityType == SyncOperation.categoryEntity) {
      if (operation.operationType == SyncOperation.delete) {
        await _firebaseService.deleteCategory(uid, operation.entityId);
      } else {
        final category = CategoryModel.fromFirestore(operation.entityId, operation.payload);
        await _firebaseService.saveCategory(uid, category);
      }
    }
  }

  // ─── Pull ──────────────────────────────────────────────────────────────────

  /// Returns false when the run stopped because the phone was wiped.
  Future<bool> _pull(String uid, {required bool full}) async {
    final run = await _store.beginRun(uid);
    if (run == null) return false;
    if (full && !await _store.resetPullCursor(run)) return false;

    // Snapshot the current time before querying so any record written to
    // Firestore during this pull is caught by the next pull's overlap window.
    final newCursor = DateTime.now().toUtc().millisecondsSinceEpoch;

    final cursor = _store.lastPulledAt;
    final List<LinkModel> cloudLinks;
    if (cursor == null) {
      cloudLinks = await _firebaseService.fetchLinks(uid);
    } else {
      cloudLinks = await _firebaseService.fetchLinksSince(uid, cursor - _pullOverlapMs);
    }

    final List<String> deletedIds;
    if (cursor == null) {
      deletedIds = await _firebaseService.fetchDeletedLinks(uid);
    } else {
      deletedIds = await _firebaseService.fetchDeletedLinksSince(uid, cursor - _pullOverlapMs);
    }

    for (final delId in deletedIds) {
      if (!await _applyCloudDelete(run, delId)) return false;
    }
    for (final cloudLink in cloudLinks) {
      if (!await _applyCloudLink(run, cloudLink)) return false;
    }

    final cloudCategories = await _firebaseService.fetchCategories(uid);
    for (final category in cloudCategories) {
      if (_store.hasLocalTombstone(SyncOperation.categoryEntity, category.id) ||
          _store.hasPendingOperation(SyncOperation.categoryEntity, category.id)) {
        continue;
      }
      if (!await _store.putCategory(run, category)) return false;
    }

    final List<String> deletedCategoryIds;
    if (cursor == null) {
      deletedCategoryIds = await _firebaseService.fetchDeletedCategories(uid);
    } else {
      deletedCategoryIds = await _firebaseService.fetchDeletedCategoriesSince(uid, cursor - _pullOverlapMs);
    }
    for (final categoryId in deletedCategoryIds) {
      if (_store.hasLocalTombstone(SyncOperation.categoryEntity, categoryId) ||
          _store.hasPendingOperation(SyncOperation.categoryEntity, categoryId)) {
        continue;
      }
      if (!await _store.removeCategory(run, categoryId)) return false;
    }

    // Advance the pull cursor only after all reconciliation succeeds, and not
    // at all if the phone was wiped meanwhile: that cursor would belong to
    // data that is gone.
    return _store.writePullCursor(run, newCursor);
  }

  Future<bool> _applyCloudDelete(SyncRunToken run, String delId) async {
    if (_store.hasLocalTombstone(SyncOperation.linkEntity, delId)) {
      return _store.isCurrentRun(run);
    }

    final localLink = _store.getLinkById(delId);
    final baseLink = _store.getBaseLinkById(delId);
    if (localLink == null) return _store.removeBaseLink(run, delId);

    if (_store.hasPendingOperation(SyncOperation.linkEntity, delId) ||
        (baseLink != null && SyncMergeHelper.hasLocalEdits(baseLink, localLink))) {
      return _store.saveConflict(
        run,
        linkId: delId,
        base: baseLink ?? localLink,
        local: localLink,
        cloud: null,
        fields: const ['delete'],
      );
    }

    return _store.removeLink(run, delId);
  }

  Future<bool> _applyCloudLink(SyncRunToken run, LinkModel cloudLink) async {
    if (_store.hasLocalTombstone(SyncOperation.linkEntity, cloudLink.id)) {
      return _store.isCurrentRun(run);
    }

    final localLink = _store.getLinkById(cloudLink.id);
    final baseLink = _store.getBaseLinkById(cloudLink.id);
    if (_store.hasPendingOperation(SyncOperation.linkEntity, cloudLink.id)) {
      if (localLink == null || baseLink == null) {
        return _store.isCurrentRun(run);
      }
      final pendingConflicts = SyncMergeHelper.conflictingFields(base: baseLink, local: localLink, cloud: cloudLink);
      if (pendingConflicts.isEmpty) return _store.isCurrentRun(run);
      return _store.saveConflict(
        run,
        linkId: cloudLink.id,
        base: baseLink,
        local: localLink,
        cloud: cloudLink,
        fields: pendingConflicts,
      );
    }

    if (localLink == null || baseLink == null) {
      return _store.putCloudLink(run, cloudLink);
    }

    final conflicts = SyncMergeHelper.conflictingFields(base: baseLink, local: localLink, cloud: cloudLink);
    if (conflicts.isNotEmpty) {
      return _store.saveConflict(
        run,
        linkId: cloudLink.id,
        base: baseLink,
        local: localLink,
        cloud: cloudLink,
        fields: conflicts,
      );
    }

    final mergedLink = SyncMergeHelper.merge(base: baseLink, local: localLink, cloud: cloudLink);
    return _store.applyMerge(run, mergedLink, cloudLink);
  }
}
