import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firebase_constants.dart';

/// Domain model representing a single saved link in LinkHive.
///
/// A [LinkModel] is the **central data object** of the app. It exists in two
/// places simultaneously:
/// - **Hive (local)** — always, for instant offline access.
/// - **Firestore (cloud)** — only when the user is authenticated and
///   connectivity is available.
///
/// ## Timestamp Design
/// Both [createdAt] and [syncedAt] are stored as **UTC milliseconds since
/// epoch** (`int`) rather than `DateTime` objects. This approach was chosen
/// because:
/// - Hive serializes `int` natively (no custom adapter logic needed).
/// - Epoch integers are timezone-agnostic, avoiding potential drift when
///   reading data back on a device in a different timezone.
/// - Firestore's `Timestamp` converts cleanly to/from millisecond epochs.
///
/// ## Sync Lifecycle
/// ```
/// [Device creates link]
///   createdAt = DateTime.now().toUtc().millisecondsSinceEpoch
///   isSynced  = false
///   syncedAt  = null
///       │
///       ▼
/// [LinkRepository.addLink / syncPendingLinks pushes to Firestore]
///   isSynced  = true
///   syncedAt  = FieldValue.serverTimestamp() (written server-side)
///       │
///       ▼
/// [LinkModel.fromFirestore reads it back]
///   syncedAt  = Timestamp → converted to int ms
/// ```
class LinkModel {
  /// Stable unique identifier for the link.
  ///
  /// Generated client-side as a UUID v4 string (e.g. "a1b2c3d4-...").
  /// Used as the Hive box key AND the Firestore document ID so the two
  /// stores stay perfectly in sync with no secondary lookup needed.
  final String id;

  /// The full URL the user saved (e.g. "https://flutter.dev").
  final String url;

  /// Human-readable title, either:
  /// - Fetched automatically from the page's Open Graph `<title>` tag, or
  /// - Typed manually by the user.
  ///
  /// Falls back to [url] if left empty (see [AddLinkBloc._onSaveRequested]).
  final String title;

  /// Optional description or personal notes about the link.
  /// Defaults to an empty string when not provided.
  final String description;

  /// URL of a preview/thumbnail image (typically the OG:image).
  /// Empty string when no image is available. The UI uses this for the
  /// favicon/avatar shown on each [LinkCard].
  final String image;

  /// List of category names/IDs that this link belongs to.
  ///
  /// Categories are the unified tag/folder concept in LinkHive — a link
  /// can belong to multiple categories simultaneously.
  final List<String> categories;

  /// Priority level of the link. One of: `'High'`, `'Normal'`, `'Low'`.
  ///
  /// Stored and compared as a plain string so the value can be serialized
  /// to Hive and Firestore without an enum adapter. Always compare using
  /// `.toLowerCase()` to avoid case sensitivity issues.
  final String priority;

  /// UTC milliseconds since epoch — set by the **device** at the moment the
  /// link is first created.
  ///
  /// This is the primary sort key when [syncedAt] is not yet available.
  /// It is written once on creation and never mutated afterwards.
  final int createdAt;

  /// UTC milliseconds since epoch — set by the **Firestore server** the
  /// first time the link is successfully synced to the cloud.
  ///
  /// Using a server-set timestamp (via `FieldValue.serverTimestamp()`) rather
  /// than the client clock ensures a globally consistent ordering across all
  /// devices, even those with slightly drifted clocks.
  ///
  /// Null until the link has been successfully synced to Firestore.
  final int? syncedAt;

  /// `true` once the link has been successfully pushed to Firestore.
  ///
  /// Used by:
  /// - [LinkRepository.syncPendingLinks] to identify which links still need
  ///   to be uploaded.
  /// - [LinkCard] to show a "cloud_off" badge for unsynced links.
  final bool isSynced;

  const LinkModel({
    required this.id,
    required this.url,
    required this.title,
    this.description = '',
    this.image = '',
    this.categories = const [],
    this.priority = 'Normal',
    required this.createdAt,
    this.syncedAt,
    this.isSynced = false,
  });

