# LinkHive 🐝

An **offline-first** Flutter app for saving links you actually come back to. Built with a bold **Neo-Brutalist** design system and powered by Firebase and Hive.

## 🚀 Overview

Saving a link is easy. Every app does it. The hard part is returning to it, which is why most saved links quietly rot.

LinkHive treats **return as the product**, not capture:

- **Capture costs one gesture.** Share to LinkHive and the link is saved instantly, no form, no decisions. It lands in an Inbox you can triage later, or never.
- **The app brings links back to you.** A daily notification surfaces one link worth revisiting, a Today screen makes acting on it a single tap, and an Android home screen widget keeps it visible without opening the app at all.
- **Everything works offline.** Writes hit local storage immediately and sync to the cloud when a connection appears.

## ✨ Key Features

### ⚡ Instant Capture
- **One-gesture save**: Share a URL from any app and it is saved immediately, with no form to fill in.
- **Inbox**: Instantly-saved links land in a separate Inbox so they never clutter your organized collection. Add details whenever you feel like it, or don't.
- **Background enrichment**: Title, image and description are fetched from the page after the save, so the save itself is never blocked on the network.
- **Undo**: A confirmation bar offers both "Add details" and "Undo" right after saving.

### 🔁 Daily Resurface (the return engine)
- **One link a day**: A 9am local notification surfaces a single link worth revisiting, chosen from what you haven't read.
- **Today screen**: Shows that one link with three actions — Open, Archive, Snooze — each advancing to the next.
- **"When should this come back?"**: Optionally schedule a link to resurface at a chosen time instead of joining the general pool.
- **Spaced ordering**: Links that have never been shown come first, then the least recently surfaced, so coverage spreads instead of repeating.
- **Android home screen widget**: Today's pick plus Inbox and unread counts, tappable straight into the link. Built with Jetpack Glance.

### 🔗 Link & Category Management
- **Offline CRUD**: Create, update and delete links and categories with zero latency.
- **Global search**: Find links by title, description or URL.
- **Smart filtering**: Filter by custom categories or priority (High, Normal, Low).
- **In-app browser**: Links open in a Chrome Custom Tab / `SFSafariViewController`, so they keep your signed-in sessions and keep you inside the app.
- **Up Next**: The oldest unread links surfaced on Home, so forgotten saves stay visible.

### 🔐 Multi-Channel Authentication
- **Secure Sign-In**: Powered by Firebase Authentication.
- **Google Integration**: One-tap sign-in with Google OAuth.
- **Email/Password**: Traditional secure account creation and login.
- **Guest Mode**: Full functionality for local-only use without an account.

### 🍱 Neo-Brutalist UI/UX
- **Bold Aesthetics**: High-contrast colors, thick 2px borders, and hard-edge shadows (zero blur).
- **Custom Components**: Bespoke widgets including `NeoBrutalistButton`, `LinkCard`, and `CommonAppBar`.
- **Light & dark themes**: Including the home screen widget, which follows the system theme rather than the app's.

### 🌐 Internationalization
- **Multi-Language Support**: Full localization for English, Arabic (RTL support), Gujarati, and Hindi.
- **Locale Persistence**: Remembers your language preference across sessions.

> **Platform support:** Android is the primary target and iOS is supported. The share-sheet integration is mobile-only (guarded at runtime), and the home screen widget is currently Android-only.

## 🏗️ Project Structure

The project follows a **Feature-based Clean Architecture**, ensuring high modularity and testability.

```
lib/
├── core/                           # Shared kernel
│   ├── constants/                  # Firebase, Hive, and enum constants
│   ├── extensions/                 # BuildContext extensions (l10n, theme)
│   ├── localization/               # i18n logic and Cubits
│   ├── services/                   # Auth, Firestore, sync, metadata,
│   │                               #   share intent, notifications, widget
│   ├── theme/                      # Neo-Brutalist design tokens
│   └── utils/                      # Service locator (GetIt), routing, helpers
│
├── features/                       # Independent modules
│   ├── links/                      # Core link domain
│   │   ├── manager/                #   LinkManager — every link action
│   │   ├── repository/             #   LinkRepository — Hive + sync queue
│   │   ├── models/                 #   LinkModel, CategoryModel, exceptions
│   │   ├── bloc/                   #   LinkBloc, AddLinkBloc
│   │   └── ui/                     #   Add / Edit link screen
│   ├── inbox/                      # Instantly-saved links awaiting triage
│   ├── today/                      # Daily Resurface focus screen
│   ├── sync/                       # Conflict resolution UI
│   ├── authentication/             # Login / signup flow
│   ├── home/                       # Link list, search, Up Next strip
│   ├── account/                    # Profile, data management, sign-out
│   └── splash/                     # Brand introduction
│
├── sharedWidgets/                  # Global Neo-Brutalist component library
├── l10n/                           # ARB translation files (en, ar, hi, gu)
├── firebase_options.dart           # Auto-generated Firebase config
├── main.dart                       # Entry point
└── my_app.dart                     # UI Root

android/app/src/main/kotlin/com/link/hive/widget/   # Glance home screen widget
```

