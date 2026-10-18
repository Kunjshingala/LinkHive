import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/hive_constants.dart';
import '../../../core/models/conflict_record.dart';
import '../../../core/models/sync_operation.dart';
import '../../../core/models/sync_tombstone.dart';
import '../../../core/services/sync_status.dart';
import '../../../core/utils/hive_helper.dart';
import '../../../core/utils/url_canonical.dart';
import '../../../core/utils/utils.dart';
import '../../../core/utils/category_utils.dart';
import '../models/category_model.dart';
import '../models/link_exceptions.dart';
import '../models/link_model.dart';
import '../models/link_query.dart';
import 'local_data_store.dart';

/// Repository that manages all [LinkModel] and [CategoryModel] persistence.
///
/// ## Offline-first Architecture
/// Every read and write goes to the **local Hive boxes first**, and every
/// write is queued in the outbox. `CloudSyncService` pushes the outbox and
/// pulls from Firestore through the narrow [SyncStore] contract; this class
/// never talks to the cloud.
class LinkRepository implements LocalDataStore, SyncStore {
  final HiveHelper _hiveHelper;

  LinkRepository({required HiveHelper hiveHelper}) : _hiveHelper = hiveHelper;

  Box<LinkModel> get _linksBox => _hiveHelper.linksBox;
  Box<LinkModel> get _baseLinksBox => _hiveHelper.baseLinksBox;
  Box<LinkModel> get _conflictLinksBox => _hiveHelper.conflictLinksBox;
  Box<CategoryModel> get _categoriesBox => _hiveHelper.categoriesBox;
  Box<SyncOperation> get _syncOperationsBox => _hiveHelper.syncOperationsBox;
  Box<SyncTombstone> get _syncTombstonesBox => _hiveHelper.syncTombstonesBox;
  Box<ConflictRecord> get _conflictRecordsBox => _hiveHelper.conflictRecordsBox;

  static const _uuid = Uuid();

  /// Counts the wipes done by [clearLocalData].
  ///
  /// A sync run holds the value it started with ([SyncRunToken]), and every
  /// [SyncStore] write checks it, so a push or pull that was still waiting on
  /// the cloud when the phone was wiped cannot write the old account's data
  /// back.
  int _wipeGeneration = 0;

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
    // Quick (instant-saved, unorganized) links are excluded here — they live
    // in the Inbox, not the main Home collection, until the user adds details.
    var filtered = _linksBox.values.where((l) => !l.isQuickSaved).toList();

    // Sort by save time (createdAt), newest first. Not syncedAt — that is a
    // server write timestamp that changes on every sync (e.g. marking a link
    // read), which would otherwise reshuffle the list.
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

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

  /// Returns the locally stored link with [id], or null if it doesn't exist.
  /// Used by the share-intent instant-save flow to re-read a link before
  /// enriching it with background-fetched metadata.
  @override
  LinkModel? getLinkById(String id) => _linksBox.get(id);

  /// The saved link that [url] is a duplicate of, or null.
  ///
  /// Compares [canonicalUrl] keys, so two shares of the same reel or video
  /// with different tracking params match. A linear scan: fine at personal
  /// scale (thousands of links), and it needs no stored key or migration.
  /// When legacy duplicates already exist, the oldest wins so merges always
  /// land on the same record.
  LinkModel? findByCanonicalUrl(String url) {
    final key = canonicalUrl(url);
    LinkModel? oldest;
    for (final link in _linksBox.values) {
      if (canonicalUrl(link.url) != key) continue;
      if (oldest == null || link.createdAt < oldest.createdAt) oldest = link;
    }
    return oldest;
  }

  /// Returns all quick-saved (unorganized) links for the Inbox, newest first.
  ///
  /// These are the instant share-saves that haven't been given details yet.
  /// They are intentionally kept out of [queryLinks] so the Inbox and the Home
  /// list never show the same link twice.
  List<LinkModel> queryQuickLinks() {
    final quick = _linksBox.values.where((l) => l.isQuickSaved).toList();
    quick.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return quick;
  }

  /// Number of quick-saved links waiting in the Inbox — drives the Home badge.
  int get quickCount => _linksBox.values.where((l) => l.isQuickSaved).length;

  // ─── Library ───────────────────────────────────────────────────────────────
  //
  // In-memory filters over the links box, like [queryLinks]. Inbox
  // (quick-saved) links are excluded everywhere: they get their own tab.

