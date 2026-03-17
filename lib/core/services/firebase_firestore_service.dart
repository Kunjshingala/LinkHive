import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/links/models/category_model.dart';
import '../../features/links/models/link_model.dart';
import '../constants/firebase_constants.dart';

/// Thin Firestore wrapper for CRUD operations on links and categories.
/// All methods are scoped to a specific userId.
class FirebaseFirestoreService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _linksCol(String uid) =>
      _db.collection(FirebaseConstants.usersCol).doc(uid).collection(FirebaseConstants.linksCol);

  CollectionReference<Map<String, dynamic>> _categoriesCol(String uid) =>
      _db.collection(FirebaseConstants.usersCol).doc(uid).collection(FirebaseConstants.categoriesCol);

  // ─── Links ────────────────────────────────────────────────────────

  Future<void> saveLink(String uid, LinkModel link) async {
    final data = link.toFirestore()..[FirebaseConstants.linkSyncedAt] = FieldValue.serverTimestamp();
    await _linksCol(uid).doc(link.id).set(data);
  }

  Future<void> updateLink(String uid, LinkModel link) async {
    await _linksCol(uid).doc(link.id).update(link.toFirestore());
  }

  Future<void> deleteLink(String uid, String linkId) async {
    await _linksCol(uid).doc(linkId).delete();
  }

  Future<List<LinkModel>> fetchLinks(String uid) async {
    final snap = await _linksCol(uid).orderBy(FirebaseConstants.linkCreatedAt, descending: true).get();
    return snap.docs.map((d) => LinkModel.fromFirestore(d.id, d.data())).toList();
  }

  Future<Map<String, dynamic>> fetchPaginatedLinks(String uid, {DocumentSnapshot? startAfter, int limit = 20}) async {
    Query<Map<String, dynamic>> query = _linksCol(
      uid,
    ).orderBy(FirebaseConstants.linkCreatedAt, descending: true).limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snap = await query.get();
    final links = snap.docs.map((d) => LinkModel.fromFirestore(d.id, d.data())).toList();
    final lastDocument = snap.docs.isNotEmpty ? snap.docs.last : null;
    return {'links': links, 'lastDocument': lastDocument};
  }

  // ─── Categories ───────────────────────────────────────────────────

  Future<void> saveCategory(String uid, CategoryModel category) async {
    await _categoriesCol(uid).doc(category.id).set(category.toFirestore());
  }

  Future<void> deleteCategory(String uid, String categoryId) async {
    await _categoriesCol(uid).doc(categoryId).delete();
  }

  Future<List<CategoryModel>> fetchCategories(String uid) async {
    final snap = await _categoriesCol(uid).get();
    return snap.docs.map((d) => CategoryModel.fromFirestore(d.id, d.data())).toList();
  }

  // -------- Bulk delete helpers --------
  Future<void> clearUserData(String uid) async {
    await _deleteCollection(_linksCol(uid));
    await _deleteCollection(_categoriesCol(uid));
  }

  Future<void> _deleteCollection(CollectionReference<Map<String, dynamic>> col) async {
    const batchSize = 400;
    while (true) {
      final snap = await col.limit(batchSize).get();
      if (snap.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snap.docs.length < batchSize) return;
    }
  }
}