### Where link logic lives

Two layers, with one job each:

| Layer | Owns | Example |
|---|---|---|
| `LinkRepository` | **Persistence.** Hive writes, the Firestore sync queue, conflict resolution. | `addLink`, `markLinkAsRead`, `pullFromCloud` |
| `LinkManager` | **Actions.** The composites that combine a launch with bookkeeping. | `openLink`, `archiveLink`, `snoozeLink` |

Every surface that can act on a link — the Today screen, link cards, the Up Next strip, the home screen widget — goes through `LinkManager`, so "open a link" is defined exactly once. Before this existed it was implemented four times with four different behaviors, and one of them forgot to mark links as read at all.

The sync machinery (`SyncEngine`, `SyncService`, conflict resolution) talks to the repository directly, since it is persistence infrastructure rather than a user action.

## 🛠️ Tech Stack

- **Framework**: [Flutter 3.38.3](https://flutter.dev/)
- **Language**: [Dart 3.10.1+](https://dart.dev/)
- **Local Storage**: [Hive](https://pub.dev/packages/hive_flutter) (NoSQL, high performance)
- **Cloud Backend**: [Firebase](https://firebase.google.com/) (Firestore, Auth)
- **State Management**: [flutter_bloc](https://pub.dev/packages/flutter_bloc) & [RxDart](https://pub.dev/packages/rxdart)
- **Routing**: [go_router](https://pub.dev/packages/go_router)
- **Dependency Injection**: [get_it](https://pub.dev/packages/get_it)
- **Share Target**: [receive_sharing_intent](https://pub.dev/packages/receive_sharing_intent) (Android intent filters + iOS Share Extension)
- **Notifications**: [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) + [timezone](https://pub.dev/packages/timezone)
- **Home Screen Widget**: [home_widget](https://pub.dev/packages/home_widget) + [Jetpack Glance](https://developer.android.com/jetpack/androidx/releases/glance)
- **In-App Browser**: [url_launcher](https://pub.dev/packages/url_launcher) (Custom Tabs / `SFSafariViewController`)

## 📡 Offline-First Sync Strategy

LinkHive uses a sophisticated two-way sync strategy between **Hive** and **Firestore**:

1.  **Writes**: All changes are committed to the local Hive box immediately. If the user is online, the change is mirrored to Firestore asynchronously.
2.  **Outbox queue**: Writes that can't reach Firestore are queued as sync operations and replayed once connectivity returns. `SyncService` watches connectivity and auth state, and also ticks every 5 minutes.
3.  **Conflict Resolution**: On pull, a local edit that collides with a cloud edit is recorded as a conflict rather than silently overwritten. The Conflicts screen lets you keep either version.
4.  **Sync Status**: Every link tracks an `isSynced` flag, displayed in the UI (cloud-off icon for local-only links), and `SyncEngine` exposes a status stream (idle / syncing / failed / conflict).

## 🚦 Getting Started

### Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Flutter | 3.38.3 | Managed via [FVM](https://fvm.app/) |
| FVM | latest | `dart pub global activate fvm` |
| Xcode | latest | Mac App Store (required for iOS) |
| CocoaPods | latest | `sudo gem install cocoapods` |
| Android Studio | latest | [Download](https://developer.android.com/studio) (required for Android) |
| Firebase Project | — | [Firebase Console](https://console.firebase.google.com/) |

### Java Requirement

Android builds need **JDK 17 or 21**. JDK 25 (bundled with recent Android Studio releases) is not supported by this project's Gradle version.

```bash
# Point Flutter at a supported JDK
fvm flutter config --jdk-dir "<path to JDK 17 or 21>"
```

In Android Studio, set **Settings → Build Tools → Gradle → Gradle JDK** to the same JDK.

### Minimum Platform Requirements

| Platform | Minimum Version |
|----------|----------------|
| Android | API 24 (Android 7.0 Nougat) |
| iOS | 16.0 |

### Step 1 — Clone & Install Dependencies

```bash
git clone https://github.com/Kunjshingala/LinkHive.git
cd LinkHive

# Install the correct Flutter version for this project
fvm install
fvm use

# Get Dart dependencies
fvm flutter pub get

# iOS only — install native pods
cd ios && pod install && cd ..
```

### Step 2 — Firebase Configuration

LinkHive uses `--dart-define-from-file` to inject Firebase config at build time. No native config files (`google-services.json`, `GoogleService-Info.plist`) are needed.

1. Copy the example config:
   ```bash
   cp firebase_config.json.example firebase_config.json
   ```

2. Open `firebase_config.json` and fill in your values:

   | Key | Where to find it |
   |-----|------------------|
   | `FB_PROJECT_ID` | Firebase Console → Project Settings → General → **Project ID** |
   | `FB_MESSAGING_SENDER_ID` | Firebase Console → Project Settings → Cloud Messaging → **Sender ID** |
   | `FB_STORAGE_BUCKET` | Firebase Console → Project Settings → General → **Storage bucket** |
   | `FB_API_KEY_ANDROID` | Firebase Console → Project Settings → Your Apps → Android → **API key** |
   | `FB_APP_ID_ANDROID` | Firebase Console → Project Settings → Your Apps → Android → **App ID** |
   | `FB_API_KEY_IOS` | Firebase Console → Project Settings → Your Apps → iOS → **API key** |
   | `FB_APP_ID_IOS` | Firebase Console → Project Settings → Your Apps → iOS → **App ID** |
   | `FB_IOS_BUNDLE_ID` | Your iOS bundle identifier (e.g., `com.link.hive`) |
   | `FB_WEB_CLIENT_ID` | Firebase Console → Authentication → Sign-in method → Google → **Web client ID** (not the Android client) |
   | `FB_IOS_CLIENT_ID` | Firebase Console → Project Settings → Your Apps → iOS → **OAuth client ID** |

   > `firebase_config.json` is gitignored — your secrets stay local.

### Step 3 — Run the App

**Terminal:**
```bash
# Run on Android
fvm flutter run --dart-define-from-file=firebase_config.json

# Run on iOS Simulator
fvm flutter run -d iPhone --dart-define-from-file=firebase_config.json
```

**VS Code:** Launch configs are pre-configured in `.vscode/launch.json` — just hit **Run/Debug** (F5).

**Android Studio:** Select the **linkhive** run configuration from `.run/` — just hit **Run** (Shift+F10).

### Firebase Project Setup (First Time Only)

If you don't have a Firebase project yet:

1. Go to the [Firebase Console](https://console.firebase.google.com/) and create a new project.
2. **Authentication** — Go to Authentication → Sign-in method and enable:
   - Email/Password
   - Google
3. **Firestore** — Go to Firestore Database → Create database → Start in **test mode** (or configure security rules for production).
4. **Register Apps** — Go to Project Settings → Add app:
   - Add an **Android** app with package name `com.link.hive`
   - Add an **iOS** app with bundle ID `com.link.hive`
5. Copy the generated config values into your `firebase_config.json`.

### Troubleshooting

| Issue | Solution |
|-------|----------|
| `No Firebase App '[DEFAULT]' has been created` | Make sure `firebase_config.json` exists and you're passing `--dart-define-from-file` |
| `google-services.json` not found (Android build error) | Make sure you removed the `com.google.gms.google-services` plugin from `android/app/build.gradle.kts` |
| Google Sign-In fails on iOS | Verify the reversed client ID URL scheme is in `ios/Runner/Info.plist` |
| `pod install` fails | Run `cd ios && pod repo update && pod install` |
| Wrong Flutter version | Run `fvm install && fvm use` in the project root |

## 📚 Documentation

All project documentation lives in the [`docs/`](docs/) directory:

| Document | Description |
|----------|-------------|
| [Product Direction: The Return Engine](docs/product-direction-return-engine.md) | Why the app exists, the problem it's actually solving, and the reasoning behind Instant Capture and Daily Resurface |
| [Project Plan](docs/PLAN.md) | Phase 1 scope, architecture decisions, and feature roadmap |
| [Dart Define & Firebase Setup](docs/setup/dart_define_and_firebase_setup.md) | How `--dart-define-from-file` works, Firebase project setup from scratch, and config file reference |
| [Receive Sharing Intent](docs/setup/receive_sharing_intent_setup.md) | Android & iOS share sheet integration — how the app receives shared URLs from other apps |

Contributor rules live in [`.claude/rules/`](.claude/rules/) (workflow, code patterns, naming) and fuller context in [`.ai/`](.ai/).

## 🧪 Testing

```bash
# Run the suite
fvm flutter test

# Must pass with zero warnings before any change is considered done
fvm flutter analyze
```

All Flutter and Dart commands go through FVM (`fvm flutter`, `fvm dart`) so everyone builds against the pinned SDK.

## 📄 License
This is a private project. All rights reserved.
