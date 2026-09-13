import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/conflict_record.dart';
import '../../../core/models/sync_operation.dart';
import '../../../core/models/sync_tombstone.dart';
import '../../../core/services/firebase_firestore_service.dart';
import '../../../core/utils/hive_helper.dart';
import '../../../core/utils/sync_backoff.dart';
import '../../../core/utils/sync_merge_helper.dart';
import '../../../core/utils/utils.dart';
import '../../../core/utils/category_utils.dart';
import '../models/category_model.dart';
import '../models/link_model.dart';

class CategoryAlreadyExistsException implements Exception {
  const CategoryAlreadyExistsException();
}

/// Repository that manages all [LinkModel] and [CategoryModel] persistence.
///
/// ## Offline-first Architecture
/// Every read and write goes to the **local Hive boxes first**.
/// Firestore is treated as an optional, best-effort sync layer.
class LinkRepository {
  final FirebaseFirestoreService _firebaseService;
  final HiveHelper _hiveHelper;
  final String? Function() _uidProvider;

  LinkRepository({
    required FirebaseFirestoreService firebaseService,
    required HiveHelper hiveHelper,
    String? Function()? uidProvider,
  }) : _firebaseService = firebaseService,
       _hiveHelper = hiveHelper,
       _uidProvider =
           uidProvider ?? (() => FirebaseAuth.instance.currentUser?.uid);

  Box<LinkModel> get _linksBox => _hiveHelper.linksBox;
  Box<LinkModel> get _baseLinksBox => _hiveHelper.baseLinksBox;
  Box<LinkModel> get _conflictLinksBox => _hiveHelper.conflictLinksBox;
  Box<CategoryModel> get _categoriesBox => _hiveHelper.categoriesBox;
  Box<SyncOperation> get _syncOperationsBox => _hiveHelper.syncOperationsBox;
  Box<SyncTombstone> get _syncTombstonesBox => _hiveHelper.syncTombstonesBox;
  Box<ConflictRecord> get _conflictRecordsBox => _hiveHelper.conflictRecordsBox;

  static const _uuid = Uuid();

  String? get _uid => _uidProvider();

  // ─── Link CRUD ─────────────────────────────────────────────────────────────

  Future<void> addLink(LinkModel link) async {
    final l = link.id.isEmpty ? link.copyWith(id: _uuid.v4()) : link;
    final localLink = l.copyWith(isSynced: false);

    await _linksBox.put(localLink.id, localLink);
    await _enqueueOperation(
      entityType: SyncOperation.linkEntity,
      entityId: localLink.id,
      operationType: SyncOperation.create,
      payload: localLink.toSyncPayload(),
    );
    printLog(
      tag: 'LinkRepository',
      msg: 'Added link locally: ${localLink.title}',
    );
  }

  Future<void> updateLink(LinkModel link) async {
    final localLink = link.copyWith(isSynced: false);
    await _linksBox.put(localLink.id, localLink);
    await _enqueueOperation(
      entityType: SyncOperation.linkEntity,
      entityId: localLink.id,
      operationType: SyncOperation.update,
      payload: localLink.toSyncPayload(),
    );
  }

  Future<void> deleteLink(String id) async {
    await _linksBox.delete(id);
    await _baseLinksBox.delete(id);
    await _conflictLinksBox.delete(id);
    await _syncTombstonesBox.put(
      '${SyncOperation.linkEntity}:$id',
      SyncTombstone(
        entityType: SyncOperation.linkEntity,
        entityId: id,
        deletedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      ),
    );
    await _enqueueOperation(
      entityType: SyncOperation.linkEntity,
      entityId: id,
      operationType: SyncOperation.delete,
      payload: const {},
    );
  }

  // ─── Querying & Pagination ─────────────────────────────────────────────────

  List<LinkModel> queryLinks({
    String query = '',
    String category = 'All',
    String priority = 'All',
    int limit = 20,
    int offset = 0,
  }) {
    var filtered = _linksBox.values.toList();

    filtered.sort((a, b) {
      final aTime = a.syncedAt ?? a.createdAt;
      final bTime = b.syncedAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });

    if (category.isNotEmpty && category != 'All') {
      filtered = filtered
          .where((l) => l.categories.contains(category))
          .toList();
    }

    if (priority.isNotEmpty && priority != 'All') {
      filtered = filtered
          .where((l) => l.priority.toLowerCase() == priority.toLowerCase())
          .toList();
    }

    if (query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      filtered = filtered
          .where(
            (l) =>
                l.title.toLowerCase().contains(q) ||
                l.description.toLowerCase().contains(q) ||
                l.url.toLowerCase().contains(q),
          )
          .toList();
    }

    return filtered.skip(offset).take(limit).toList();
  }