  /// Returns a copy of this [LinkModel] with the specified fields replaced.
  ///
  /// All parameters are optional — unspecified fields retain their current
  /// value. Used heavily in [AddLinkBloc] and [LinkRepository] to produce
  /// updated immutable instances without mutating state.
  ///
  /// Note: there is no way to explicitly null-out [syncedAt] through
  /// `copyWith` because of Dart's optional-null limitation. If you ever need
  /// to clear it, create a new [LinkModel] directly.
  LinkModel copyWith({
    String? id,
    String? url,
    String? title,
    String? description,
    String? image,
    List<String>? categories,
    String? priority,
    int? createdAt,
    int? syncedAt,
    bool? isSynced,
  }) {
    return LinkModel(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      description: description ?? this.description,
      image: image ?? this.image,
      categories: categories ?? this.categories,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  /// Serializes this link to a Firestore-compatible map.
  ///
  /// **Important:** [syncedAt] is intentionally excluded here because it is
  /// written by [FirebaseFirestoreService] as `FieldValue.serverTimestamp()`
  /// — letting the server set its own timestamp guarantees accuracy.
  ///
  /// Field keys are sourced from [FirebaseConstants] to prevent typos and
  /// make renaming safer (single source of truth).
  Map<String, dynamic> toFirestore() {
    return {
      FirebaseConstants.linkUrl: url,
      FirebaseConstants.linkTitle: title,
      FirebaseConstants.linkDescription: description,
      FirebaseConstants.linkImage: image,
      FirebaseConstants.linkCategories: categories,
      FirebaseConstants.linkPriority: priority,
      FirebaseConstants.linkCreatedAt: createdAt,
      // syncedAt is NOT written here — the service writes it as
      // FieldValue.serverTimestamp() to get the authoritative server time.
    };
  }

  /// Deserializes a Firestore document snapshot into a [LinkModel].
  ///
  /// [id] is the Firestore document ID (same as [LinkModel.id]).
  /// [data] is the raw `Map<String, dynamic>` from the document snapshot.
  ///
  /// ## syncedAt handling
  /// Firestore's server timestamps come back as a [Timestamp] object after
  /// the first read, but may arrive as an `int` if the data was written by
  /// an older version of the app or a third-party tool. Both cases are
  /// handled explicitly; any other type is treated as "not yet synced".
  factory LinkModel.fromFirestore(String id, Map<String, dynamic> data) {
    int? syncedAtMs;
    final raw = data[FirebaseConstants.linkSyncedAt];

    if (raw is Timestamp) {
      // Standard path: Firestore server timestamp
      syncedAtMs = raw.millisecondsSinceEpoch;
    } else if (raw is int) {
      // Fallback: raw integer written by older app versions or manual imports
      syncedAtMs = raw;
    }
    // Any other type (null, String, etc.) leaves syncedAtMs as null.

    return LinkModel(
      id: id,
      url: data[FirebaseConstants.linkUrl] as String? ?? '',
      title: data[FirebaseConstants.linkTitle] as String? ?? '',
      description: data[FirebaseConstants.linkDescription] as String? ?? '',
      image: data[FirebaseConstants.linkImage] as String? ?? '',
      categories: List<String>.from(data[FirebaseConstants.linkCategories] as List? ?? []),
      priority: data[FirebaseConstants.linkPriority] as String? ?? 'Normal',
      // Guard against missing createdAt (e.g. data created before the field
      // was added) by falling back to the current time. This should be rare.
      createdAt: data[FirebaseConstants.linkCreatedAt] as int? ?? DateTime.now().toUtc().millisecondsSinceEpoch,
      syncedAt: syncedAtMs,
      isSynced: true, // All links that come from Firestore are already synced.
    );
  }

  @override
  String toString() => 'LinkModel(id: $id, title: $title, url: $url)';
}
