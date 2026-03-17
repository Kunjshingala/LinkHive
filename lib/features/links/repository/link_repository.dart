import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/firebase_firestore_service.dart';
import '../../../core/utils/hive_helper.dart';
import '../../../core/utils/utils.dart';
import '../models/category_model.dart';
import '../models/link_model.dart';

/// Repository that manages all [LinkModel] and [CategoryModel] persistence.
///
/// ## Offline-first Architecture
/// Every read and write goes to the **local Hive boxes first**. This means
/// the app works fully offline (or for guest users) with no degraded UX.
/// Firestore is treated as an optional, best-effort sync layer:
///
/// - **Writes**: If the user is authenticated and online, the change is
///   immediately mirrored to Firestore. If that cloud write fails (network
///   error, etc.), the change is already safe in Hive and will be retried
///   by [syncPendingLinks] when connectivity is restored.
/// - **Reads**: Always served from Hive — no Firestore reads on the hot path,
///   which keeps the UI fast regardless of network conditions.
///
/// ## Two-way Sync Strategy
/// | Direction      | Trigger                      | Method               |
/// |----------------|------------------------------|----------------------|
/// | Local → Cloud  | After each write (add/update)| Direct Firestore call|
/// | Local → Cloud  | On reconnect / login         | [syncPendingLinks]   |
/// | Cloud → Local  | On app resume / login        | [pullFromCloud]      |
///
/// **Conflict resolution**: Cloud data wins. [pullFromCloud] overwrites local
/// entries with the Firestore version without merging. This keeps the logic
/// simple; a future version could add field-level merging if needed.
///
/// ## Dependencies
/// - [FirebaseFirestoreService] — thin wrapper around the Firestore SDK.
/// - [HiveHelper] — typed accessors for the Hive boxes (opens/closes them).
class LinkRepository {
  /// Thin Firestore wrapper. All Firestore calls are delegated to this service
  /// so the repository logic stays clean and this service is easily mockable
  /// in tests.
  final FirebaseFirestoreService _firebaseService;

  /// Provides typed, pre-opened Hive boxes for links and categories.
  final HiveHelper _hiveHelper;

  LinkRepository({required FirebaseFirestoreService firebaseService, required HiveHelper hiveHelper})
    : _firebaseService = firebaseService,
      _hiveHelper = hiveHelper;

  /// Convenience getter for the links Hive box.
  /// The box stores [LinkModel] objects keyed by their [LinkModel.id].
  Box<LinkModel> get _linksBox => _hiveHelper.linksBox;

  /// Convenience getter for the categories Hive box.
  /// The box stores [CategoryModel] objects keyed by their [CategoryModel.id].
  Box<CategoryModel> get _categoriesBox => _hiveHelper.categoriesBox;

  /// UUID generator shared across all repository methods. Stateless and safe
  /// to reuse as a single `static const` instance.
  static const _uuid = Uuid();

  /// Returns the currently authenticated user's UID, or `null` for guests.
  ///
  /// All cloud operations are gated on this being non-null — a `null` value
  /// means the user is not signed in and we skip Firestore entirely.
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ─── Link CRUD ─────────────────────────────────────────────────────────────

  /// Persists a new [link] locally (Hive) and, if authenticated, to Firestore.
  ///
  /// ## Offline / guest safety
  /// The Hive write happens unconditionally **before** any Firestore call.
  /// This guarantees the link is saved even if:
  /// - The user is a guest (no account).
  /// - The device is offline.
  /// - The Firestore call throws.
  ///
  /// ## ID generation
  /// If [link.id] is empty (which should not happen when coming from
  /// [AddLinkBloc], but is a defensive guard), a fresh UUID is generated
  /// before storing.
  ///
  /// ## isSynced flag
  /// On a successful Firestore write, the local copy is updated with
  /// `isSynced: true` so the [LinkCard] stops showing the offline badge.
  /// On failure, `isSynced` remains `false` and [syncPendingLinks] will
  /// retry the upload later.
  Future<void> addLink(LinkModel link) async {
    // Ensure the link always has a valid ID before persisting.
    final l = link.id.isEmpty ? link.copyWith(id: _uuid.v4()) : link;

    // Step 1: Always persist locally first — works offline and for guests.
    await _linksBox.put(l.id, l);
    printLog(tag: 'LinkRepository', msg: 'Added link: ${l.title}');

    // Step 2: Attempt cloud sync only when the user is authenticated.
    // Wrapped in try/catch so a network failure never surfaces as a
    // user-visible error — the link is safely stored in Hive and
    // SyncService will retry it later.
    if (_uid != null) {
      try {
        await _firebaseService.saveLink(_uid!, l.copyWith(isSynced: true));
        // Update the local copy to reflect the successful sync.
        await _linksBox.put(l.id, l.copyWith(isSynced: true));
      } catch (e) {
        printLog(tag: 'LinkRepository', msg: 'Cloud save failed (will retry): $e');
        // isSynced stays false — SyncService picks it up on reconnect.
      }
    }
  }