  // ─── Categories ────────────────────────────────────────────────────────────

  List<CategoryModel> getCategories() => _categoriesBox.values.toList();

  Stream<BoxEvent> watchLinksBox() => _linksBox.watch();

  Future<void> addCategory(CategoryModel category) async {
    final c = category.id.isEmpty
        ? CategoryModel(id: _uuid.v4(), name: category.name)
        : category;
    final normalizedName = c.name.trim().toLowerCase();
    final existsInBuiltIns = CategoryUtils.suggestedCategories.any(
      (name) => name.toLowerCase() == normalizedName,
    );
    final existsInCustom = _categoriesBox.values.any(
      (existing) => existing.name.trim().toLowerCase() == normalizedName,
    );
    if (existsInBuiltIns || existsInCustom) {
      throw const CategoryAlreadyExistsException();
    }

    await _categoriesBox.put(c.id, c);
    await _enqueueOperation(
      entityType: SyncOperation.categoryEntity,
      entityId: c.id,
      operationType: SyncOperation.create,
      payload: c.toSyncPayload(),
    );
  }

  Future<void> deleteCategory(String id) async {
    await _categoriesBox.delete(id);
    await _syncTombstonesBox.put(
      '${SyncOperation.categoryEntity}:$id',
      SyncTombstone(
        entityType: SyncOperation.categoryEntity,
        entityId: id,
        deletedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      ),
    );
    await _enqueueOperation(
      entityType: SyncOperation.categoryEntity,
      entityId: id,
      operationType: SyncOperation.delete,
      payload: const {},
    );
  }

  // ─── Cloud Sync ────────────────────────────────────────────────────────────

  Future<void> syncPendingLinks() async {
    final uid = _uid;
    if (uid == null) return;

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final operations =
        _syncOperationsBox.values
            .where(
              (operation) =>
                  (operation.state == SyncOperation.pending ||
                      operation.state == SyncOperation.failed ||
                      operation.state == SyncOperation.processing) &&
                  operation.nextAttemptAt <= now,
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final operation in operations) {
      final processingOperation = operation.copyWith(
        state: SyncOperation.processing,
      );
      await _syncOperationsBox.put(operation.operationId, processingOperation);
      try {
        await _syncOperation(uid, processingOperation);
        await _syncOperationsBox.delete(processingOperation.operationId);
      } catch (e) {
        final attemptCount = processingOperation.attemptCount + 1;
        final retryAt =
            now + SyncBackoff.delayForAttempt(attemptCount).inMilliseconds;
        await _syncOperationsBox.put(
          processingOperation.operationId,
          processingOperation.copyWith(
            state: SyncOperation.failed,
            attemptCount: attemptCount,
            nextAttemptAt: retryAt,
            lastError: e.toString(),
          ),
        );
        printLog(tag: 'LinkRepository', msg: 'Syncing operation failed: $e');
      }
    }
  }

  /// Returns durable operations in creation order for the sync engine.
  List<SyncOperation> get pendingSyncOperations =>
      _syncOperationsBox.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Future<void> _syncOperation(String uid, SyncOperation operation) async {
    if (operation.entityType == SyncOperation.linkEntity) {
      if (operation.operationType == SyncOperation.delete) {
        await _firebaseService.deleteLink(uid, operation.entityId);
        return;
      }

      final link = LinkModel.fromFirestore(
        operation.entityId,
        operation.payload,
      );
      if (operation.operationType == SyncOperation.create) {
        await _firebaseService.saveLink(uid, link);
      } else {
        await _firebaseService.updateLink(uid, link);
      }
      final syncedLink = link.copyWith(isSynced: true);
      await _linksBox.put(syncedLink.id, syncedLink);
      await _baseLinksBox.put(syncedLink.id, syncedLink);
      return;
    }

    if (operation.entityType == SyncOperation.categoryEntity) {
      if (operation.operationType == SyncOperation.delete) {
        await _firebaseService.deleteCategory(uid, operation.entityId);
      } else {
        final category = CategoryModel.fromFirestore(
          operation.entityId,
          operation.payload,
        );
        await _firebaseService.saveCategory(uid, category);
      }
    }
  }

