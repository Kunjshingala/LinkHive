# LinkHive - Phase 1 (Mid-Level Version)

## Goal

A well-structured, production-ready Flutter app with:

- Authentication (Optional / Local-First)
- Save / Edit / Delete links
- Unified Tag/Folder organization
- Share intent support with rich metadata extraction
- Cloud & Local Sync
- Clean architecture (lightweight)

> Not over-engineered. Not messy. Balanced.

---

## 1. Architecture (Simple but Scalable)

Do NOT go full heavy Clean Architecture yet. Use **Feature-First + Repository Pattern** (Light Version).

```
lib/
 ├── core/
 │   ├── services/
 │   │   ├── firebase_service.dart
 │   │   ├── link_metadata_service.dart
 │   │   └── sync_service.dart
 │   ├── theme/
 │   └── utils/
 │
 ├── features/
 │   ├── auth/
 │   │   ├── auth_controller.dart
 │   │   ├── auth_repository.dart
 │   │   └── auth_screen.dart
 │   │
 │   ├── links/
 │   │   ├── link_model.dart
 │   │   ├── category_model.dart
 │   │   ├── link_repository.dart
 │   │   ├── link_controller.dart
 │   │   ├── home_screen.dart
 │   │   └── add_link_screen.dart
 │
 └── main.dart
```

**State Management:** BLoC (strictly for all state management)

---

## 2. Authentication & Storage (Optional & Local-First)

- **Local First**: Users can install the app and immediately start saving links without creating an account or logging in.
- **UI Indicator**: A clear notice in the UI will indicate when data is stored locally only and not backed up.
- **Fast Login**: If a user decides to back up their data permanently, they can log in via a simple, fast authentication method (e.g., Google Sign-In or Email).

### Flow

```
Splash → Home (Local Mode by default)

If user wants to sync → Fast Login (Google/Email) → Cloud Sync enabled
```

---

## 3. Core Feature - Link Management (MVP)

### Organization: Combined Tags & Folders

- **Unified Tag/Folder System**: Tags and folders are treated as the same concept to simplify organization.
- **Multiple Assignments**: A single link can be assigned to multiple tags/folders (or be `null` if uncategorized).
- **Categories in Firestore**: The user's available tags/folders are defined and synced via Firestore.
- **Fixed Priorities**: Links or tags can be assigned one of three fixed priorities: `High`, `Normal`, `Low`.

### Link Model

```dart
class LinkModel {
  final String id;
  final String url;
  final String title;
  final String description;
  final String image;
  final List<String> categories; // Unified tags/folders
  final String priority;         // High, Normal, Low
  final DateTime createdAt;
}
```

### Features

- Add link manually
- Auto-fetch title + image (basic metadata)
- Edit link
- Delete link
- Search by title
- Filter by category

### Storage

- **Local Storage** - for local-first mode (Hive)
- **Firestore** - cloud sync when authenticated

---

## 4. Data Synchronization

- **Online Sync**: When connected to the internet and logged in, all local link data automatically syncs to Firebase.
- **Offline & Background Sync**: If saved offline, links are stored locally. A background sync process automatically pushes local data to Firebase once internet connectivity is restored.

---

## 5. Seamless External Sharing

- **Share Intent**: Users can share links from outside apps directly to LinkHive.
- **Metadata Extraction**: The app automatically extracts metadata (title, description, image) from the shared link.
- **Prefilled Forms**: When the app opens to save the shared link, extracted metadata prefills the form, requiring minimal user effort.

---

## 6. UI Scope (Neo-Brutalism Polish)

Follow the **Neo-Brutalist design pattern** (pure whites/blacks, thick borders, hard pastel shadows). Keep UI clean but not over-animated.

### Screens

- **Splash**
- **Home** - List/Grid toggle, with Local-Only UI Indicator if not logged in
- **Add/Edit Link** - Prefilled when coming from Share Intent
- **Profile / Fast Login**

### UI Requirements

- Pull to refresh
- Empty state UI
- Basic loading indicators
- Dark mode
- BottomSheets for all pop-ups (NO traditional dialogs)
- No Rive animations

---

## 7. Firestore Structure (Simple)

```
users (collection)
 └── userId (doc)
      ├── categories (subcollection)
      │     └── categoryId (Unified Tag/Folder)
      └── links (subcollection)
            └── linkId
```

### Link Document

```json
{
  "url": "...",
  "title": "...",
  "description": "...",
  "image": "...",
  "categories": ["flutter", "ai"],
  "priority": "High",
  "createdAt": "Timestamp"
}
```

---

## 8. Testing (Minimum Professional Standard)

- 1-2 repository unit tests
- 1 widget test for link list
- Manual QA checklist

> Mid-level does not equal no testing.

---

## 9. Packages

| Package | Purpose |
|---------|---------|
| `firebase_core` | Firebase initialization |
| `firebase_auth` | Authentication |
| `cloud_firestore` | Cloud storage |
| `flutter_bloc` | State management |
| `go_router` | Clean routing |
| `receive_sharing_intent` | Share intent handling |
| `cached_network_image` | Image caching |
| `connectivity_plus` | Background sync triggers |

---

## Phase 1 Scope Summary

- [x] Optional Auth & Local First
- [x] CRUD links with Priorities
- [x] Unified Categories (Tags/Folders)
- [x] Search
- [x] Seamless Share Intent (Prefilled)
- [x] Background Cloud Sync
- [x] Clean folder structure

> That's a strong mid-level app.

---

## Future Phase 2 Ideas (Don't Build Now)

- Smart auto-categorization
- Collections (Shared lists)
- Analytics dashboard
- AI tag suggestion
- Web version
- Multi-device sync conflict resolution

> Architecture is kept ready for these.

---

## What This Project Demonstrates

As a Flutter developer working with State management (BLoC), Firebase, and Production apps, this project shows:

- **Product thinking**
- **Clean code organization**
- **Scalable mindset**
- **Platform feature usage** (share intent)
- **Offline-first architecture**

> That's senior trajectory thinking.
