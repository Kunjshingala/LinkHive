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
- Flutter SDK (v3.38.3)
- [FVM](https://fvm.app/) (recommended)
- Firebase Project configured

### Installation

1.  **Clone & Setup**:
    ```bash
    git clone https://github.com/Kunjshingala/LinkHive.git
    cd linkhive
    fvm use # if using FVM
    flutter pub get
    ```

2.  **Firebase Config**:
    - Place `google-services.json` in `android/app/`.
    - Place `GoogleService-Info.plist` in `ios/Runner/`.

3.  **Run**:
    ```bash
    flutter run
    ```

## 🧪 Testing
We maintain high code quality through unit and widget tests.
```bash
flutter test
```

## 📄 License
This is a private project. All rights reserved.