  Future<void> _enqueueOperation({
    required String entityType,
    required String entityId,
    required String operationType,
    required Map<String, dynamic> payload,
  }) async {
    SyncOperation? existing;
    for (final operation in _syncOperationsBox.values) {
      if (operation.entityType == entityType &&
          operation.entityId == entityId) {
        existing = operation;
        break;
      }
    }

    if (existing != null &&
        existing.operationType == SyncOperation.create &&
        operationType == SyncOperation.delete) {
      await _syncOperationsBox.delete(existing.operationId);
      return;
    }

    final effectiveType =
        existing?.operationType == SyncOperation.create &&
            operationType == SyncOperation.update
        ? SyncOperation.create
        : operationType;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final operation = existing == null
        ? SyncOperation(
            operationId: _uuid.v4(),
            entityType: entityType,
            entityId: entityId,
            operationType: effectiveType,
            payload: Map<String, dynamic>.from(payload),
            createdAt: now,
            nextAttemptAt: now,
          )
        : existing.copyWith(
            operationType: effectiveType,
            payload: Map<String, dynamic>.from(payload),
            nextAttemptAt: now,
            clearLastError: true,
            state: SyncOperation.pending,
          );

    await _syncOperationsBox.put(operation.operationId, operation);
  }

  /// Fetches remote records and reconciles them against local state.
  Future<void> pullFromCloud() async {
    final uid = _uid;
    if (uid == null) return;

    final cloudLinks = await _firebaseService.fetchLinks(uid);
    final deletedIds = await _firebaseService.fetchDeletedLinks(uid);

    for (final delId in deletedIds) {
      if (_hasLocalTombstone(SyncOperation.linkEntity, delId)) continue;

      final localLink = _linksBox.get(delId);
      final baseLink = _baseLinksBox.get(delId);
      if (localLink == null) {
        await _baseLinksBox.delete(delId);
        continue;
      }

      if (_hasPendingOperation(SyncOperation.linkEntity, delId) ||
          (baseLink != null &&
              SyncMergeHelper.hasLocalEdits(baseLink, localLink))) {
        await _saveConflict(
          linkId: delId,
          base: baseLink ?? localLink,
          local: localLink,
          cloud: null,
          fields: const ['delete'],
        );
        continue;
      }

      await _linksBox.delete(delId);
      await _baseLinksBox.delete(delId);
    }

    for (final cloudLink in cloudLinks) {
      if (_hasLocalTombstone(SyncOperation.linkEntity, cloudLink.id)) {
        continue;
      }

      final localLink = _linksBox.get(cloudLink.id);
      final baseLink = _baseLinksBox.get(cloudLink.id);
      if (_hasPendingOperation(SyncOperation.linkEntity, cloudLink.id)) {
        if (localLink != null && baseLink != null) {
          final pendingConflicts = SyncMergeHelper.conflictingFields(
            base: baseLink,
            local: localLink,
            cloud: cloudLink,
          );
          if (pendingConflicts.isNotEmpty) {
            await _saveConflict(
              linkId: cloudLink.id,
              base: baseLink,
              local: localLink,
              cloud: cloudLink,
              fields: pendingConflicts,
            );
          }
        }
        continue;
      }

      if (localLink == null || baseLink == null) {
        await _linksBox.put(cloudLink.id, cloudLink);
        await _baseLinksBox.put(cloudLink.id, cloudLink);
        continue;
      }

      final conflicts = SyncMergeHelper.conflictingFields(
        base: baseLink,
        local: localLink,
        cloud: cloudLink,
      );
      if (conflicts.isNotEmpty) {
        await _saveConflict(
          linkId: cloudLink.id,
          base: baseLink,
          local: localLink,
          cloud: cloudLink,
          fields: conflicts,
        );
        continue;
      }

      final mergedLink = SyncMergeHelper.merge(
        base: baseLink,
        local: localLink,
        cloud: cloudLink,
      );
      await _linksBox.put(mergedLink.id, mergedLink);
      await _baseLinksBox.put(cloudLink.id, cloudLink);
      if (!mergedLink.isSynced) {
        await _enqueueOperation(
          entityType: SyncOperation.linkEntity,
          entityId: mergedLink.id,
          operationType: SyncOperation.update,
          payload: mergedLink.toSyncPayload(),
        );
      }
    }

    final cloudCategories = await _firebaseService.fetchCategories(uid);
    for (final category in cloudCategories) {
      if (_hasLocalTombstone(SyncOperation.categoryEntity, category.id) ||
          _hasPendingOperation(SyncOperation.categoryEntity, category.id)) {
        continue;
      }
      await _categoriesBox.put(category.id, category);
    }

    final deletedCategoryIds = await _firebaseService.fetchDeletedCategories(
      uid,
    );
    for (final categoryId in deletedCategoryIds) {
      if (_hasLocalTombstone(SyncOperation.categoryEntity, categoryId) ||
          _hasPendingOperation(SyncOperation.categoryEntity, categoryId)) {
        continue;
      }
      await _categoriesBox.delete(categoryId);
    }
  }