  Iterable<LinkModel> get _libraryLinks =>
      _linksBox.values.where((l) => !l.isQuickSaved);

  /// One page of the Links list for [query].
  List<LinkModel> findLinks(LinkQuery query, {int limit = 20, int offset = 0}) {
    final matches = _matching(query).toList();
    final comparator = query.sort == LinkSort.site
        ? _bySiteComparator(matches)
        : _comparatorFor(query.sort);
    matches.sort(comparator);
    return matches.skip(offset).take(limit).toList();
  }

  /// Sites with the most matching links first (ties A–Z), newest first within
  /// a site, so the list reads as one group per site.
  int Function(LinkModel, LinkModel) _bySiteComparator(
    List<LinkModel> matches,
  ) {
    final hosts = {for (final l in matches) l.id: sourceHost(l.url)};
    final counts = <String, int>{};
    for (final host in hosts.values) {
      counts[host] = (counts[host] ?? 0) + 1;
    }
    return (a, b) {
      final hostA = hosts[a.id]!, hostB = hosts[b.id]!;
      if (hostA != hostB) {
        final byCount = counts[hostB]!.compareTo(counts[hostA]!);
        return byCount != 0 ? byCount : hostA.compareTo(hostB);
      }
      return b.createdAt.compareTo(a.createdAt);
    };
  }

  /// Number of links [findLinks] would return across all pages.
  int countLinks(LinkQuery query) => _matching(query).length;

