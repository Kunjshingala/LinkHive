import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:link_hive/core/services/firebase_firestore_service.dart';
import 'package:link_hive/features/links/models/category_model.dart';
import 'package:link_hive/features/links/models/link_model.dart';

/// In-memory stand-in for [FirebaseFirestoreService], for sync scenario tests.
///
/// It keeps the behaviors the sync code relies on, so a story such as "sign in
/// as A, sync, sign out, sign in as B, sync" can be written in a few lines:
///
/// * every account (uid) has its own links, categories and tombstones;
/// * a write stamps `syncedAt` with the server clock, and the stored link comes
///   back with `isSynced == true`, like `LinkModel.fromFirestore`;
/// * deleting a link or category writes a tombstone;
/// * `updateLink` on a missing document throws a `not-found` error;
/// * `fetchLinksSince` and the `...Since` tombstone reads are inclusive.
///
/// It is not Firestore: security rules, indexes, offline persistence and
/// `fetchPaginatedLinks` paging are not modelled.
class FakeFirebaseFirestoreService implements FirebaseFirestoreService {
  FakeFirebaseFirestoreService({int Function()? clock})
    : _clock = clock ?? (() => DateTime.now().toUtc().millisecondsSinceEpoch);

  final int Function() _clock;

  /// Awaited at the start of every call with the method name and uid.
  ///
  /// Tests use it to hold a call open (await a `Completer`) or to make it throw.
  Future<void> Function(String method, String uid)? onCall;

  final Map<String, Map<String, LinkModel>> _links = {};
  final Map<String, Map<String, int>> _deletedLinks = {};
  final Map<String, Map<String, CategoryModel>> _categories = {};
  final Map<String, Map<String, int>> _deletedCategories = {};

  // ─── Test helpers ──────────────────────────────────────────────────────────

  /// Puts [link] in [uid]'s cloud as if it had been synced at [syncedAt].
  void seedLink(String uid, LinkModel link, {required int syncedAt}) {
    _linkMap(uid)[link.id] = link.copyWith(syncedAt: syncedAt, isSynced: true);
  }

  /// Links in [uid]'s cloud, newest first.
  List<LinkModel> linksOf(String uid) => _sortedLinks(uid);

  /// Ids of the link tombstones in [uid]'s cloud.
  Set<String> deletedLinkIdsOf(String uid) =>
      _deletedLinks[uid]?.keys.toSet() ?? <String>{};

  /// Categories in [uid]'s cloud.
  List<CategoryModel> categoriesOf(String uid) =>
      _categories[uid]?.values.toList() ?? <CategoryModel>[];

  Map<String, LinkModel> _linkMap(String uid) =>
      _links.putIfAbsent(uid, () => {});

  List<LinkModel> _sortedLinks(String uid) {
    final links = _links[uid]?.values.toList() ?? <LinkModel>[];
    links.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return links;
  }

  Future<void> _enter(String method, String uid) async {
    await onCall?.call(method, uid);
  }

  // ─── Links ─────────────────────────────────────────────────────────────────

  @override
  Future<void> saveLink(String uid, LinkModel link) async {
    await _enter('saveLink', uid);
    _linkMap(uid)[link.id] = link.copyWith(syncedAt: _clock(), isSynced: true);
  }

  @override
  Future<void> updateLink(String uid, LinkModel link) async {
    await _enter('updateLink', uid);
    if (!_linkMap(uid).containsKey(link.id)) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'not-found',
        message: 'No document to update: users/$uid/links/${link.id}',
      );
    }
    _linkMap(uid)[link.id] = link.copyWith(syncedAt: _clock(), isSynced: true);
  }

  @override
  Future<void> deleteLink(String uid, String linkId) async {
    await _enter('deleteLink', uid);
    _linkMap(uid).remove(linkId);
    (_deletedLinks[uid] ??= {})[linkId] = _clock();
  }

  @override
  Future<List<String>> fetchDeletedLinks(String uid) async {
    await _enter('fetchDeletedLinks', uid);
    return (_deletedLinks[uid]?.keys ?? const <String>[]).toList();
  }

  @override
  Future<void> removeDeletedLink(String uid, String linkId) async {
    await _enter('removeDeletedLink', uid);
    _deletedLinks[uid]?.remove(linkId);
  }

  @override
  Future<List<String>> fetchDeletedLinksSince(String uid, int sinceMs) async {
    await _enter('fetchDeletedLinksSince', uid);
    return _idsSince(_deletedLinks[uid], sinceMs);
  }

  @override
  Future<List<LinkModel>> fetchLinks(String uid) async {
    await _enter('fetchLinks', uid);
    return _sortedLinks(uid);
  }

  @override
  Future<List<LinkModel>> fetchLinksSince(String uid, int sinceMs) async {
    await _enter('fetchLinksSince', uid);
    final links = _linkMap(
      uid,
    ).values.where((link) => (link.syncedAt ?? 0) >= sinceMs).toList();
    links.sort((a, b) => (a.syncedAt ?? 0).compareTo(b.syncedAt ?? 0));
    return links;
  }

  /// Returns the first [limit] links; paging by [startAfter] is not modelled.
  @override
  Future<Map<String, dynamic>> fetchPaginatedLinks(
    String uid, {
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) async {
    await _enter('fetchPaginatedLinks', uid);
    return {
      'links': _sortedLinks(uid).take(limit).toList(),
      'lastDocument': null,
    };
  }

  // ─── Categories ────────────────────────────────────────────────────────────

  @override
  Future<void> saveCategory(String uid, CategoryModel category) async {
    await _enter('saveCategory', uid);
    (_categories[uid] ??= {})[category.id] = category;
  }

  @override
  Future<void> deleteCategory(String uid, String categoryId) async {
    await _enter('deleteCategory', uid);
    _categories[uid]?.remove(categoryId);
    (_deletedCategories[uid] ??= {})[categoryId] = _clock();
  }

  @override
  Future<List<String>> fetchDeletedCategories(String uid) async {
    await _enter('fetchDeletedCategories', uid);
    return (_deletedCategories[uid]?.keys ?? const <String>[]).toList();
  }

  @override
  Future<List<String>> fetchDeletedCategoriesSince(
    String uid,
    int sinceMs,
  ) async {
    await _enter('fetchDeletedCategoriesSince', uid);
    return _idsSince(_deletedCategories[uid], sinceMs);
  }

  @override
  Future<List<CategoryModel>> fetchCategories(String uid) async {
    await _enter('fetchCategories', uid);
    return categoriesOf(uid);
  }

  // ─── Bulk delete ───────────────────────────────────────────────────────────

  @override
  Future<void> clearUserData(String uid) async {
    await _enter('clearUserData', uid);
    _links.remove(uid);
    _categories.remove(uid);
    _deletedLinks.remove(uid);
    _deletedCategories.remove(uid);
  }

  List<String> _idsSince(Map<String, int>? tombstones, int sinceMs) {
    if (tombstones == null) return <String>[];
    return tombstones.entries
        .where((entry) => entry.value >= sinceMs)
        .map((entry) => entry.key)
        .toList();
  }
}
