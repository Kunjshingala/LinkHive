🎯 LinkHive – Phase 1 (Mid-Level Version)
Goal

A well-structured, production-ready Flutter app with:

Authentication (Optional / Local-First)

Save / Edit / Delete links

Unified Tag/Folder organization

Share intent support with rich metadata extraction

Cloud & Local Sync

Clean architecture (lightweight)

Not over-engineered. Not messy. Balanced.

🧱 1️⃣ Architecture (Simple but Scalable)

Do NOT go full heavy Clean Architecture yet.

Use Feature-First + Repository Pattern (Light Version)

lib/
 ├── core/
 │   ├── services/
 │   │   ├── firebase_service.dart
 │   │   ├── link_metadata_service.dart
 │   │   ├── sync_service.dart
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

State Management:

✅ Bloc (strictly for all state management)

🔐 2️⃣ Authentication & Storage (Optional & Local-First)

**Optional Authentication & Local First Storage**
- **Local First**: Users can install the app and immediately start saving links without creating an account or logging in. 
- **UI Indicator**: A clear notice in the UI will indicate when data is uniquely stored locally and not backed up.
- **Fast Login**: If a user decides to back up their data permanently, they can log in via a simple, fast authentication method (e.g., Google Sign-In or Email).

Flow:

Splash → Home (Local Mode by default)

If user wants to sync → Fast Login (Google/Email) → Cloud Sync enabled

🔗 3️⃣ Core Feature – Link Management (MVP)

**Organization: Combined Tags & Folders**
- **Unified Tag/Folder System**: Tags and folders will be treated as the same concept to simplify organization.
- **Multiple Assignments**: A single link can be assigned to multiple tags/folders (or be `null` if uncategorized).
- **Categories in Firestore**: The user's available tags/folders will be defined and synced via Firestore.
- **Fixed Priorities**: Links or tags can be assigned one of three fixed priorities: High, Normal, Low.

Each link:

class LinkModel {
  final String id;
  final String url;
  final String title;
  final String description;
  final String image;
  final List<String> categories; // Unified tags/folders
  final String priority; // High, Normal, Low
  final DateTime createdAt;
}

Features:

Add link manually

Auto-fetch title + image (basic metadata)

Edit link

Delete link

Search by title

Filter by category

Store in:

Local Storage (for local-first mode)
Firestore (cloud sync)

🔄 4️⃣ Data Synchronization

- **Online Sync**: When connected to the internet and logged in, all local link data automatically syncs to Firebase.
- **Offline & Background Sync**: If saved offline, links are stored locally. A background sync process will automatically push the local data to Firebase once internet connectivity is restored.

📤 5️⃣ Seamless External Sharing

- **Share Intent**: Users can share links from outside apps directly to LinkHive.
- **Metadata Extraction**: The app will attempt to automatically extract metadata (e.g., title, description, image) from the shared link.
- **Prefilled Forms**: When the app opens to save the shared link, the extracted metadata will prefill the form, requiring minimal effort from the user to save it.

🎨 6️⃣ UI Scope (Neo-Brutalism Polish)

Follow the Neo-Brutalist design pattern (pure whites/blacks, thick borders, hard pastel shadows). Keep UI clean but not over-animated.

Screens:

Splash

Home (List/Grid toggle, with Local-Only UI Indicator if not logged in)

Add/Edit Link (Prefilled when coming from Share Intent)

Profile / Fast Login

Add:

Pull to refresh

Empty state UI

Basic loading indicators

Dark mode

Use BottomSheets for all pop-ups (NO traditional dialogs allowed)

No heavy Rive animations yet.

☁️ 7️⃣ Firestore Structure (Simple)
users (collection)
   └── userId (doc)
        ├── categories (subcollection)
        │     └── categoryId (Unified Tag/Folder)
        └── links (subcollection)
              └── linkId

Link document:

{
  "url": "...",
  "title": "...",
  "description": "...",
  "image": "...",
  "categories": ["flutter", "ai"],
  "priority": "High",
  "createdAt": Timestamp
}

Keep it clean.

🧪 8️⃣ Testing (Minimum Professional Standard)

1-2 repository unit tests

1 widget test for link list

Manual QA checklist

Mid-level ≠ no testing.

📦 9️⃣ Packages You Should Use

firebase_core

firebase_auth

cloud_firestore

flutter_bloc

go_router (clean routing)

receive_sharing_intent

cached_network_image

connectivity_plus (for background sync triggers)

That’s enough.

🧭 Phase 1 Scope Summary

✅ Optional Auth & Local First
✅ CRUD links with Priorities
✅ Unified Categories (Tags/Folders)
✅ Search
✅ Seamless Share Intent (Prefilled)
✅ Background Cloud Sync
✅ Clean folder structure

That’s a strong mid-level app.

🔮 Future Phase 2 Ideas (Don’t Build Now)

Smart auto-categorization

Collections (Shared lists)

Analytics dashboard

AI tag suggestion

Web version

Multi-device sync conflict resolution

We keep architecture ready for that.

🎯 What This Shows About You

As a Flutter developer already working with:

State management (Bloc)

Firebase

Production apps

This project will show:

Product thinking

Clean code organization

Scalable mindset

Platform feature usage (share intent)

Offline-first architecture

That’s senior trajectory thinking.