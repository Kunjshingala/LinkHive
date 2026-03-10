# Architecture — LinkHive

## Overview

LinkHive uses a **feature-first, layered architecture** within `lib/`:

```
lib/
├── main.dart               # Entry point: Firebase init, DI setup, BlocObserver
├── my_app.dart             # MaterialApp.router, ReceiveSharedIntent lifecycle
├── core/                   # Shared infrastructure (not feature-specific)
│   ├── services/           # External service wrappers (Firebase, share intent)
│   │   ├── auth/auth_service.dart
│   │   └── receiveIntent/receive_shared_intent.dart
│   │   └── ...
│   └── utils/              # App-wide utilities
│       ├── bloc_observer.dart   # Global BLoC debug logging
│       ├── locator.dart         # get_it DI container setup
│       ├── utils.dart           # showSnackBar, printLog
│       ├── navigation/route.dart  # go_router config + route names
│       └── validator/validator.dart
│       └── ...
├── features/               # Self-contained feature modules
│   ├── authentication/     # Login, Signup, AuthGate, AuthBloc
│   ├── home/               # HomeScreen + HomeBloc (scaffold)
│   ├── account/            # AccountScreen + AccountBloc (scaffold)
│   ├── splash/             # SplashScreen + SplashBloc (initial load)
│   └── login/              # (legacy or secondary login entry)
│   └── ...                 # other feature screen ...
└── sharedWidgets/          # Reusable UI components
    ├── common_app_bar.dart
    ├── common_text_form_field.dart
    ├── custom_button.dart
    └── custom_text_field.dart
    └── ...
```

---

## Layering Rules

1. **`features/`** — contain their own Bloc (event/state/bloc), screen widget(s), and internal widgets. Features do NOT import from other features directly.
2. **`core/services/`** — wraps external APIs (Firebase, OS intents). Services are registered in `locator.dart` as lazy singletons. Blocs receive services via constructor injection.
3. **`core/utils/`** — stateless helpers and routing config. Nothing in utils should have business logic.
4. **`sharedWidgets/`** — purely presentational. No Bloc or service access.

---

## Auth Flow

```markdown
App Start
  └─> SplashScreen (SplashBloc fires SplashStarted)
        └─> SplashComplete → pushReplacement to /home (HomeScreen)
              └─> User triggers Save/Sync/Account
                    └─> Auth Check (via AuthService)
                          ├─ Authenticated → Proceed with Action
                          └─ Not Authenticated → navigate to /login
                                ├─ email/password → AuthBloc (AuthSignInRequested)
                                ├─ Google sign-in → AuthBloc (AuthGoogleSignInRequested)
                                └─ AuthSuccess → Proceed with Action & return to /home
```
```

---

## Dependency Injection (get_it)

All singleton services are wired in `core/utils/locator.dart`:

```dart
locator.registerLazySingleton<AuthService>(() => AuthService());
locator.registerLazySingleton<ReceiveSharedIntent>(() => ReceiveSharedIntent());
```

- **Blocs** receive services via constructor: `AuthBloc(authService: locator<AuthService>())`
- **Screens** obtain blocs via `BlocProvider` wrapping the content widget
- **AuthGate** and `MyApp` use `locator<T>()` directly for services

---

## Routing (go_router)

Defined in `core/utils/navigation/route.dart`. All routes use **named navigation**:

| Name | Path | Widget |
|---|---|---|
| `splash` | `/` | `SplashScreen` |
| `login` | `/login` | `LoginScreen` |
| `homeScreen` | `/home` | `AuthGate` |
| `accountScreen` | `/accountScreen` | `AccountScreen` |
| `signup` | `/signup` | `SignupScreen` |

Use `context.goNamed(MyRouteName.xxx)` or `context.pushNamed(MyRouteName.xxx)` — never raw string paths.

---

## Share Intent Handling

`ReceiveSharedIntent` listens in two modes:
1. **Foreground stream** (`getMediaStream`) — handles links shared while the app is open
2. **Background/cold-start** (`getInitialMedia`) — handles links that launched the app

The service is initialized in `MyApp.initState()` and disposed in `MyApp.dispose()`. Currently logs received content via `printLog`. **Future work:** route received links into the link storage feature.

---

## BLoC Pattern

Each screen has its own Bloc. Pattern:
- `*_bloc.dart` — extends `Bloc<Event, State>`, registers handlers in constructor
- `*_event.dart` — sealed/abstract event classes extending `Equatable`
- `*_state.dart` — sealed/abstract state classes extending `Equatable`

Global `AppBlocObserver` in `core/utils/bloc_observer.dart` logs all events, transitions, and errors in debug mode (🔵 events, 🟢 transitions, 🔴 errors).
