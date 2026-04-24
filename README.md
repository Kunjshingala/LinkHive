# LinkHive 🐝

A high-performance, **offline-first** Flutter application for capturing, organizing, and syncing links across devices. Built with a bold **Neo-Brutalist** design system and powered by Firebase and Hive.

## 🚀 Overview

LinkHive is designed for users who need a reliable way to save and categorize links instantly, even without an internet connection. By utilizing a robust local-first architecture, it ensures a lag-free experience while automatically syncing data to the cloud whenever connectivity is available.

## ✨ Key Features

### 🔗 Link & Category Management (New!)
- **Instant Capture**: Save links with metadata (title, image, description) automatically fetched.
- **Offline CRUD**: Create, Update, and Delete links and categories with zero latency.
- **Global Search**: Find links by title, description, or URL using high-performance local indexing.
- **Smart Filtering**: Filter links by dynamic categories or custom priority levels (High, Normal, Low).
- **Dynamic Sorting**: Automatic descending sort by server-confirmed or client-created timestamps.

### 🔐 Multi-Channel Authentication
- **Secure Sign-In**: Powered by Firebase Authentication.
- **Google Integration**: One-tap sign-in with Google OAuth.
- **Email/Password**: Traditional secure account creation and login.
- **Guest Mode**: Full functionality for local-only use without an account.

### 🍱 Neo-Brutalist UI/UX
- **Bold Aesthetics**: High-contrast colors, thick borders, and hard-edge shadows.
- **Custom Components**: Bespoke widgets including `NeoBrutalistButton`, `LinkCard`, and `CommonAppBar`.
- **Responsive Design**: Full support for Mobile (Android/iOS), Web, and Desktop.

### 🌐 Internationalization
- **Multi-Language Support**: Full localization for English, Arabic (RTL support), Gujarati, and Hindi.
- **Locale Persistence**: Remembers your language preference across sessions.

## 🏗️ Project Structure

The project follows a **Feature-based Clean Architecture**, ensuring high modularity and testability.

```
lib/
├── core/                           # Shared kernel
│   ├── constants/                  # Firebase, Hive, and UI constants
│   ├── extensions/                 # BuildContext and String extensions
│   ├── localization/               # i18n logic and Cubits
│   ├── services/                   # Auth, Firestore, and Sync logic
│   ├── theme/                      # Neo-Brutalist design tokens
│   └── utils/                      # Service locator (GetIt) and helpers
│
├── features/                       # Independent modules
│   ├── links/                      # Core: CRUD, Models, Repositories, BLoCs
│   ├── authentication/             # Auth flow and Guard rails
│   ├── home/                       # Dashboard and Search
│   ├── account/                    # User profiling
│   ├── login/                      # Login interface
│   └── splash/                     # Brand introduction
│
├── sharedWidgets/                  # Global Neo-Brutalist component library
├── firebase_options.dart           # Auto-generated Firebase config
├── main.dart                       # Entry point
└── my_app.dart                     # UI Root
```

## 🛠️ Tech Stack

- **Framework**: [Flutter 3.38.3](https://flutter.dev/)
- **Language**: [Dart 3.10.1+](https://dart.dev/)
- **Local Storage**: [Hive](https://pub.dev/packages/hive_flutter) (NoSQL, high performance)
- **Cloud Backend**: [Firebase](https://firebase.google.com/) (Firestore, Auth)
- **State Management**: [flutter_bloc](https://pub.dev/packages/flutter_bloc) & [RxDart](https://pub.dev/packages/rxdart)
- **Routing**: [go_router](https://pub.dev/packages/go_router)
- **Dependency Injection**: [get_it](https://pub.dev/packages/get_it)

## 📡 Offline-First Sync Strategy

LinkHive uses a sophisticated two-way sync strategy between **Hive** and **Firestore**:

1.  **Writes**: All changes are committed to the local Hive box immediately. If the user is online, the change is mirrored to Firestore asynchronously.
2.  **Conflict Resolution**: Cloud data acts as the source of truth. On app resume, Firestore data is pulled and merged into Hive.
3.  **Sync Status**: Every link tracks an `isSynced` flag, displayed in the UI (cloud-off icon for local-only links).

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

### Minimum Platform Requirements

| Platform | Minimum Version |
|----------|----------------|
| Android | API 24 (Android 7.0 Nougat) |
| iOS | 16.0 |

### Step 1 — Clone & Install Dependencies

```bash
git clone https://github.com/Kunjshingala/LinkHive.git
cd LinkHive/Code/LinkHive

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
   | `FB_ANDROID_CLIENT_ID` | Firebase Console → Authentication → Sign-in method → Google → **Web client ID** |
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
| [Project Plan](docs/PLAN.md) | Phase 1 scope, architecture decisions, and feature roadmap |
| [Dart Define & Firebase Setup](docs/setup/dart_define_and_firebase_setup.md) | How `--dart-define-from-file` works, Firebase project setup from scratch, and config file reference |
| [Receive Sharing Intent](docs/setup/receive_sharing_intent_setup.md) | Android & iOS share sheet integration — how the app receives shared URLs from other apps |

## 🧪 Testing

```bash
fvm flutter test
```

## 📄 License
This is a private project. All rights reserved.
