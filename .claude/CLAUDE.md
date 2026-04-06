# LinkHive

> **Mandatory:** Read `.claude/rules.md` before every task. Read `.ai/` for full project context.

## Project

- **App:** LinkHive — personal link manager, universal OS share target
- **Package:** `com.link.hive` | Flutter `3.38.3` via FVM | Dart `^3.10.1`
- **Features:** Save links, categorize (custom + built-in), prioritize (High/Normal/Low), search, cloud sync
- **Platforms:** Android (primary), iOS
- **Languages:** en, ar, hi, gu (ARB files in `lib/l10n/`)

> **FVM Required:** Always `fvm flutter` / `fvm dart` — never bare `flutter` or `dart`.

---

## Architecture

### State Management: BLoC (`lib/features/*/bloc/`)

Each feature has 3 files: `*_bloc.dart`, `*_event.dart`, `*_state.dart`.
- Events = sealed class extending `Equatable`
- States = sealed class extending `Equatable`
- Handlers registered via `on<Event>(_handler)` in constructor
- Always emit `Loading` before async ops, `Error` on failure

### Screen Pattern

```
<feature>_screen.dart        ← outer: BlocProvider only
_<feature>_content.dart      ← inner: all UI, BlocBuilder/Listener
bloc/
  <feature>_bloc.dart
  <feature>_event.dart
  <feature>_state.dart
```

### Data Layer

- **Local:** Hive boxes (`linksBox`, `categoriesBox`, `settingsBox`) via `HiveHelper`
- **Cloud:** Firestore at `/users/{uid}/links` and `/users/{uid}/categories` via `FirebaseFirestoreService`
- **Repository:** `LinkRepository` — offline-first, Hive writes immediately, Firestore sync on connectivity
- **Background sync:** `SyncService` listens for connectivity changes

### API / Services (`lib/core/services/`)

| Service | Purpose |
|---|---|
| `AuthService` | Firebase Auth wrapper (email/password + Google) |
| `FirebaseFirestoreService` | Firestore CRUD, always scoped to `/users/{uid}/` |
| `LinkMetadataService` | Open Graph scraper via HTTP, 8s timeout |
| `SyncService` | Background connectivity listener → sync pending links |

### DI: get_it (`lib/core/utils/locator.dart`)

```dart
locator<AuthService>()
locator<LinkRepository>()
locator<HiveHelper>()
locator<SyncService>()
locator<LinkMetadataService>()
locator<FirebaseFirestoreService>()
```

### Routing: go_router (`lib/core/utils/navigation/route.dart`)

| Constant | Path | Screen |
|---|---|---|
| `MyRouteName.splash` | `/` | `SplashScreen` |
| `MyRouteName.login` | `/login` | `LoginScreen` |
| `MyRouteName.homeScreen` | `/home` | `HomeScreen` |
| `MyRouteName.accountScreen` | `/accountScreen` | `AccountScreen` |
| `MyRouteName.signup` | `/signup` | `SignupScreen` |
| `MyRouteName.addLink` | `/addLink` | `AddLinkScreen` (extra: `String? prefillUrl`) |

Always use `context.goNamed(MyRouteName.xxx)` — never raw strings or `Navigator`.

---

## Key Directories

```
lib/
├── main.dart                    # Firebase init → setupLocator() → HiveHelper.init() → SyncService.start()
├── my_app.dart                  # MaterialApp.router, ReceiveSharedIntent lifecycle
├── core/
│   ├── constants/               # HiveConstants, FirebaseConstants, AppEnums
│   ├── extensions/              # context.l10n, context.neoBrutal, context.colors, context.text
│   ├── services/                # AuthService, FirebaseFirestoreService, SyncService, LinkMetadataService
│   ├── theme/                   # AppColors, AppSpacing, AppTypography, AppTheme, ThemeCubit
│   └── utils/
│       ├── locator.dart         # get_it DI setup
│       ├── utils.dart           # showSnackBar(), printLog()
│       └── navigation/route.dart # GoRouter config + MyRouteName constants
├── features/
│   ├── authentication/          # LoginScreen, SignupScreen, AuthBloc
│   ├── home/                    # HomeScreen, HomeBloc
│   ├── links/                   # AddLinkScreen, LinkBloc, AddLinkBloc, LinkRepository, LinkModel
│   ├── account/                 # AccountScreen, AccountBloc
│   └── splash/                  # SplashScreen, SplashBloc
└── sharedWidgets/               # NeoBrutalistButton, CustomTextField, LinkCard, bottom sheets, etc.
```

---

## Conventions

- **State mgmt:** BLoC only — no `setState` for business logic
- **Popups:** `showConfirmationBottomSheet` / `showOptionsBottomSheet` — never `AlertDialog`
- **Colors:** `AppColors.*` only — never `Color()` / `Colors.xxx`
- **Spacing:** `AppSpacing.*` only — never raw `EdgeInsets` values
- **Typography:** `AppTypography.*` — never raw `TextStyle`
- **Buttons:** `NeoBrutalistButton` — never `ElevatedButton` / `TextButton`
- **Inputs:** `CustomTextField` — never bare `TextFormField`
- **AppBar:** `CommonAppBar` — never bare `AppBar`
- **Logging:** `printLog(tag: '...', msg: '...')` — never `print()`
- **SnackBars:** `showSnackBar(message)` — never `ScaffoldMessenger` directly
- **Strings:** `context.l10n.*` — never hardcode user-facing text
- **Neo-Brutalism:** thick 2px borders, `BoxShadow(blurRadius: 0, offset: Offset(4,4))`

---

## Key Dependencies

| Category | Package |
|---|---|
| State | `flutter_bloc`, `equatable`, `rxdart` |
| DI | `get_it` |
| Routing | `go_router` |
| Auth | `firebase_auth`, `google_sign_in` |
| Storage | `hive_flutter` |
| Cloud | `cloud_firestore` |
| Networking | `http` (metadata only) |
| Share | `receive_sharing_intent` |
| UI | `flutter_svg`, `font_awesome_flutter`, `cached_network_image` |
| L10n | `flutter_localizations`, `intl` |
| Testing | `bloc_test`, `mocktail`, `hive_test` |

---

## Commands

```bash
fvm flutter analyze               # Must pass with 0 warnings before done
fvm flutter test                  # Run all tests
fvm flutter gen-l10n              # Regenerate after ARB changes
fvm dart run build_runner build --delete-conflicting-outputs  # After Hive model changes
fvm dart format lib/              # Format all Dart files
cd ios && pod install             # After iOS dependency changes
```

---

## Context Files

Full context lives in `.ai/`:
- `.ai/context/project.md` — what the app is, current state
- `.ai/context/architecture.md` — layered structure, auth flow, DI
- `.ai/context/domain.md` — link management domain
- `.ai/conventions/code-style.md` — naming, BLoC structure, formatting
- `.ai/constraints/never-do.md` — hard rules
- `.ai/constraints/always-do.md` — non-negotiables

Claude-specific quick references:
- `.claude/rules.md` — rule index + quick reminders
- `.claude/context/components-ui.md` — widget catalog, AppColors table, AppSpacing table
