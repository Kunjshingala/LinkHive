import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/links/models/category_model.dart';
import '../../features/links/models/link_model.dart';
import '../constants/firebase_constants.dart';
import '../utils/call_timeout.dart';

/// Thin Firestore wrapper for CRUD operations on links and categories.
/// All methods are scoped to a specific userId.
///
/// Every Firestore call goes through [withCallTimeout], so a call that never
/// answers (for example offline) fails after [cloudCallTimeout] instead of
/// holding a sync run open forever.
class FirebaseFirestoreService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _linksCol(String uid) =>
      _db.collection(FirebaseConstants.usersCol).doc(uid).collection(FirebaseConstants.linksCol);

  CollectionReference<Map<String, dynamic>> _categoriesCol(String uid) =>
      _db.collection(FirebaseConstants.usersCol).doc(uid).collection(FirebaseConstants.categoriesCol);

  CollectionReference<Map<String, dynamic>> _deletedLinksCol(String uid) =>
      _db.collection(FirebaseConstants.usersCol).doc(uid).collection(FirebaseConstants.deletedLinksCol);

  CollectionReference<Map<String, dynamic>> _deletedCategoriesCol(String uid) =>
      _db.collection(FirebaseConstants.usersCol).doc(uid).collection(FirebaseConstants.deletedCategoriesCol);

  // ─── Links ────────────────────────────────────────────────────────

  Future<void> saveLink(String uid, LinkModel link) async {
    final data = link.toFirestore()..[FirebaseConstants.linkSyncedAt] = FieldValue.serverTimestamp();
    await withCallTimeout('saveLink', () => _linksCol(uid).doc(link.id).set(data));
  }

  Future<void> updateLink(String uid, LinkModel link) async {
    final data = link.toFirestore()..[FirebaseConstants.linkSyncedAt] = FieldValue.serverTimestamp();
    await withCallTimeout('updateLink', () => _linksCol(uid).doc(link.id).update(data));
  }

  Future<void> deleteLink(String uid, String linkId) async {
    final batch = _db.batch();
    batch.delete(_linksCol(uid).doc(linkId));
    batch.set(_deletedLinksCol(uid).doc(linkId), {FirebaseConstants.linkDeletedAt: FieldValue.serverTimestamp()});
    await withCallTimeout('deleteLink', batch.commit);
  }

  Future<List<String>> fetchDeletedLinks(String uid) async {
    final snap = await withCallTimeout('fetchDeletedLinks', () => _deletedLinksCol(uid).get());
    return snap.docs.map((d) => d.id).toList();
  }

  Future<void> removeDeletedLink(String uid, String linkId) async {
    await withCallTimeout('removeDeletedLink', () => _deletedLinksCol(uid).doc(linkId).delete());
  }

  /// Fetches tombstones whose [FirebaseConstants.linkDeletedAt] is at or after
  /// [sinceMs]. Used for incremental pulls alongside [fetchLinksSince].
  Future<List<String>> fetchDeletedLinksSince(String uid, int sinceMs) async {
    final since = Timestamp.fromMillisecondsSinceEpoch(sinceMs);
    final snap = await withCallTimeout(
      'fetchDeletedLinksSince',
      () => _deletedLinksCol(uid).where(FirebaseConstants.linkDeletedAt, isGreaterThanOrEqualTo: since).get(),
    );
    return snap.docs.map((d) => d.id).toList();
  }

  /// Fetches category tombstones whose [FirebaseConstants.linkDeletedAt] is at
  /// or after [sinceMs]. Mirrors [fetchDeletedLinksSince] for categories.
  Future<List<String>> fetchDeletedCategoriesSince(String uid, int sinceMs) async {
    final since = Timestamp.fromMillisecondsSinceEpoch(sinceMs);
    final snap = await withCallTimeout(
      'fetchDeletedCategoriesSince',
      () => _deletedCategoriesCol(uid).where(FirebaseConstants.linkDeletedAt, isGreaterThanOrEqualTo: since).get(),
    );
    return snap.docs.map((d) => d.id).toList();
  }

  Future<List<LinkModel>> fetchLinks(String uid) async {
    final snap = await withCallTimeout(
      'fetchLinks',
      () => _linksCol(uid).orderBy(FirebaseConstants.linkCreatedAt, descending: true).get(),
    );
    return snap.docs.map((d) => LinkModel.fromFirestore(d.id, d.data())).toList();
  }

  /// Fetches links whose [FirebaseConstants.linkSyncedAt] is at or after [sinceMs].
  ///
  /// Used for incremental pulls: [sinceMs] should already include the caller's
  /// conservative overlap window so records written near the cursor boundary
  /// are not missed due to clock skew.
  Future<List<LinkModel>> fetchLinksSince(String uid, int sinceMs) async {
    final since = Timestamp.fromMillisecondsSinceEpoch(sinceMs);
    final snap = await withCallTimeout(
      'fetchLinksSince',
      () => _linksCol(uid)
          .where(FirebaseConstants.linkSyncedAt, isGreaterThanOrEqualTo: since)
          .orderBy(FirebaseConstants.linkSyncedAt)
          .get(),
    );
    return snap.docs.map((d) => LinkModel.fromFirestore(d.id, d.data())).toList();
  }

  Future<Map<String, dynamic>> fetchPaginatedLinks(String uid, {DocumentSnapshot? startAfter, int limit = 20}) async {
    Query<Map<String, dynamic>> query = _linksCol(
      uid,
    ).orderBy(FirebaseConstants.linkCreatedAt, descending: true).limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snap = await withCallTimeout('fetchPaginatedLinks', query.get);
    final links = snap.docs.map((d) => LinkModel.fromFirestore(d.id, d.data())).toList();
    final lastDocument = snap.docs.isNotEmpty ? snap.docs.last : null;
    return {'links': links, 'lastDocument': lastDocument};
  }

  // ─── Categories ───────────────────────────────────────────────────

  Future<void> saveCategory(String uid, CategoryModel category) async {
    await withCallTimeout('saveCategory', () => _categoriesCol(uid).doc(category.id).set(category.toFirestore()));
  }

  Future<void> deleteCategory(String uid, String categoryId) async {
    final batch = _db.batch();
    batch.delete(_categoriesCol(uid).doc(categoryId));
    batch.set(_deletedCategoriesCol(uid).doc(categoryId), {
      FirebaseConstants.linkDeletedAt: FieldValue.serverTimestamp(),
    });
    await withCallTimeout('deleteCategory', batch.commit);
  }

  Future<List<String>> fetchDeletedCategories(String uid) async {
    final snap = await withCallTimeout('fetchDeletedCategories', () => _deletedCategoriesCol(uid).get());
    return snap.docs.map((d) => d.id).toList();
  }

  Future<List<CategoryModel>> fetchCategories(String uid) async {
    final snap = await withCallTimeout('fetchCategories', () => _categoriesCol(uid).get());
    return snap.docs.map((d) => CategoryModel.fromFirestore(d.id, d.data())).toList();
  }

  // -------- Bulk delete helpers --------
  Future<void> clearUserData(String uid) async {
    await _deleteCollection(_linksCol(uid));
    await _deleteCollection(_categoriesCol(uid));
    await _deleteCollection(_deletedLinksCol(uid));
    await _deleteCollection(_deletedCategoriesCol(uid));
  }

  /// Each read and each batch has its own time limit, so a large collection
  /// that is still making progress is not cut off.
  Future<void> _deleteCollection(CollectionReference<Map<String, dynamic>> col) async {
    const batchSize = 400;
    while (true) {
      final snap = await withCallTimeout('clearUserData read', () => col.limit(batchSize).get());
      if (snap.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await withCallTimeout('clearUserData delete', batch.commit);
      if (snap.docs.length < batchSize) return;
    }
  }
}