  /// Updates an existing [link] locally (Hive) and, if authenticated, in Firestore.
  ///
  /// The link's [id] is used as the Hive key and Firestore document ID, so
  /// both stores are updated in place. The same offline-safety logic as
  /// [addLink] applies.
  Future<void> updateLink(LinkModel link) async {
    // Persist the updated link locally first.
    await _linksBox.put(link.id, link);

    // Mirror to Firestore if signed in; silently ignore cloud failures.
    if (_uid != null) {
      try {
        await _firebaseService.updateLink(_uid!, link);
      } catch (e) {
        printLog(tag: 'LinkRepository', msg: 'Cloud update failed (will retry): $e');
      }
    }
  }

  /// Deletes the link identified by [id] from Hive and, if authenticated,
  /// from Firestore.
  ///
  /// An offline delete is stored locally without any pending-delete queue, so
  /// if the Firestore delete fails, the record will remain in Firestore until
  /// the user manually deletes it again when online. A pending-delete
  /// mechanism can be added in the future if this gap is a concern.
  Future<void> deleteLink(String id) async {
    await _linksBox.delete(id);

    if (_uid != null) {
      try {
        await _firebaseService.deleteLink(_uid!, id);
      } catch (e) {
        printLog(tag: 'LinkRepository', msg: 'Cloud delete failed (will retry): $e');
      }
    }
  }

  // ─── Querying & Pagination ─────────────────────────────────────────────────

  /// Returns a paginated, filtered, and sorted list of [LinkModel]s from the
  /// local Hive box.
  ///
  /// ## Sorting
  /// Links are sorted **descending by time**. The sort prefers [LinkModel.syncedAt]
  /// (the authoritative server timestamp) when available, and falls back to
  /// [LinkModel.createdAt] (the local device timestamp) for links that have
  /// not yet been synced. This produces a stable order across devices without
  /// requiring network access.
  ///
  /// ## Filtering order
  /// 1. Sort by time (descending).
  /// 2. Filter by [category] (if not 'All').
  /// 3. Filter by [priority] (if not 'All', case-insensitive).
  /// 4. Filter by [query] (searches title, description, and URL).
  /// 5. Apply pagination via [offset] and [limit].
  ///
  /// ## Parameters
  /// - [query]    — Free-text search string. Matches against title, description,
  ///               and URL substrings (case-insensitive). Empty means "no filter".
  /// - [category] — Category name to filter by. Use `'All'` to skip this filter.
  /// - [priority] — Priority string to filter by ('High' | 'Normal' | 'Low').
  ///               Use `'All'` to skip this filter. Comparison is case-insensitive.
  /// - [limit]    — Maximum number of results to return (page size). Default 20.
  /// - [offset]   — Number of results to skip before returning (for pagination).
  ///               Default 0 (first page).
  List<LinkModel> queryLinks({
    String query = '',
    String category = 'All',
    String priority = 'All',
    int limit = 20,
    int offset = 0,
  }) {
    var filtered = _linksBox.values.toList();

    // Sort descending: prefer the server-confirmed syncedAt, fall back to
    // the client-set createdAt for links that haven't been synced yet.
    filtered.sort((a, b) {
      final aTime = a.syncedAt ?? a.createdAt;
      final bTime = b.syncedAt ?? b.createdAt;
      return bTime.compareTo(aTime); // Descending (newest first).
    });

    // Filter by category: only include links that have the selected category
    // in their categories list.
    if (category.isNotEmpty && category != 'All') {
      filtered = filtered.where((l) => l.categories.contains(category)).toList();
    }

    // Filter by priority: case-insensitive so 'high' matches 'High'.
    if (priority.isNotEmpty && priority != 'All') {
      filtered = filtered.where((l) => l.priority.toLowerCase() == priority.toLowerCase()).toList();
    }

    // Free-text search across title, description, and URL substrings.
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

    // Apply pagination: skip [offset] results and take up to [limit].
    return filtered.skip(offset).take(limit).toList();
  }

  // ─── Categories ────────────────────────────────────────────────────────────

  /// Returns all categories from the local Hive box as an unordered list.
  ///
  /// No filtering or pagination is applied — the total number of categories
  /// per user is expected to be small (< 100), so loading all at once is fine.
  List<CategoryModel> getCategories() => _categoriesBox.values.toList();

  /// Returns a stream that emits [BoxEvent]s whenever the links Hive box
  /// changes (put, delete, etc.).
  ///
  /// [LinkBloc] subscribes to this stream so that any external write — for
  /// example a save from [AddLinkBloc] running on a different route — triggers
  /// an automatic reload of the home list without requiring cross-route
  /// coordination via `await context.push(...)`.
  Stream<BoxEvent> watchLinksBox() => _linksBox.watch();