  /// Returns unresolved conflicts for presentation and later user resolution.
  List<ConflictRecord> get conflicts => _conflictRecordsBox.values
      .where((conflict) => conflict.status == ConflictRecord.unresolved)
      .toList();

  /// Keeps the local version and queues it as the new cloud version.
  Future<void> resolveConflictKeepLocal(String conflictId) async {
    final conflict = _conflictRecordsBox.get(conflictId);
    if (conflict == null) return;
    await resolveConflictWithLink(
      conflictId,
      _linkFromPayload(conflict.localVersion),
    );
  }

  /// Keeps the cloud version, including accepting a remote deletion.
  Future<void> resolveConflictKeepCloud(String conflictId) async {
    final conflict = _conflictRecordsBox.get(conflictId);
    if (conflict == null) return;

    await _removeOperationsFor(SyncOperation.linkEntity, conflict.linkId);
    final cloudVersion = conflict.cloudVersion;
    if (cloudVersion == null) {
      await _linksBox.delete(conflict.linkId);
      await _baseLinksBox.delete(conflict.linkId);
      await _conflictLinksBox.delete(conflict.linkId);
      await _syncTombstonesBox.put(
        '${SyncOperation.linkEntity}:${conflict.linkId}',
        SyncTombstone(
          entityType: SyncOperation.linkEntity,
          entityId: conflict.linkId,
          deletedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
        ),
      );
    } else {
      final cloudLink = _linkFromPayload(cloudVersion).copyWith(isSynced: true);
      await _linksBox.put(cloudLink.id, cloudLink);
      await _baseLinksBox.put(cloudLink.id, cloudLink);
      await _conflictLinksBox.delete(conflict.linkId);
    }
    await _conflictRecordsBox.delete(conflictId);
  }

  /// Saves an explicit user-selected merge and queues it for upload.
  Future<void> resolveConflictWithLink(
    String conflictId,
    LinkModel resolvedLink,
  ) async {
    final conflict = _conflictRecordsBox.get(conflictId);
    if (conflict == null) return;
    await updateLink(resolvedLink);
    await _conflictLinksBox.delete(conflict.linkId);
    await _conflictRecordsBox.delete(conflictId);
  }

  bool _hasPendingOperation(String entityType, String entityId) =>
      _syncOperationsBox.values.any(
        (operation) =>
            operation.entityType == entityType &&
            operation.entityId == entityId,
      );

  bool _hasLocalTombstone(String entityType, String entityId) =>
      _syncTombstonesBox.containsKey('$entityType:$entityId');

  LinkModel _linkFromPayload(Map<String, dynamic> payload) =>
      LinkModel.fromFirestore(payload['id'] as String, payload);

  Future<void> _removeOperationsFor(String entityType, String entityId) async {
    final operationIds = _syncOperationsBox.values
        .where(
          (operation) =>
              operation.entityType == entityType &&
              operation.entityId == entityId,
        )
        .map((operation) => operation.operationId)
        .toList();
    for (final operationId in operationIds) {
      await _syncOperationsBox.delete(operationId);
    }
  }

  Future<void> _saveConflict({
    required String linkId,
    required LinkModel base,
    required LinkModel local,
    required LinkModel? cloud,
    required List<String> fields,
  }) async {
    final conflict = ConflictRecord(
      conflictId: '$linkId:${fields.join(',')}',
      linkId: linkId,
      conflictingFields: fields,
      baseVersion: base.toSyncPayload(),
      localVersion: local.toSyncPayload(),
      cloudVersion: cloud?.toSyncPayload(),
      createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    await _conflictRecordsBox.put(conflict.conflictId, conflict);
    await _conflictLinksBox.put(linkId, local);
  }

  Future<void> clearLocalData() async {
    await _linksBox.clear();
    await _baseLinksBox.clear();
    await _conflictLinksBox.clear();
    await _categoriesBox.clear();
    await _syncOperationsBox.clear();
    await _syncTombstonesBox.clear();
    await _conflictRecordsBox.clear();
    printLog(tag: 'LinkRepository', msg: 'Cleared local data');
  }

  Future<void> clearRemoteData() async {
    if (_uid == null) return;
    await _firebaseService.clearUserData(_uid!);
    printLog(tag: 'LinkRepository', msg: 'Cleared remote data for uid=$_uid');
  }

  (int total, int synced, int unsynced) getLinkStats() {
    final all = _linksBox.values;
    final total = all.length;
    final synced = all.where((l) => l.isSynced).length;
    final unsynced = total - synced;
    return (total, synced, unsynced);
  }
}
