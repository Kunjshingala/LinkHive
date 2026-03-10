 # LinkHive

A Flutter application for managing and sharing links with authentication features.

## Overview

LinkHive is a cross-platform Flutter application that allows users to collect, manage, and share links. The app features a complete authentication system with Google Sign-In and email/password authentication, built on Firebase.

## Features

- 🔐 **Authentication System**
  - Email/password sign-in and sign-up
  - Google Sign-In integration
  - Auth state management
  - Secure Firebase authentication

- 🔗 **Link Management**
  - Receive and handle shared links from other apps
  - Home dashboard for link organization
  - User account management

- 🎨 **Modern UI/UX**
  - Neo-Brutalism design pattern (high contrast, hard shadows, thick borders)
  - Custom widgets and components
  - Rive animations
  - Material Design 3 foundation

## Project Structure

This project follows a feature-based clean architecture pattern:

```
lib/
├── core/                           # Core functionality and utilities
│   ├── services/                   # App-wide services
│   │   ├── auth_service.dart       # Authentication service
│   │   ├── firebaseAuth/           # Firebase auth integration
│   │   └── receiveIntent/          # Handle incoming shared intents
│   └── utils/                      # Utilities and helpers
│       ├── bloc.dart               # BLoC exports
│       ├── locator.dart            # Service locator (GetIt)
│       ├── navigation/             # Navigation configuration
│       ├── utils.dart              # General utilities
│       └── validator/              # Form validators
│
├── features/                       # Feature modules
│   ├── account/                    # User account management
│   │   ├── account.dart
│   │   └── account_bloc.dart
│   ├── authentication/             # Auth screens and logic
│   │   ├── auth_gate.dart          # Auth state router
│   │   ├── login_screen.dart
│   │   ├── signup_screen.dart
│   │   └── widgets/                # Auth-specific widgets
│   ├── home/                       # Home dashboard
│   │   ├── home.dart
│   │   └── home_bloc.dart
│   ├── login/                      # Login feature
│   │   └── login.dart
│   └── splash/                     # Splash screen
│       ├── splash_screen.dart
│       └── splash_bloc.dart
│
├── sharedWidgets/                  # Reusable widgets
│   ├── common_app_bar.dart
│   └── common_text_form_field.dart
│
├── firebase_options.dart           # Firebase configuration
├── main.dart                       # App entry point
└── my_app.dart                     # Root app widget

assets/
└── rive/                           # Rive animation files
```

## Tech Stack

### Core
- **Flutter SDK**: 3.38.3
- **Dart SDK**: ^3.10.1

### Key Dependencies
- **Navigation**: `go_router` - Declarative routing
- **State Management**: `rxdart` - Reactive programming
- **Backend**: Firebase (`firebase_core`, `firebase_auth`)
- **Authentication**: `google_sign_in` - Google OAuth
- **Dependency Injection**: `get_it` - Service locator
- **Sharing**: `receive_sharing_intent` - Handle shared content
- **UI**: `flutter_svg`, `font_awesome_flutter` - Icons and graphics

## Getting Started

### Prerequisites
- Flutter SDK (version 3.38.3)
- FVM (Flutter Version Management) - recommended
- Firebase project with Authentication enabled
- Android Studio / VS Code with Flutter extensions

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd linkhive
   ```

2. **Set up Flutter version (if using FVM)**
   ```bash
   fvm use
   ```

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Configure Firebase**
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Ensure Firebase Authentication is enabled in your Firebase console
   - Enable Google Sign-In provider

5. **Run the app**
   ```bash
   flutter run
   ```

## Platform Support

- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ macOS
- ✅ Linux
- ✅ Windows

## Architecture

The project uses:
- **Feature-based architecture**: Each feature is self-contained with its own BLoC and UI
- **BLoC pattern**: For state management
- **Service layer**: Centralized business logic in core/services
- **Dependency injection**: Using GetIt for service location

## Development

### Running Tests
```bash
flutter test
```

### Building for Production
```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

## License

This project is a private Flutter application.

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Go Router Documentation](https://pub.dev/packages/go_router)
