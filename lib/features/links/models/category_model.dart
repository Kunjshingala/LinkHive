import '../../../core/constants/firebase_constants.dart';

/// Domain model representing a user-defined category (tag/folder) in LinkHive.
///
/// Categories are the primary organizational concept: a single [LinkModel] can
/// belong to multiple categories, and a category can contain many links.
///
/// ## Storage
/// Categories are persisted in two places:
/// - **Hive** (`categoriesBox`) — for instant offline reads.
/// - **Firestore** (`users/{uid}/categories/{id}`) — for cross-device sync
///   when the user is authenticated.
///
/// ## Design notes
/// - The [id] is a UUID v4 string generated client-side before persisting,
///   which means the same ID is used as both the Hive key and the Firestore
///   document ID. No secondary lookup is ever needed.
/// - The model is intentionally kept minimal (id + name) to avoid coupling
///   the domain layer to UI concerns like color or icon choices — those can
///   be derived in the UI layer from the category name if needed.
class CategoryModel {
  /// Stable unique identifier for the category.
  ///
  /// A UUID v4 string (e.g. "f47ac10b-58cc-4372-a567-0e02b2c3d479").
  /// Used as the Hive box key AND the Firestore document ID so both stores
  /// stay in sync with no additional ID mapping layer.
  final String id;

  /// Human-readable display name of the category (e.g. "Design", "Flutter").
  ///
  /// This is the value shown in the category chip, filter drawer, and
  /// category management screen. It is NOT guaranteed to be unique — two
  /// categories could have the same name but different [id]s. Equality
  /// checks should therefore always compare [id], not [name].
  final String name;

  const CategoryModel({required this.id, required this.name});

  /// Serializes this category to a Firestore-compatible map.
  ///
  /// Only [name] is included because [id] is stored as the Firestore
  /// document ID (not as a field inside the document).
  ///
  /// Field keys are sourced from [FirebaseConstants] to keep the Firestore
  /// schema as a single source of truth and prevent typos.
  Map<String, dynamic> toFirestore() => {FirebaseConstants.categoryName: name};

  /// Deserializes a Firestore document snapshot into a [CategoryModel].
  ///
  /// [id] is the Firestore document ID (passed in separately, not read from
  /// [data]).
  /// [data] is the raw `Map<String, dynamic>` from the document snapshot.
  ///
  /// Defensively defaults [name] to an empty string if the Firestore field
  /// is missing or of an unexpected type.
  factory CategoryModel.fromFirestore(String id, Map<String, dynamic> data) {
    return CategoryModel(id: id, name: data[FirebaseConstants.categoryName] as String? ?? '');
  }

  @override
  String toString() => 'CategoryModel(id: $id, name: $name)';
}
