# AGENTS.md — LinkHive AI Context Entry Point

version: 1.1.0
last_updated: 2026-03-08

---

## ⚠️ READ THIS FIRST

This is the single source of truth for AI agents working on the **LinkHive** Flutter project. Read this file before any other context. Then read the relevant subdirectories below based on what you're working on.

---

## 🔥 Top Golden Rules for Agents
If you only read one section, read this:
1. **State Management is STRICTLY `flutter_bloc`.** Do not use `setState()` or `ChangeNotifier` for business logic. Every feature has its own Bloc directory with `_bloc.dart`, `_event.dart`, and `_state.dart`. Always emit states and wait for state transitions.
2. **Never hardcode raw route paths.** Always use `go_router` and rely on the `MyRouteName` string constants from `lib/core/utils/navigation/route.dart`.
3. **Always use FVM (Flutter Version Management).** Every `flutter` or `dart` command must be prefixed with `fvm` (e.g., `fvm flutter run`, `fvm dart format lib/`).
4. **Service Dependency Injection.** Services are injected via `get_it`. Never instantiate services blindly in UI widgets. Retrieve them via `locator<ServiceName>()` or inject them into Blocs via their constructors.

---

## 🏗️ Quick Project Summary & Core Stack

- **App Name & Purpose:** Link Hive (`link_hive`). A Flutter mobile app (iOS/Android) serving as a universal **share target** for links across the OS.
- **Current Core Status:** Auth flow is nearly complete (Firebase Email/Google Sign-In). Architecture shell (routing, DI, splash, home shell) is wired. The core link storage feature is pending.
- **Framework:** Flutter with Material Design 3.
- **State Management:** `flutter_bloc`
- **Authentication:** Firebase Auth + `google_sign_in`
- **Routing:** `go_router` (using named routes)
- **Dependency Injection:** `get_it` via a central `locator`
- **Key Feature Library:** `receive_sharing_intent` (for OS-level link receiving in foreground and background)
- **Assets/Animations:** Custom Rive animations (`assets/rive/`)

---

## 📂 Detailed Directory Index
Dive deeper based on the task:

| Directory/File | When to Read This |
|---|---|
| [`context/project.md`](context/project.md) | When you need the high-level goals and what the app is supposed to do. |
| [`context/architecture.md`](context/architecture.md) | When you are creating new features, modifying the app's structural flow, or changing how screens integrate. |
| [`context/domain.md`](context/domain.md) | When working with core business logic (Links, Hives, Share Intents). |
| [`plans/clean-architecture-refactor-plan.md`](plans/clean-architecture-refactor-plan.md) | When planning or executing the clean-architecture migration and repository-wide refactor work. |
| [`conventions/code-style.md`](conventions/code-style.md) | When you are writing new Dart code, making sure naming and Bloc structures match the project standard. |
| [`conventions/git.md`](conventions/git.md) | When you need to create branches, commits, or PRs. |
| [`conventions/testing.md`](conventions/testing.md) | When writing tests (especially `bloc_test` for verifying logic). |
| [`constraints/never-do.md`](constraints/never-do.md) | **MUST READ** if refactoring or proposing a large code change to avoid violating project constraints. |
| [`constraints/always-do.md`](constraints/always-do.md) | **MUST READ** for standard operational guidelines (like error handling and logging). |
| [`ops/commands.md`](ops/commands.md) | How to run the app, format code, and execute tests. |
| [`ops/env.md`](ops/env.md) | How Firebase configs and environment variables are managed. |
| [`ops/dependencies.md`](ops/dependencies.md) | If you need to upgrade, change, or understand why a specific pub.dev package is used. |

> Start with [`context/project.md`](context/project.md) for the full picture if it's your first time working on LinkHive.