  Iterable<LinkModel> _matching(LinkQuery query) {
    final q = query.search.trim().toLowerCase();
    final priorities = query.priorities.map((p) => p.toLowerCase()).toSet();

    return _libraryLinks.where((l) {
      if (query.readFilter == ReadFilter.unread && l.isRead) return false;
      if (query.readFilter == ReadFilter.read && !l.isRead) return false;
      if (l.shareCount < query.minShareCount) return false;
      if (query.host != null && sourceHost(l.url) != query.host) return false;
      if (query.uncategorized && l.categories.isNotEmpty) return false;
      if (query.categories.isNotEmpty &&
          !l.categories.any(query.categories.contains)) {
        return false;
      }
      if (priorities.isNotEmpty &&
          !priorities.contains(l.priority.toLowerCase())) {
        return false;
      }
      if (q.isNotEmpty &&
          !l.title.toLowerCase().contains(q) &&
          !l.description.toLowerCase().contains(q) &&
          !l.url.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    });
  }

  int Function(LinkModel, LinkModel) _comparatorFor(LinkSort sort) {
    int newestFirst(LinkModel a, LinkModel b) =>
        b.createdAt.compareTo(a.createdAt);
    switch (sort) {
      case LinkSort.newest:
        return newestFirst;
      case LinkSort.oldest:
        return (a, b) => a.createdAt.compareTo(b.createdAt);
      case LinkSort.priority:
        return (a, b) {
          final byPriority = _priorityRank(
            a.priority,
          ).compareTo(_priorityRank(b.priority));
          return byPriority != 0 ? byPriority : newestFirst(a, b);
        };
      case LinkSort.mostSaved:
        return (a, b) {
          final byCount = b.shareCount.compareTo(a.shareCount);
          return byCount != 0 ? byCount : newestFirst(a, b);
        };
      case LinkSort.site:
        // Needs per-site counts; findLinks uses _bySiteComparator instead.
        return newestFirst;
    }
  }

  static int _priorityRank(String priority) =>
      switch (priority.toLowerCase()) {
        'high' => 0,
        'low' => 2,
        _ => 1,
      };

  /// Counts for the quick chips and "No category".
  LibraryStats getLibraryStats() {
    var total = 0, unread = 0, high = 0, savedTwicePlus = 0, uncategorized = 0;
    for (final l in _libraryLinks) {
      total++;
      if (!l.isRead) unread++;
      if (l.priority.toLowerCase() == 'high') high++;
      if (l.shareCount >= 2) savedTwicePlus++;
      if (l.categories.isEmpty) uncategorized++;
    }
    return LibraryStats(
      total: total,
      unread: unread,
      high: high,
      savedTwicePlus: savedTwicePlus,
      read: total - unread,
      uncategorized: uncategorized,
    );
  }

  /// Sites links come from, most links first. Links without a host are left
  /// out. With [within], counts only links matching that query (for the
  /// per-site group headers).
  List<NamedCount> getSourceCounts({LinkQuery? within}) => _countBy(
    (within == null ? _libraryLinks : _matching(within)).map(
      (l) => [sourceHost(l.url)],
    ),
  );

  /// Every category name used by at least one link, most links first.
  ///
  /// Built from the links rather than the categories box, so legacy built-in
  /// names that are no longer offered still show up while links use them.
  List<NamedCount> getCategoryCounts() =>
      _countBy(_libraryLinks.map((l) => l.categories));

  static List<NamedCount> _countBy(Iterable<Iterable<String>> keysPerLink) {
    final counts = <String, int>{};
    for (final keys in keysPerLink) {
      for (final key in keys.toSet()) {
        if (key.isEmpty) continue;
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    final result = counts.entries.map((e) => NamedCount(e.key, e.value)).toList()
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0 ? byCount : a.name.compareTo(b.name);
      });
    return result;
  }

  /// Category names [host]'s links already have, most used first, keeping only
  /// names on at least [minLinks] links. Backs the category suggestions.
  List<NamedCount> getCategoryCountsForHost(String host, {int minLinks = 2}) =>
      _countBy(
        _libraryLinks
            .where((l) => sourceHost(l.url) == host)
            .map((l) => l.categories),
      ).where((c) => c.count >= minLinks).toList();

  // ─── Bulk writes ───────────────────────────────────────────────────────────
  //
  // Each changed link is written and queued for sync exactly like the
  // single-link versions. Links that wouldn't change are skipped.

  Future<void> markLinksRead(Iterable<String> ids) => _updateEach(
    ids,
    (l) => l.isRead ? null : l.copyWith(isRead: true),
  );

  Future<void> addCategoryToLinks(Iterable<String> ids, String name) =>
      _updateEach(
        ids,
        (l) => l.categories.contains(name)
            ? null
            : l.copyWith(categories: [...l.categories, name]),
      );

  Future<void> setPriorityForLinks(Iterable<String> ids, String priority) =>
      _updateEach(
        ids,
        (l) => l.priority.toLowerCase() == priority.toLowerCase()
            ? null
            : l.copyWith(priority: priority),
      );

  Future<void> deleteLinks(Iterable<String> ids) async {
    for (final id in ids.toSet()) {
      if (_linksBox.containsKey(id)) await deleteLink(id);
    }
  }

  Future<void> _updateEach(
    Iterable<String> ids,
    LinkModel? Function(LinkModel) change,
  ) async {
    for (final id in ids.toSet()) {
      final link = _linksBox.get(id);
      if (link == null) continue;
      final updated = change(link);
      if (updated != null) await updateLink(updated);
    }
  }

  // ─── Daily Resurface ───────────────────────────────────────────────────────

  /// Picks the single link the Daily Resurface engine should show today.
  ///
  /// Candidates are every unread link — quick-saved or organized, the engine
  /// doesn't care which; the point is to fight rot on anything not yet
  /// consumed. Priority:
  /// 1. A link with a **due** [LinkModel.resurfaceAt] (a "when should this
  ///    come back?" schedule that has arrived), earliest due first.
  /// 2. Otherwise, the general pool ordered by [LinkModel.lastResurfacedAt]
  ///    ascending (nulls — never shown — first), then [LinkModel.createdAt]
  ///    ascending, so coverage spreads instead of repeating the same link.
  ///
  /// Returns `null` when there is nothing unread to resurface.
  LinkModel? getResurfaceCandidate({DateTime? now}) {
    final nowMs = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    final unread = _linksBox.values.where((l) => !l.isRead).toList();
    if (unread.isEmpty) return null;

    final due =
        unread
            .where((l) => l.resurfaceAt != null && l.resurfaceAt! <= nowMs)
            .toList()
          ..sort((a, b) => a.resurfaceAt!.compareTo(b.resurfaceAt!));
    if (due.isNotEmpty) return due.first;

    final pool = List<LinkModel>.from(unread)
      ..sort((a, b) {
        final aLast = a.lastResurfacedAt;
        final bLast = b.lastResurfacedAt;
        if (aLast == null && bLast == null) {
          return a.createdAt.compareTo(b.createdAt);
        }
        if (aLast == null) return -1; // never shown sorts first
        if (bLast == null) return 1;
        return aLast.compareTo(bLast);
      });
    return pool.first;
  }

  /// Records that [id] was just shown by the Daily Resurface engine and
  /// clears any due schedule, so it falls back into the general spaced pool
  /// instead of being offered again every day.
  Future<void> markResurfaced(String id) async {
    final link = _linksBox.get(id);
    if (link == null) return;
    final updated = link.copyWith(
      lastResurfacedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      clearResurfaceAt: true,
      isSynced: false,
    );
    await _linksBox.put(id, updated);
    await _enqueueOperation(
      entityType: SyncOperation.linkEntity,
      entityId: id,
      operationType: SyncOperation.update,
      payload: updated.toSyncPayload(),
    );
  }

  // ─── Categories ────────────────────────────────────────────────────────────

  List<CategoryModel> getCategories() => _categoriesBox.values.toList();

  Stream<BoxEvent> watchLinksBox() => _linksBox.watch();

  /// Marks a link as read and queues a sync update to Firestore.
  /// No-op if the link is already read or doesn't exist.
  Future<void> markLinkAsRead(String id) async {
    final link = _linksBox.get(id);
    if (link == null || link.isRead) return;
    final updated = link.copyWith(isRead: true, isSynced: false);
    await _linksBox.put(id, updated);
    await _enqueueOperation(
      entityType: SyncOperation.linkEntity,
      entityId: id,
      operationType: SyncOperation.update,
      payload: updated.toSyncPayload(),
    );
  }

  /// Marks a link as unread and queues a sync update to Firestore.
  /// No-op if the link is already unread or doesn't exist.
  Future<void> markLinkAsUnread(String id) async {
    final link = _linksBox.get(id);
    if (link == null || !link.isRead) return;
    final updated = link.copyWith(isRead: false, isSynced: false);
    await _linksBox.put(id, updated);
    await _enqueueOperation(
      entityType: SyncOperation.linkEntity,
      entityId: id,
      operationType: SyncOperation.update,
      payload: updated.toSyncPayload(),
    );
  }

  /// Returns up to [count] oldest unread links for the "Up Next" strip.
  /// Sorted by [LinkModel.createdAt] ascending so the oldest saved (most
  /// likely forgotten) links are surfaced first.
  List<LinkModel> getUpNextLinks({int count = 3}) {
    // Exclude quick-saved links — they belong to the Inbox, not the managed
    // reading queue surfaced on Home.
    final unread = _linksBox.values
        .where((l) => !l.isRead && !l.isQuickSaved)
        .toList();
    unread.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return unread.take(count).toList();
  }

  /// Total number of unread links — used for the Up Next strip label.
  /// Quick-saved (Inbox) links are excluded; they are counted by [quickCount].
  int get unreadCount =>
      _linksBox.values.where((l) => !l.isRead && !l.isQuickSaved).length;

  Future<void> addCategory(CategoryModel category) async {
    final c = category.id.isEmpty
        ? CategoryModel(id: _uuid.v4(), name: category.name)
        : category;
    final normalizedName = c.name.trim().toLowerCase();
    final existsInBuiltIns = CategoryUtils.isBuiltIn(normalizedName);
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

  /// Deletes the category and removes its name from every link that has it.
  ///
  /// Links store category names, not ids, so without the second step the
  /// links would keep a category that no longer exists anywhere else.
  Future<void> deleteCategory(String id) async {
    final name = _categoriesBox.get(id)?.name;
    if (name != null) {
      final tagged = _linksBox.values
          .where((l) => l.categories.contains(name))
          .toList();
      for (final link in tagged) {
        await updateLink(
          link.copyWith(
            categories: link.categories.where((c) => c != name).toList(),
          ),
        );
      }
    }
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

  // ─── Sync state ────────────────────────────────────────────────────────────
  //
  // Push, pull and merge live in CloudSyncService. This class keeps the outbox
  // and gives that service the reads and guarded writes of [SyncStore].

  /// Returns durable operations in creation order.
  List<SyncOperation> get pendingSyncOperations =>
      _syncOperationsBox.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// What has not reached the cloud yet: queued writes (links and categories),
  /// how many of them failed their last attempt, and unresolved conflicts.
  @override
  UnsyncedSummary unsyncedSummary() {
    final operations = _syncOperationsBox.values;
    return UnsyncedSummary(
      changes: operations.length,
      failedChanges: operations
          .where((operation) => operation.state == SyncOperation.failed)
          .length,
      conflicts: conflicts.length,
    );
  }

  /// Emits whenever the queue of unsynced writes changes.
  Stream<BoxEvent> watchSyncOperations() => _syncOperationsBox.watch();

  @override
  int? get lastPulledAt =>
      _hiveHelper.settingsBox.get(HiveConstants.lastPulledAtKey) as int?;

  @override
  Future<SyncRunToken?> beginRun(String uid) async {
    final settings = _hiveHelper.settingsBox;
    var run = SyncRunToken(_wipeGeneration);
    final owner = settings.get(HiveConstants.ownerUidKey) as String?;
    if (owner == uid) return run;

    if (owner == null) {
      final reset = await _guarded(
        run,
        () => settings.delete(HiveConstants.lastPulledAtKey),
      );
      if (!reset) return null;
    } else {
      printLog(
        tag: 'LinkRepository',
        msg: 'Local data belongs to another account; wiping before sync',
      );
      await clearLocalData();
      // This wipe moved the count by one; more means another wipe ran too.
      if (_wipeGeneration != run.generation + 1) return null;
      run = SyncRunToken(_wipeGeneration);
    }
    final claimed = await _guarded(
      run,
      () => settings.put(HiveConstants.ownerUidKey, uid),
    );
    return claimed ? run : null;
  }

  @override
  bool isCurrentRun(SyncRunToken run) => run.generation == _wipeGeneration;

  /// Starts [write] only if no wipe happened since [run] began.
  ///
  /// The check and the start of the write are one synchronous step, and Hive
  /// applies a box's writes in the order they start. So the write either
  /// starts before a wipe's clear, which then removes it, or not at all.
  Future<bool> _guarded(SyncRunToken run, Future<void> Function() write) async {
    if (!isCurrentRun(run)) return false;
    await write();
    return true;
  }

  @override
  List<SyncOperation> dueOperations(int nowMs) =>
      _syncOperationsBox.values
          .where(
            (operation) =>
                (operation.state == SyncOperation.pending ||
                    operation.state == SyncOperation.failed ||
                    operation.state == SyncOperation.processing) &&
                operation.nextAttemptAt <= nowMs,
          )
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// `_enqueueOperation` resets a replaced operation to pending.
  @override
  bool isStillInFlight(SyncOperation operation) =>
      _syncOperationsBox.get(operation.operationId)?.state ==
      SyncOperation.processing;

  @override
  LinkModel? getBaseLinkById(String id) => _baseLinksBox.get(id);

  @override
  bool hasPendingOperation(String entityType, String entityId) =>
      _syncOperationsBox.values.any(
        (operation) =>
            operation.entityType == entityType &&
            operation.entityId == entityId,
      );

  @override
  bool hasLocalTombstone(String entityType, String entityId) =>
      _syncTombstonesBox.containsKey('$entityType:$entityId');

  @override
  Future<bool> putOperation(SyncRunToken run, SyncOperation operation) =>
      _guarded(
        run,
        () => _syncOperationsBox.put(operation.operationId, operation),
      );

  /// The queued operation can change while its upload waits: an edit replaces
  /// its payload, and deleting an entity whose create was queued removes it.
  /// That newer change must not be lost, so it stays queued, the local link is
  /// left alone, and only the base learns what the cloud now holds.
  @override
  Future<bool> finishPushed(SyncRunToken run, SyncOperation operation) async {
    final pushedLink =
        operation.entityType == SyncOperation.linkEntity &&
            operation.operationType != SyncOperation.delete
        ? LinkModel.fromFirestore(
            operation.entityId,
            operation.payload,
          ).copyWith(isSynced: true)
        : null;

    if (isStillInFlight(operation)) {
      if (pushedLink != null) {
        if (!await _guarded(
              run,
              () => _linksBox.put(pushedLink.id, pushedLink),
            ) ||
            !await _guarded(
              run,
              () => _baseLinksBox.put(pushedLink.id, pushedLink),
            )) {
          return false;
        }
      }
      return _guarded(
        run,
        () => _syncOperationsBox.delete(operation.operationId),
      );
    }

    if (pushedLink != null && _linksBox.containsKey(pushedLink.id)) {
      return _guarded(run, () => _baseLinksBox.put(pushedLink.id, pushedLink));
    }
    if (operation.operationType != SyncOperation.delete &&
        !hasPendingOperation(operation.entityType, operation.entityId) &&
        hasLocalTombstone(operation.entityType, operation.entityId)) {
      // Deleted while its create was uploading: the cloud has it now.
      return _guarded(
        run,
        () => _enqueueOperation(
          entityType: operation.entityType,
          entityId: operation.entityId,
          operationType: SyncOperation.delete,
          payload: const {},
        ),
      );
    }
    return isCurrentRun(run);
  }

  @override
  Future<bool> putCloudLink(SyncRunToken run, LinkModel cloudLink) async =>
      await _guarded(run, () => _linksBox.put(cloudLink.id, cloudLink)) &&
      await _guarded(run, () => _baseLinksBox.put(cloudLink.id, cloudLink));

  @override
  Future<bool> applyMerge(
    SyncRunToken run,
    LinkModel merged,
    LinkModel cloudLink,
  ) async {
    if (!await _guarded(run, () => _linksBox.put(merged.id, merged)) ||
        !await _guarded(
          run,
          () => _baseLinksBox.put(cloudLink.id, cloudLink),
        )) {
      return false;
    }
    // An edit made while these writes waited is newer than the merge and
    // queued its own operation; queueing the merge would replace it.
    if (merged.isSynced || !identical(_linksBox.get(merged.id), merged)) {
      return isCurrentRun(run);
    }
    return _guarded(
      run,
      () => _enqueueOperation(
        entityType: SyncOperation.linkEntity,
        entityId: merged.id,
        operationType: SyncOperation.update,
        payload: merged.toSyncPayload(),
      ),
    );
  }

  @override
  Future<bool> removeLink(SyncRunToken run, String id) async =>
      await _guarded(run, () => _linksBox.delete(id)) &&
      await _guarded(run, () => _baseLinksBox.delete(id));

  @override
  Future<bool> removeBaseLink(SyncRunToken run, String id) =>
      _guarded(run, () => _baseLinksBox.delete(id));

  @override
  Future<bool> saveConflict(
    SyncRunToken run, {
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
    return await _guarded(
          run,
          () => _conflictRecordsBox.put(conflict.conflictId, conflict),
        ) &&
        await _guarded(run, () => _conflictLinksBox.put(linkId, local));
  }

  @override
  Future<bool> putCategory(SyncRunToken run, CategoryModel category) =>
      _guarded(run, () => _categoriesBox.put(category.id, category));

  @override
  Future<bool> removeCategory(SyncRunToken run, String id) =>
      _guarded(run, () => _categoriesBox.delete(id));

  /// Nothing on this phone is deleted: pulled links are merged in the same way
  /// as on a first sync.
  @override
  Future<bool> resetPullCursor(SyncRunToken run) => _guarded(
    run,
    () => _hiveHelper.settingsBox.delete(HiveConstants.lastPulledAtKey),
  );

  @override
  Future<bool> writePullCursor(SyncRunToken run, int timestampMs) => _guarded(
    run,
    () =>
        _hiveHelper.settingsBox.put(HiveConstants.lastPulledAtKey, timestampMs),
  );

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

  @override
  Future<void> clearLocalData() async {
    // First, before any await: a sync run that is still waiting on the cloud
    // sees the change and stops writing (see [_wipeGeneration]).
    _wipeGeneration++;
    await _linksBox.clear();
    await _baseLinksBox.clear();
    await _conflictLinksBox.clear();
    await _categoriesBox.clear();
    await _syncOperationsBox.clear();
    await _syncTombstonesBox.clear();
    await _conflictRecordsBox.clear();
    // Reset the pull cursor so the next sign-in performs a full bootstrap fetch,
    // and forget the owner: nothing local belongs to any account any more.
    await _hiveHelper.settingsBox.delete(HiveConstants.lastPulledAtKey);
    await _hiveHelper.settingsBox.delete(HiveConstants.ownerUidKey);
    printLog(tag: 'LinkRepository', msg: 'Cleared local data');
  }

  @override
  bool get isWipePending =>
      _hiveHelper.settingsBox.get(HiveConstants.wipePendingKey) == true;

  @override
  Future<void> setWipePending(bool pending) => pending
      ? _hiveHelper.settingsBox.put(HiveConstants.wipePendingKey, true)
      : _hiveHelper.settingsBox.delete(HiveConstants.wipePendingKey);

  (int total, int synced, int unsynced) getLinkStats() {
    final all = _linksBox.values;
    final total = all.length;
    final synced = all.where((l) => l.isSynced).length;
    final unsynced = total - synced;
    return (total, synced, unsynced);
  }
}