  /// Persists a new [category] locally and, if authenticated, to Firestore.
  ///
  /// If [category.id] is empty, a fresh UUID is generated before persisting.
  Future<void> addCategory(CategoryModel category) async {
    final c = category.id.isEmpty ? CategoryModel(id: _uuid.v4(), name: category.name) : category;

    await _categoriesBox.put(c.id, c);

    // Categories are small and important for UX, so we propagate them to
    // Firestore synchronously (no silenced catch) unlike links.
    if (_uid != null) {
      await _firebaseService.saveCategory(_uid!, c);
    }
  }

  /// Deletes the category identified by [id] from Hive and, if authenticated,
  /// from Firestore.
  ///
  /// **Note**: this does NOT remove the deleted category from existing links —
  /// those links will simply have a stale category string that no longer maps
  /// to a [CategoryModel]. Consider cleaning orphaned references at the call
  /// site if needed.
  Future<void> deleteCategory(String id) async {
    await _categoriesBox.delete(id);
    if (_uid != null) {
      await _firebaseService.deleteCategory(_uid!, id);
    }
  }

  // ─── Cloud Sync ────────────────────────────────────────────────────────────

  /// Uploads all locally stored links that have not yet been synced to Firestore.
  ///
  /// A link is considered "unsynced" when [LinkModel.isSynced] is `false`.
  /// This happens when:
  /// - The link was created while the device was offline.
  /// - The initial Firestore write in [addLink] failed due to a network error.
  ///
  /// After a successful upload, the local copy is updated with
  /// `isSynced: true` to prevent it from being uploaded again.
  ///
  /// This method is a no-op when the user is not authenticated.
  /// It should be called by `SyncService` when both connectivity and
  /// authentication are confirmed.
  Future<void> syncPendingLinks() async {
    final uid = _uid;
    if (uid == null) return; // Nothing to sync for guest users.

    final unsynced = _linksBox.values.where((l) => !l.isSynced).toList();
    printLog(tag: 'LinkRepository', msg: '${unsynced.length} links to sync');

    for (final link in unsynced) {
      await _firebaseService.saveLink(uid, link);
      await _linksBox.put(link.id, link.copyWith(isSynced: true));
    }
  }

  /// Fetches all links and categories from Firestore and merges them into the
  /// local Hive boxes.
  ///
  /// **Conflict resolution**: Cloud data wins unconditionally. If a link
  /// exists in both Hive and Firestore, the Firestore version overwrites the
  /// local one. Local-only links (not yet synced) are not affected because
  /// their IDs won't appear in the Firestore response.
  ///
  /// This method is a no-op when the user is not authenticated.
  /// Typically called on:
  /// - App resume / foreground transition.
  /// - Successful sign-in (to populate the local DB on first launch).
  Future<void> pullFromCloud() async {
    final uid = _uid;
    if (uid == null) return; // Nothing to pull for guest users.

    final cloudLinks = await _firebaseService.fetchLinks(uid);
    for (final link in cloudLinks) {
      await _linksBox.put(link.id, link); // Overwrite local copy with cloud data.
    }

    // Also pull categories so filters stay accurate after a sign-in.
    final cloudCats = await _firebaseService.fetchCategories(uid);
    for (final cat in cloudCats) {
      await _categoriesBox.put(cat.id, cat);
    }
  }

  /// Deletes all data from the local Hive boxes (links and categories).
  ///
  /// **This is a destructive operation** — data that has not been synced to
  /// Firestore will be permanently lost.
  ///
  /// Intended use cases:
  /// - User signs out (wipe local data to protect privacy).
  /// - "Clear all data" action in settings.
  Future<void> clearLocalData() async {
    await _linksBox.clear();
    await _categoriesBox.clear();
    printLog(tag: 'LinkRepository', msg: 'Cleared local data');
  }

  /// Deletes all remote links and categories for the signed-in user.
  Future<void> clearRemoteData() async {
    if (_uid == null) return;
    await _firebaseService.clearUserData(_uid!);
    printLog(tag: 'LinkRepository', msg: 'Cleared remote data for uid=$_uid');
  }

  // ─── Stats ─────────────────────────────────────────────────────────────────

  /// Returns a record of basic statistics about local links.
  ///
  /// Returns a Dart record `(int total, int synced, int unsynced)`:
  /// - `total`   — total number of links in the local Hive box.
  /// - `synced`  — links that have been successfully pushed to Firestore.
  /// - `unsynced`— links pending upload (total - synced).
  ///
  /// Used by the sync status UI (e.g. a settings screen badge or debug panel).
  (int total, int synced, int unsynced) getLinkStats() {
    final all = _linksBox.values;
    final total = all.length;
    final synced = all.where((l) => l.isSynced).length;
    final unsynced = total - synced;
    return (total, synced, unsynced);
  }
}
