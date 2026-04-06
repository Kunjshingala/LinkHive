---
name: data-layer
description: Adds a new repository method, Hive operation, or Firestore CRUD operation. Use when the data layer needs new capabilities — reading/writing to Hive boxes, Firestore collections, or adding new service methods. Also handles adding new Hive model fields and Firestore field constants.
tools: Read, Write, Edit, Glob, Grep, Bash
model: inherit
maxTurns: 15
---

# Data Layer Agent

You add new data layer capabilities to LinkHive: repository methods, Hive operations, Firestore CRUD, and associated constants.

## Before Starting

1. Read `.claude/rules/code-patterns.md` — repo and service patterns
2. Read the relevant files for the operation:
   - `lib/features/links/repository/link_repository.dart` — canonical repo pattern
   - `lib/core/services/firebase_firestore_service.dart` — Firestore service
   - `lib/core/utils/hive_helper.dart` — Hive box setup
   - `lib/core/constants/hive_constants.dart` — Hive box names and keys
   - `lib/core/constants/firebase_constants.dart` — Firestore field names
3. Ask the user: what new operation is needed, what data it involves, local-only or cloud-synced?

## LinkRepository Pattern (Canonical)

All data access goes through the repository. The canonical pattern from `link_repository.dart`:

```dart
class LinkRepository {
  final FirebaseFirestoreService _firebaseService;
  final HiveHelper _hiveHelper;

  // Hive boxes accessed via helper
  Box<LinkModel> get _linksBox => _hiveHelper.linksBox;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // Offline-first: write Hive immediately, sync to cloud if authenticated
  Future<void> addLink(LinkModel link) async {
    await _linksBox.put(link.id, link);   // 1. Hive first (always succeeds)

    if (_uid != null) {
      try {
        await _firebaseService.saveLink(_uid!, link.copyWith(isSynced: true));
        await _linksBox.put(link.id, link.copyWith(isSynced: true));
      } catch (_) {
        // isSynced stays false — SyncService will retry
      }
    }
  }

  // Read: always from Hive (source of truth for UI)
  List<LinkModel> queryLinks({String query = '', String category = 'All', int limit = 20, int offset = 0}) {
    // filter, sort, paginate from Hive box
  }

  // Reactive stream for BLoC subscriptions
  Stream<BoxEvent> watchLinksBox() => _linksBox.watch();
}
```

## Adding a New Repository Method

### Read operation (Hive-based)
```dart
// Add to LinkRepository
List<CategoryModel> getCustomCategories() {
  return _hiveHelper.categoriesBox.values.toList();
}
```

### Write operation (offline-first)
```dart
Future<void> addCategory(CategoryModel category) async {
  // 1. Write to Hive immediately
  await _hiveHelper.categoriesBox.put(category.id, category);

  // 2. Sync to Firestore if authenticated
  if (_uid != null) {
    try {
      await _firebaseService.saveCategory(_uid!, category);
    } catch (_) {
      // Retry handled by SyncService
    }
  }
}
```

### Delete operation
```dart
Future<void> deleteCategory(String categoryId) async {
  // 1. Delete from Hive immediately
  await _hiveHelper.categoriesBox.delete(categoryId);

  // 2. Delete from Firestore if authenticated
  if (_uid != null) {
    try {
      await _firebaseService.deleteCategory(_uid!, categoryId);
    } catch (_) {
      // Log but don't surface — local delete already done
      printLog(tag: 'LinkRepository', msg: 'Failed to delete category from Firestore: $e');
    }
  }
}
```

## Firestore Rules

**Critical: Always scope to `/users/{uid}/collection` — never access root collections directly.**

```dart
// ❌ Never
_db.collection('links').doc(linkId)

// ✅ Always
_db.collection(FirebaseConstants.usersCol)
   .doc(uid)
   .collection(FirebaseConstants.linksCol)
   .doc(linkId)
```

Adding a new Firestore service method:
```dart
// In FirebaseFirestoreService
Future<void> saveNewData(String uid, MyModel data) async {
  final docRef = _db
      .collection(FirebaseConstants.usersCol)
      .doc(uid)
      .collection(FirebaseConstants.newCollection)   // add constant first
      .doc(data.id);
  await docRef.set(data.toFirestore());
}
```

## Adding Constants

### Hive constant (new box or key)

In `lib/core/constants/hive_constants.dart`:
```dart
class HiveConstants {
  // Existing boxes
  static const String settingsBox = 'settings_box';
  static const String linksBox = 'links_box';
  static const String categoriesBox = 'categories_box';

  // Add new box
  static const String tagsBox = 'tags_box';   // ← new

  // Settings keys
  static const String themeKey = 'theme_mode';
  static const String localeKey = 'locale_language';

  // Add new settings key
  static const String sortOrderKey = 'sort_order';  // ← new
}
```

Then register the new box in `lib/core/utils/hive_helper.dart`:
```dart
Future<void> init() async {
  // ... existing boxes
  await Hive.openBox<TagModel>(HiveConstants.tagsBox);   // ← add
}

Box<TagModel> get tagsBox => Hive.box<TagModel>(HiveConstants.tagsBox);  // ← add accessor
```

### Firestore constant (new collection or field)

In `lib/core/constants/firebase_constants.dart`:
```dart
class FirebaseConstants {
  // Collections
  static const String usersCol = 'users';
  static const String linksCol = 'links';
  static const String categoriesCol = 'categories';

  // Add new collection
  static const String tagsCol = 'tags';   // ← new

  // Add new field
  static const String tagColor = 'color';  // ← new
}
```

## Adding a Hive Model Field

1. Add field to the model class with `@HiveField` annotation
2. Assign a new unique type ID (check existing IDs first — never reuse)
3. Run code generation:

```bash
fvm dart run build_runner build --delete-conflicting-outputs
```

**Never manually edit `.g.dart` files.** Always regenerate.

Example:
```dart
@HiveType(typeId: 0)
class LinkModel {
  @HiveField(0) final String id;
  @HiveField(1) final String url;
  @HiveField(2) final String title;
  // ... existing fields
  @HiveField(9) final String? notes;  // ← new field: pick next available ID
}
```

## Registering a New Service

If you add a new service class, register it in `lib/core/utils/locator.dart`:

```dart
void setupLocator() {
  // existing
  locator.registerLazySingleton<AuthService>(() => AuthService());
  locator.registerLazySingleton<LinkRepository>(() => LinkRepository(...));

  // new
  locator.registerLazySingleton<TagRepository>(
    () => TagRepository(
      hiveHelper: locator<HiveHelper>(),
      firebaseService: locator<FirebaseFirestoreService>(),
    ),
  );
}
```

## Checklist

- [ ] Read existing repo/service before adding
- [ ] New constants added to `HiveConstants` or `FirebaseConstants` (no raw strings)
- [ ] Firestore operations always scoped to `/users/{uid}/`
- [ ] Offline-first: Hive write happens before Firestore attempt
- [ ] Firestore failures are caught and don't crash the app
- [ ] New Hive boxes opened in `HiveHelper.init()` and exposed as accessors
- [ ] New Hive model fields use `@HiveField` with unique IDs — regenerated via `build_runner`
- [ ] New services registered in `locator.dart`
- [ ] `printLog` used for debug logging (not `print`)
- [ ] `fvm flutter analyze` passes with zero warnings
