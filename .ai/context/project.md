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

- ✅ Auth (email/password + Google Sign-In) — complete
- ✅ Routing — complete (5 named routes)
- ✅ DI setup — complete
- ✅ Splash screen — complete (Bloc-driven)
- ✅ Share intent service — wired, logging received links
- 🔲 Home screen — shell only, body empty (needs Local-Only indicator)
- 🔲 Account screen — shell only (needs fast login flow)
- 🔲 Link storage/retrieval (Hive for local, Firestore for cloud sync) — not started
- 🔲 Link display/organization (Unified Categories & Priorities) — not started
