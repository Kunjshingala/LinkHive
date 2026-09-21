# Project Context — LinkHive

## What Is LinkHive?

**LinkHive** is a Flutter mobile application that acts as a **share target** — users share URLs/links from any app (browser, social media, etc.) into LinkHive, which then saves, organizes, and manages those links. Think of it as a personal link repository that works natively with the Android/iOS share sheet.

The app is currently in **early development** — core infrastructure is in place but link storage and display features are not yet implemented.

---

## Design & UI System

LinkHive strictly uses the **Neo-Brutalism UI Pattern**. Future AI developers must read `.ai/context/ui.md` before building UI components. The design relies on pure white/black, thick 2px borders, highly saturated pastel accents, hard non-blurred offset shadows, and bold typography. No soft minimal styling.

---

## App Name & Package

- **Display name:** Link Hive
- **Flutter package name:** `link_hive`
- **Dart package import prefix:** `package:link_hive/`

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI Framework | Flutter (Dart), Material Design 3 |
| State Management | `flutter_bloc` (BLoC pattern) |
| Authentication | Firebase Auth (`firebase_auth`) - Optional / Local-First |
| Social Auth | Google Sign-In (`google_sign_in`) |
| Backend Cloud Auth | Firebase (Firestore planned, Auth currently active) |
| Local Storage | Hive (`hive_flutter`) for offline link persistence |
| Background Sync | `connectivity_plus` to detect network status |
| Navigation/Routing | `go_router` (named routes) |
| Dependency Injection | `get_it` (lazy singletons via `locator`) |
| Share Intent Handling | `receive_sharing_intent` |
| Reactive Utils | `rxdart` |
| SVG rendering | `flutter_svg` |
| Icon Pack | `font_awesome_flutter` |
| Animation | Rive (`.riv` files in `assets/rive/`) |
| Linting | `flutter_lints` + custom `analysis_options.yaml` |
| Flutter version | FVM-managed (see `.fvmrc`) |

---

## Platform Targets

- Android (primary target — share sheet integration)
- iOS
- Linux, macOS, Windows, Web (scaffolded but not priority)

---

## Current State

- ✅ Auth — email/password + Google Sign-In, sign-out with local/remote clear options
- ✅ Routing — 8 named routes via go_router (splash, login, signup, home, account, addLink, editLink, conflicts)
- ✅ DI — 8 lazy singletons registered in locator
- ✅ Splash screen — Bloc-driven auth-check transition
- ✅ Share intent — fully wired; foreground + cold-start; opens AddLink with prefilled URL
- ✅ Local storage — 8 Hive boxes (links, baseLinks, conflictLinks, categories, syncOperations, syncTombstones, conflictRecords, settings)
- ✅ Cloud sync — offline-first pending operations queue pushed to Firestore on connectivity/auth
- ✅ Incremental pull — cursor-based with 60-second overlap window
- ✅ Deleted items sync — `deleted-links` and `deleted-categories` tracked via tombstones
- ✅ Guest → auth migration — pending ops queue auto-flushed on sign-in via `authStateChanges()`
- ✅ Conflict detection + resolution — ConflictRecord tracking, keep-local / keep-cloud / custom merge
- ✅ Home screen — link list with pagination (20/page), reactive Hive watch, edit/delete actions, FAB
- ✅ Search — debounced 300ms full-text across title, description, URL; combined with filters
- ✅ Category filtering — built-in suggested + user-created custom categories; long-press delete
- ✅ Priority filtering — High / Normal / Low chips; combined with search + category filter
- ✅ Add Link screen — URL form, OG/Twitter metadata auto-fetch (debounced 300ms), category picker, priority selector
- ✅ Edit Link — same screen as Add Link; pre-populates all fields
- ✅ Link metadata service — OG + Twitter extraction; platform-aware (IO / Web fetcher)
- ✅ Account screen — user info, link stats, real-time sync status (idle/syncing/failed/conflict), language + theme settings
- ✅ Sync status UI — SyncStatusBloc drives idle / syncing / failed / conflict states in Account screen
- 🔲 Image preview — OG image fetched and stored in state, not rendered in Add Link UI
- 🔲 Sync retry — no automatic retry on failure; status shows `failed` until next manual or periodic trigger
- 🔲 Non-URL share handling — file/text shares silently ignored (URL-only guard in place)
