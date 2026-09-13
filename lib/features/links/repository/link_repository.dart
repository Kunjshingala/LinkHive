import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/firebase_firestore_service.dart';
import '../../../core/utils/hive_helper.dart';
import '../../../core/utils/sync_merge_helper.dart';
import '../../../core/utils/utils.dart';
import '../models/category_model.dart';
import '../models/link_model.dart';

/// Repository that manages all [LinkModel] and [CategoryModel] persistence.
///
/// ## Offline-first Architecture
/// Every read and write goes to the **local Hive boxes first**.
/// Firestore is treated as an optional, best-effort sync layer.
class LinkRepository {
  final FirebaseFirestoreService _firebaseService;
  final HiveHelper _hiveHelper;

  LinkRepository({required FirebaseFirestoreService firebaseService, required HiveHelper hiveHelper})
    : _firebaseService = firebaseService,
      _hiveHelper = hiveHelper;

  Box<LinkModel> get _linksBox => _hiveHelper.linksBox;
  Box<LinkModel> get _baseLinksBox => _hiveHelper.baseLinksBox;
  Box<LinkModel> get _conflictLinksBox => _hiveHelper.conflictLinksBox;
  Box<CategoryModel> get _categoriesBox => _hiveHelper.categoriesBox;

  static const _uuid = Uuid();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ─── Link CRUD ─────────────────────────────────────────────────────────────

  Future<void> addLink(LinkModel link) async {
    final l = link.id.isEmpty ? link.copyWith(id: _uuid.v4()) : link;

    await _linksBox.put(l.id, l);
    printLog(tag: 'LinkRepository', msg: 'Added link: ${l.title}');

    if (_uid != null) {
      try {
        final syncedLink = l.copyWith(isSynced: true);
        await _firebaseService.saveLink(_uid!, syncedLink);
        await _linksBox.put(l.id, syncedLink);
        await _baseLinksBox.put(l.id, syncedLink);
      } catch (e) {
        printLog(tag: 'LinkRepository', msg: 'Cloud save failed (will retry): $e');
      }
    }
  }

  Future<void> updateLink(LinkModel link) async {
    await _linksBox.put(link.id, link);

    if (_uid != null) {
      try {
        await _firebaseService.updateLink(_uid!, link);
        await _baseLinksBox.put(link.id, link.copyWith(isSynced: true));
      } catch (e) {
        printLog(tag: 'LinkRepository', msg: 'Cloud update failed (will retry): $e');
      }
    }
  }

  Future<void> deleteLink(String id) async {
    await _linksBox.delete(id);
    await _baseLinksBox.delete(id);
    await _conflictLinksBox.delete(id);

    if (_uid != null) {
      try {
        await _firebaseService.deleteLink(_uid!, id);
      } catch (e) {
        printLog(tag: 'LinkRepository', msg: 'Cloud delete failed (will retry): $e');
      }
    }
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
      filtered = filtered.where((l) => l.categories.contains(category)).toList();
    }

    if (priority.isNotEmpty && priority != 'All') {
      filtered = filtered.where((l) => l.priority.toLowerCase() == priority.toLowerCase()).toList();
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
    final c = category.id.isEmpty ? CategoryModel(id: _uuid.v4(), name: category.name) : category;
    await _categoriesBox.put(c.id, c);
    if (_uid != null) {
      await _firebaseService.saveCategory(_uid!, c);
    }
  }

  Future<void> deleteCategory(String id) async {
    await _categoriesBox.delete(id);
    if (_uid != null) {
      await _firebaseService.deleteCategory(_uid!, id);
    }
  }

  // ─── Cloud Sync ────────────────────────────────────────────────────────────

  Future<void> syncPendingLinks() async {
    final uid = _uid;
    if (uid == null) return; 

    final unsynced = _linksBox.values.where((l) => !l.isSynced).toList();
    printLog(tag: 'LinkRepository', msg: '${unsynced.length} links to sync');

    for (final link in unsynced) {
      try {
        final syncedLink = link.copyWith(isSynced: true);
        await _firebaseService.saveLink(uid, syncedLink);
        await _linksBox.put(link.id, syncedLink);
        await _baseLinksBox.put(link.id, syncedLink);
      } catch (e) {
        printLog(tag: 'LinkRepository', msg: 'Syncing pending link failed: $e');
      }
    }
  }

  /// Fetches links and tombstones from Firestore and applies the 3-Way Merge strategy.
  Future<void> pullFromCloud() async {
    final uid = _uid;
    if (uid == null) return; 

    // 1. Fetch Cloud Data
    final cloudLinks = await _firebaseService.fetchLinks(uid);
    final deletedIds = await _firebaseService.fetchDeletedLinks(uid);
    
    // 2. Handle Tombstones (Edge Case 2)
    for (final delId in deletedIds) {
      final localLink = _linksBox.get(delId);
      final baseLink = _baseLinksBox.get(delId);

      if (localLink != null) {
        if (baseLink != null && SyncMergeHelper.hasLocalEdits(baseLink, localLink)) {
          // It was deleted on cloud, but edited locally offline. Mark as conflict!
          await _conflictLinksBox.put(delId, localLink);
          printLog(tag: 'LinkRepository', msg: 'Tombstone conflict on $delId. Saved to conflict box.');
        } else {
          // No local edits, safe to delete.
          await _linksBox.delete(delId);
        }
      }
      // Clear base state
      await _baseLinksBox.delete(delId);
    }

    // 3. Handle Active Links (3-Way Merge)
    for (final cloudLink in cloudLinks) {
      final localLink = _linksBox.get(cloudLink.id);
      final baseLink = _baseLinksBox.get(cloudLink.id);

      if (localLink == null || baseLink == null) {
        // Edge Case 4 (First time sync) or new link created on another device
        await _linksBox.put(cloudLink.id, cloudLink);
        await _baseLinksBox.put(cloudLink.id, cloudLink);
      } else {
        // Merge!
        final mergedLink = SyncMergeHelper.merge(
          base: baseLink,
          local: localLink,
          cloud: cloudLink,
        );

        await _linksBox.put(mergedLink.id, mergedLink);
        await _baseLinksBox.put(cloudLink.id, cloudLink);
      }
    }

    // Also pull categories
    final cloudCats = await _firebaseService.fetchCategories(uid);
    for (final cat in cloudCats) {
      await _categoriesBox.put(cat.id, cat);
    }
  }

  Future<void> clearLocalData() async {
    await _linksBox.clear();
    await _baseLinksBox.clear();
    await _conflictLinksBox.clear();
    await _categoriesBox.clear();
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
